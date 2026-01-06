import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heylo/core/session/session_store.dart';
import 'package:heylo/features/home/view_models/notifiers/conversation_notifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GlobalTypingNotifier extends Notifier<Map<String, List<String>>> {
  final Map<String, RealtimeChannel> _channels = {};
  String? _myId;

  @override
  Map<String, List<String>> build() {
    _initId();

    ref.listen(conversationProvider, (prev, next) {
      next.whenData((data) {
        updateSubscriptions(data.items);
      });
    });

    ref.onDispose(() {
      for (var c in _channels.values) c.unsubscribe();
    });

    return {};
  }

  Future<void> _initId() async {
    _myId = await SessionStore.readUid();
    // Retry subscription with current data
    final convAsync = ref.read(conversationProvider);
    convAsync.whenData((data) => updateSubscriptions(data.items));
  }

  void updateSubscriptions(List<ChatConversationItem> items) {
    if (_myId == null) return;

    final activeChannelNames = <String>{};
    // Map channelName -> itemPeerId
    final channelToItemId = <String, String>{};

    for (final item in items) {
      String channelName;
      if (item.isGroup) {
        channelName = 'room:group:${item.peerId}';
      } else {
        // 1:1 using sorted IDs
        final otherId = item.peerId;
        final ids = [_myId!, otherId]..sort();
        channelName = 'room:dm:${ids.join('_')}';
      }
      activeChannelNames.add(channelName);
      channelToItemId[channelName] = item.peerId;
    }

    // Unsubscribe from old
    final currentChannels = _channels.keys.toList();
    for (final name in currentChannels) {
      if (!activeChannelNames.contains(name)) {
        _channels[name]?.unsubscribe();
        _channels.remove(name);

        // Find peerId for this channel to clear state
        // Simplification: iterate entries
        // Since we don't have reverse map stored, we can rebuild state logic or ignore until update.
        // Or cleaner:
        // Just clear state for any peerId NOT in items.
        // But `item.peerId` might map to different things?
        // Let's rely on _updateState logic to handle state.
        // Or forcing a clear:
        // state = {...state}..removeWhere((k, v) => !items.any((i) => i.peerId == k));
      }
    }

    // Subscribe to new
    for (final name in activeChannelNames) {
      if (!_channels.containsKey(name)) {
        final peerId = channelToItemId[name]!;
        _subscribe(name, peerId);
      }
    }
  }

  void _subscribe(String channelName, String peerId) {
    final channel = Supabase.instance.client.channel(channelName);
    _channels[channelName] = channel;

    channel
        .onPresenceSync((payload) {
          _updateState(channel, peerId);
        })
        .onPresenceJoin((payload) {
          _updateState(channel, peerId);
        })
        .onPresenceLeave((payload) {
          _updateState(channel, peerId);
        })
        .subscribe();
  }

  void _updateState(RealtimeChannel channel, String peerId) {
    if (_myId == null) return;

    final state_ = channel.presenceState();
    final names = <String>[];

    for (final pState in state_) {
      for (final presence in pState.presences) {
        final payload = presence.payload;
        if (payload['is_typing'] == true && payload['user_id'] != _myId) {
          names.add(payload['name'] as String? ?? 'Someone');
        }
      }
    }

    if (names.isEmpty) {
      if (state.containsKey(peerId)) {
        // Remove
        final newState = Map<String, List<String>>.from(state);
        newState.remove(peerId);
        state = newState;
      }
    } else {
      // Add/Update
      state = {...state, peerId: names};
    }
  }
}

final globalTypingProvider =
    NotifierProvider<GlobalTypingNotifier, Map<String, List<String>>>(
      GlobalTypingNotifier.new,
    );
