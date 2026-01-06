import 'dart:async'; // Import for StreamSubscription

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:heylo/features/auth/view_model/notifiers/auth_notifier.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'user_presence_notifier.g.dart';

@Riverpod(keepAlive: true)
class UserPresence extends _$UserPresence {
  RealtimeChannel? _channel;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _heartbeatTimer;

  @override
  Map<String, bool> build() {
    final authState = ref.watch(authProvider);
    final userId = authState.userId;

    // React to user ID changes
    if (userId != null) {
      // If we are not initialized or initialized for a different user (though rare here as we recreate)
      // The example suggests using ref.listen for updates, and Future.microtask for initial load.
      // The direct call here is commented out in the example, but the intent is to call _init.
      // We'll rely on the ref.listen and initial check below.
    } else {
      // User logged out
      _channel?.unsubscribe();
      _channel = null;
      // return empty state but we can't mutate state directly in build like this usually
      // failing safe, strictly speaking build returns initial state.
      // But side effects in build are discouraged.
      // Better pattern: use ref.listen.
    }

    // Better pattern with ref.listen to avoid side-effects in build:
    ref.listen(authProvider, (previous, next) {
      final oldId = previous?.userId;
      final newId = next.userId;
      final oldPrivacy = previous?.privacyLastSeen;
      final newPrivacy = next.privacyLastSeen;

      if (newId != null) {
        if (newId != oldId) {
          // New user login
          _init(newId, newPrivacy);
        } else if (newPrivacy != oldPrivacy) {
          // Privacy changed
          _updateTracking(newId, newPrivacy);
        }
      } else if (newId == null && oldId != null) {
        _channel?.unsubscribe();
        _channel = null;
        state = {};
      }
    });

    // Initial check (if already loaded when this provider builds)
    if (userId != null) {
      // Use microtask to avoid build phase issues, passing current privacy
      final privacy = authState.privacyLastSeen;
      Future.microtask(() => _init(userId, privacy));
    }

    // Connectivity listener
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!ref.mounted) return;
      final isOnline = results.any((r) => r != ConnectivityResult.none);
      final userId = ref.read(authProvider).userId;
      final privacy = ref.read(authProvider).privacyLastSeen;

      if (isOnline && userId != null) {
        _init(userId, privacy);
      } else if (!isOnline) {
        // We are offline, clear channel and notify others by just letting timeout happen
        // Or explicitly untrack if we still have a connection (unlikely if network is totally gone)
        _channel?.unsubscribe();
        _channel = null;
        state = {};
      }
    });

    // Cleanup on dispose
    ref.onDispose(() {
      _heartbeatTimer?.cancel();
      _connectivitySub?.cancel();
      _channel?.unsubscribe();
    });

    return {};
  }

  Future<void> _init(String myId, String privacy) async {
    if (_channel != null) {
      // Already initialized. Maybe just update tracking if needed?
      // If user ID changed, we should have unsubscribed.
      // Assuming singleton channel usage here.
      // But we need to ensure tracking payload is correct.
      _updateTracking(myId, privacy);
      return;
    }

    print('[UserPresence] Initializing tracking for user: $myId');
    final client = Supabase.instance.client;

    _channel = client.channel('online_presence');

    _channel!
        .onPresenceSync((payload) {
          print('[UserPresence] Sync received: $payload');
          _updateState();
        })
        .onPresenceJoin((payload) {
          print('[UserPresence] Join received: $payload');
          _updateState();
        })
        .onPresenceLeave((payload) {
          print('[UserPresence] Leave received: $payload');
          _updateState();
        })
        .subscribe((status, [error]) async {
          print('[UserPresence] Status changed: $status, error: $error');
          if (status == RealtimeSubscribeStatus.subscribed) {
            await _updateTracking(myId, privacy);
            _startHeartbeat(myId);
          } else {
            _heartbeatTimer?.cancel();
          }
        });
  }

  void _startHeartbeat(String myId) {
    _heartbeatTimer?.cancel();
    // Update last_seen immediately then every minute
    _updateLastSeen(myId);
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateLastSeen(myId);
    });
  }

  Future<void> _updateLastSeen(String myId) async {
    try {
      await Supabase.instance.client
          .from('users')
          .update({'last_seen': DateTime.now().toIso8601String()})
          .eq('uid', myId);
    } catch (e) {
      debugPrint('[UserPresence] Heartbeat error: $e');
    }
  }

  Future<void> _updateTracking(String myId, String privacy) async {
    if (_channel == null) return;

    if (privacy == 'nobody') {
      // Stop tracking / untrack
      print('[UserPresence] Privacy is nobody, untracking.');
      await _channel!.untrack();
    } else {
      // Track with payload
      print('[UserPresence] Tracking as $privacy');
      await _channel!.track({
        'user_id': myId,
        'privacy_last_seen': privacy,
        'online_at': DateTime.now().toIso8601String(),
      });
    }
  }

  void _updateState() {
    if (!ref.mounted) return;
    if (_channel == null) return;

    final newState = <String, bool>{};
    // supabase_flutter/realtime_client specifics can vary.
    // We treat it as dynamic first to inspect runtime type or just use standard map access.
    final dynamic rawState = _channel!.presenceState();

    print('[UserPresence] Raw State: $rawState');

    // SDK v2 returns List<PresenceState>
    // rawState: [PresenceState(key: ..., presences: [Presence(...)]), ...]
    if (rawState is List) {
      for (final stateItem in rawState) {
        // stateItem is PresenceState
        // It has a .presences property which is List<Presence>
        // We need to access it dynamically or via known structure
        final pState = stateItem as dynamic;
        final presences = pState.presences as List<dynamic>?;

        if (presences != null) {
          for (final presence in presences) {
            final p = presence as dynamic;
            final payload = (p is Map)
                ? p
                : (p.payload as Map<String, dynamic>?);
            final uid = payload?['user_id'] as String?;
            if (uid != null) {
              newState[uid] = true;
            }
          }
        }
      }
    } else if (rawState is Map) {
      // Old behavior fallback
      for (final presences in rawState.values) {
        if (presences is List) {
          for (final presence in presences) {
            final p = presence as dynamic;
            final payload = (p is Map)
                ? p
                : (p.payload as Map<String, dynamic>?);
            final uid = payload?['user_id'] as String?;
            if (uid != null) {
              newState[uid] = true;
            }
          }
        }
      }
    }

    print('[UserPresence] Parsed Online Users: ${newState.keys}');

    state = newState;
  }

  bool isOnline(String userId) => state[userId] ?? false;
}
