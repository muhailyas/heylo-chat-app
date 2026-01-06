import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:heylo/core/session/session_store.dart';
import 'package:heylo/core/supabase/supabase_client.dart';
import 'package:heylo/core/utils/phone_utils.dart';
import 'package:heylo/features/auth/models/user_model.dart';
import 'package:heylo/features/auth/repositories/profile_repo.dart';
import 'package:heylo/features/chat/repositories/chat_repo.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'conversation_notifier.g.dart';

// View model for chat list item
class ChatConversationItem {
  final String peerId;
  final Map<String, dynamic> lastMessage;
  final UserModel? profile;
  final String? contactName;
  final int unreadCount;
  final bool isGroup;
  final Map<String, dynamic>? groupData;

  const ChatConversationItem({
    required this.peerId,
    required this.lastMessage,
    this.profile,
    this.contactName,
    this.unreadCount = 0,
    this.isGroup = false,
    this.groupData,
  });

  String get name => isGroup
      ? (groupData?['name'] ?? 'Group')
      : (contactName ?? profile?.phone ?? profile?.name ?? 'Unknown User');
  String get avatarUrl => isGroup
      ? (groupData?['avatar_url'] ?? '')
      : ((profile?.privacyProfilePhoto == 'everyone')
            ? (profile?.avatarUrl ?? '')
            : '');
  String get id => peerId;

  String get lastMessageContent {
    if (unreadCount > 1) {
      return '$unreadCount new messages';
    }

    final type = lastMessage['type'] as String? ?? 'text';
    final content = lastMessage['content'] as String? ?? '';

    switch (type) {
      case 'text':
        return content;
      case 'image':
        return '📷 Image';
      case 'voice':
        final durationMs = lastMessage['duration_ms'] as int? ?? 0;
        final d = Duration(milliseconds: durationMs);
        final m = d.inMinutes;
        final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
        return '🎵 Voice Message $m:$s';
      case 'file':
        return '📄 $content';
      case 'call':
        final parts = content.split('|');
        final base = parts[0];
        final status = parts.length > 1 ? parts[1] : 'completed';
        final durationMs = lastMessage['duration_ms'] as int? ?? 0;

        if (status == 'missed' || status == 'rejected') {
          return '📞 Missed $base';
        }

        if (durationMs > 0) {
          final d = Duration(milliseconds: durationMs);
          final m = d.inMinutes;
          final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
          return '📞 $base ($m:$s)';
        }
        return '📞 $base';
      case 'revoked':
        return '🚫 Message deleted';
      default:
        return content.isNotEmpty ? content : '[$type]';
    }
  }

  DateTime get timestamp => DateTime.parse(lastMessage['created_at']).toLocal();
}

class ConversationListState {
  final List<ChatConversationItem> items;
  final bool isPaginating;
  final bool hasMore;

  const ConversationListState({
    this.items = const [],
    this.isPaginating = false,
    this.hasMore = true,
  });

  ConversationListState copyWith({
    List<ChatConversationItem>? items,
    bool? isPaginating,
    bool? hasMore,
  }) {
    return ConversationListState(
      items: items ?? this.items,
      isPaginating: isPaginating ?? this.isPaginating,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

@riverpod
class ConversationNotifier extends _$ConversationNotifier {
  SupabaseProfileRepo get _profileRepo =>
      SupabaseProfileRepo(SupabaseDbAuthRepoClient.instance);

  ChatRepo get _chatRepo => ChatRepo(Supabase.instance.client);

  RealtimeChannel? _realtimeChannel;
  final AudioPlayer _soundPlayer = AudioPlayer();
  String? _myId;

  @override
  Future<ConversationListState> build() async {
    _myId = await SessionStore.readUid();

    // Listen to Realtime for new messages to update list
    if (_myId != null) {
      final channelName = 'public:conversations:$_myId';
      _realtimeChannel = Supabase.instance.client
          .channel(channelName)
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'messages',
            callback: (payload) {
              if (payload.eventType == PostgresChangeEvent.insert) {
                final newMsg = payload.newRecord;
                if (newMsg['sender_id'] != _myId) {
                  _chatRepo.markDelivered(newMsg['id']);
                  _playReceiveSound();
                }
              }
              _refreshSingle(
                payload.newRecord.isNotEmpty
                    ? payload.newRecord
                    : payload.oldRecord,
              );
            },
          )
          .subscribe((status, [error]) {
            debugPrint(
              '[ConversationNotifier] Realtime Status ($channelName): $status',
            );
          });

      // Listen to groups table for metadata updates
      Supabase.instance.client
          .channel('public:groups:$_myId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'groups',
            callback: (payload) {
              _refreshGroup(payload.newRecord);
            },
          )
          .subscribe();
    }

    ref.onDispose(() {
      _realtimeChannel?.unsubscribe();
      _soundPlayer.dispose();
    });

    return _fetchAndHydrate();
  }

  Future<void> _playReceiveSound() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('pref_conversation_tones') ?? true;
      if (!enabled) return;

      // Ensure the asset path is correct
      await _soundPlayer.setAsset('assets/sounds/receive_message_v2.mp3');
      await _soundPlayer.play();
    } catch (e) {
      debugPrint('[ConversationNotifier] Error playing sound: $e');
    }
  }

  Future<ConversationListState> _fetchAndHydrate() async {
    if (_myId == null) {
      return const ConversationListState(items: [], hasMore: false);
    }

    try {
      final rawConvs = await _chatRepo.getConversations(_myId!);

      // Mark all incoming messages in the conversation list as delivered
      for (var msg in rawConvs) {
        if (msg['sender_id'] != _myId && msg['status'] == 'sent') {
          _chatRepo.markDelivered(msg['id']);
        }
      }

      final items = await _hydrate(rawConvs);

      return ConversationListState(
        items: items,
        hasMore: false, // pagination not implemented for MVP
        isPaginating: false,
      );
    } catch (e) {
      print('[ConversationNotifier] Fetch error: $e');
      // Return empty state but allow notification of error if needed
      return const ConversationListState(items: [], hasMore: false);
    }
  }

  Future<Map<String, String>> _fetchLocalContactNames() async {
    if (!await Permission.contacts.isGranted) return {};
    try {
      final contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
      );
      final map = <String, String>{};
      for (var c in contacts) {
        for (var p in c.phones) {
          final norm = PhoneUtils.normalize(p.number);
          if (norm != null) map[norm] = c.displayName;
        }
      }
      return map;
    } catch (e) {
      print('[ConversationNotifier] Failed to fetch contacts: $e');
      return {};
    }
  }

  Future<List<ChatConversationItem>> _hydrate(
    List<Map<String, dynamic>> rawMessages,
  ) async {
    if (rawMessages.isEmpty) return [];

    // Extract peer IDs and Group IDs
    final uids = <String>{};
    final gids = <String>{};
    for (var msg in rawMessages) {
      final gid = msg['group_id'] as String?;
      if (gid != null) {
        gids.add(gid);
      } else {
        final sender = msg['sender_id'];
        final receiver = msg['receiver_id'];
        final peer = sender == _myId ? receiver : sender;
        if (peer != null) uids.add(peer);
      }
    }

    // Fetch profiles
    final profiles = await _profileRepo.fetchUsers(uids.toList());
    final profileMap = {for (var p in profiles) p.uid: p};

    // Fetch groups
    final groupMap = <String, Map<String, dynamic>>{};
    if (gids.isNotEmpty) {
      try {
        final res = await Supabase.instance.client
            .from('groups')
            .select()
            .filter('id', 'in', gids.toList());
        for (var g in (res as List)) {
          groupMap[g['id']] = g as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('[ConversationNotifier] Error fetching groups: $e');
      }
    }

    // Fetch local contacts
    final contactMap = await _fetchLocalContactNames();

    return rawMessages.map((msg) {
      final gid = msg['group_id'] as String?;
      if (gid != null) {
        return ChatConversationItem(
          peerId: gid,
          lastMessage: msg,
          isGroup: true,
          groupData: groupMap[gid],
        );
      }

      final sender = msg['sender_id'];
      final receiver = msg['receiver_id'];
      final peerId = sender == _myId ? receiver : sender;

      final profile = profileMap[peerId];
      String? contactName;
      if (profile != null) {
        final normalizedPhone = PhoneUtils.normalize(profile.phone);
        if (normalizedPhone != null) {
          contactName = contactMap[normalizedPhone];
        }
      }

      return ChatConversationItem(
        peerId: peerId,
        lastMessage: msg,
        profile: profile,
        contactName: contactName,
      );
    }).toList();
  }

  Future<void> _refreshSingle(Map<String, dynamic> newMsg) async {
    // Optimistic up-to-top
    final current = state.value;
    if (current == null) return;

    final sender = newMsg['sender_id'];
    final receiver = newMsg['receiver_id'];
    final gid = newMsg['group_id'] as String?;
    final peerId = gid ?? (sender == _myId ? receiver : sender);

    if (peerId == null) return;

    // Need to re-hydrate this single one
    final existingIndex = current.items.indexWhere((i) => i.peerId == peerId);

    ChatConversationItem newItem;

    final isRead = newMsg['is_read'] as bool? ?? false;

    if (existingIndex != -1) {
      final existing = current.items[existingIndex];

      int newUnread = existing.unreadCount;
      if (gid != null) {
        // Simple simplified logic for group unread: increment if not sender
        if (sender != _myId) newUnread++;
      } else {
        if (isRead) {
          newUnread = 0;
        } else if (sender != _myId) {
          newUnread++;
        }
      }

      newItem = ChatConversationItem(
        peerId: existing.peerId,
        lastMessage: newMsg,
        profile: existing.profile,
        contactName: existing.contactName,
        unreadCount: newUnread,
        isGroup: existing.isGroup,
        groupData: existing.groupData,
      );

      final newItems = List<ChatConversationItem>.from(current.items);
      newItems.removeAt(existingIndex);
      newItems.insert(0, newItem);
      state = AsyncValue.data(current.copyWith(items: newItems));
    } else {
      // New conversation
      final list = await _hydrate([newMsg]);
      if (list.isNotEmpty) {
        state = AsyncValue.data(
          current.copyWith(items: [list.first, ...current.items]),
        );
      }
    }
  }

  Future<void> _refreshGroup(Map<String, dynamic> newGroup) async {
    final current = state.value;
    if (current == null) return;

    final gid = newGroup['id'] as String;
    final existingIndex = current.items.indexWhere((i) => i.peerId == gid);

    if (existingIndex != -1) {
      final existing = current.items[existingIndex];
      final newItem = ChatConversationItem(
        peerId: existing.peerId,
        lastMessage: existing.lastMessage,
        profile: existing.profile,
        contactName: existing.contactName,
        unreadCount: existing.unreadCount,
        isGroup: true,
        groupData: newGroup,
      );

      final newItems = List<ChatConversationItem>.from(current.items);
      newItems[existingIndex] = newItem;
      state = AsyncValue.data(current.copyWith(items: newItems));
    }
  }

  Future<void> loadMore() async {
    // Pagination not supported in MVP
  }
}
