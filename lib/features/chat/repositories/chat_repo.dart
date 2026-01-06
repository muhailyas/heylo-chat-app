import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_message.dart';

class ChatRepo {
  final SupabaseClient _client;
  ChatRepo(this._client);

  static const _bucket = 'chat_media';

  // ───────────────── Upload ─────────────────

  Future<String> _upload({
    required String senderId,
    required File file,
    required String chatId,
  }) async {
    final ext = _ext(file.path);
    final path =
        '$senderId/$chatId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage
        .from(_bucket)
        .upload(path, file, fileOptions: const FileOptions(upsert: false));

    return _client.storage.from(_bucket).getPublicUrl(path);
  }

  static String _ext(String path) {
    final i = path.lastIndexOf('.');
    return i == -1 ? 'bin' : path.substring(i + 1);
  }

  // ───────────────── Messages (Supabase) ─────────────────

  Future<void> sendText({
    required String senderId,
    String? peerId,
    String? groupId,
    required String text,
    ChatMessage? replyTo,
  }) async {
    await _client.from('messages').insert({
      'sender_id': senderId,
      if (peerId != null) 'receiver_id': peerId,
      if (groupId != null) 'group_id': groupId,
      'content': text,
      'type': 'text',
      'reply_to_id': replyTo?.id,
    });
  }

  Future<void> sendImage({
    required String senderId,
    String? peerId,
    String? groupId,
    required String chatId,
    required File file,
    ChatMessage? replyTo,
  }) async {
    final url = await _upload(senderId: senderId, file: file, chatId: chatId);
    await _client.from('messages').insert({
      'sender_id': senderId,
      if (peerId != null) 'receiver_id': peerId,
      if (groupId != null) 'group_id': groupId,
      'content': 'Image',
      'media_url': url,
      'type': 'image',
      'reply_to_id': replyTo?.id,
    });
  }

  Future<void> sendVoice({
    required String senderId,
    String? peerId,
    String? groupId,
    required String chatId,
    required File file,
    required Duration duration,
    ChatMessage? replyTo,
  }) async {
    final url = await _upload(senderId: senderId, file: file, chatId: chatId);
    await _client.from('messages').insert({
      'sender_id': senderId,
      if (peerId != null) 'receiver_id': peerId,
      if (groupId != null) 'group_id': groupId,
      'content': 'Voice Message',
      'media_url': url,
      'duration_ms': duration.inMilliseconds,
      'type': 'voice',
      'reply_to_id': replyTo?.id,
    });
  }

  Future<void> sendFile({
    required String senderId,
    String? peerId,
    String? groupId,
    required String chatId,
    required File file,
    ChatMessage? replyTo,
  }) async {
    final name = file.path.split('/').last;
    final url = await _upload(senderId: senderId, file: file, chatId: chatId);
    await _client.from('messages').insert({
      'sender_id': senderId,
      if (peerId != null) 'receiver_id': peerId,
      if (groupId != null) 'group_id': groupId,
      'content': name,
      'media_url': url,
      'type': 'file',
      'reply_to_id': replyTo?.id,
    });
  }

  Future<void> sendContact({
    required String senderId,
    String? peerId,
    String? groupId,
    required String name,
    required String phone,
    ChatMessage? replyTo,
  }) async {
    await _client.from('messages').insert({
      'sender_id': senderId,
      if (peerId != null) 'receiver_id': peerId,
      if (groupId != null) 'group_id': groupId,
      'content': '$name|$phone',
      'type': 'contact',
      'reply_to_id': replyTo?.id,
    });
  }

  Future<void> sendCallMessage({
    required String senderId,
    String? peerId,
    String? groupId,
    required bool isVideo,
    required int durationSeconds,
    String? status,
  }) async {
    final title = isVideo ? 'Video Call' : 'Voice Call';
    final content = status != null ? '$title|$status' : title;

    await _client.from('messages').insert({
      'sender_id': senderId,
      if (peerId != null) 'receiver_id': peerId,
      if (groupId != null) 'group_id': groupId,
      'content': content,
      'type': 'call',
      'duration_ms': durationSeconds * 1000,
    });
  }

  // ───────────────── History / Realtime ─────────────────

  Stream<List<Map<String, dynamic>>> getMessagesStream(
    String myId,
    String peerId,
  ) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', myId) // Incoming
        .order('created_at', ascending: false) // Latest first
        .map((event) => event);

    // Note: To get BOTH incoming and outgoing in one stream is tricky with simple filters.
    // Usually easier to query history + listen for NEW inserts where (sender=me AND receiver=peer) OR (sender=peer AND receiver=me)
    // But .stream() is robust.
    // Let's implement listener in Notifier or fetching logic.
    // Ideally, UI subscribes to the Room ID (if we used Rooms), but we are using peer-to-peer.
    // For simplicity, we can fetch history + listen to ANY new message involving us and peer.
  }

  // Actually, Supabase Stream is best for "All updates to this table matching criteria".
  // Complex OR conditions in Stream are limited locally.
  // Better approach:
  // 1. Fetch History (RPC or simple select)
  // 2. Listen to Realtime Channel for NEW inserts.

  Future<List<Map<String, dynamic>>> getConversations(String myId) async {
    // 1. Get groups user is in
    final groupRes = await _client
        .from('group_members')
        .select('group_id, groups(*)')
        .eq('user_id', myId);

    final userGroups = List<Map<String, dynamic>>.from(groupRes as List);
    final groupIds = userGroups.map((e) => e['group_id'] as String).toList();

    final groupFilter = groupIds.isNotEmpty
        ? ',group_id.in.(${groupIds.join(',')})'
        : '';

    final res = await _client
        .from('messages')
        .select()
        .or('sender_id.eq.$myId,receiver_id.eq.$myId$groupFilter')
        .order('created_at', ascending: false)
        .limit(400);

    final data = List<Map<String, dynamic>>.from(res as List);

    // Group by peer or groupId and keep only first (latest)
    final latestMessages = <String, Map<String, dynamic>>{};
    for (final msg in data) {
      final gid = msg['group_id'] as String?;
      if (gid != null) {
        if (!latestMessages.containsKey(gid)) {
          latestMessages[gid] = msg;
        }
      } else {
        final sender = msg['sender_id'] as String;
        final receiver = msg['receiver_id'] as String?;
        if (receiver == null) continue;
        final peer = sender == myId ? receiver : sender;

        if (!latestMessages.containsKey(peer)) {
          latestMessages[peer] = msg;
        }
      }
    }

    // 2. Add groups that have no messages yet
    for (final ug in userGroups) {
      final gid = ug['group_id'] as String;
      if (!latestMessages.containsKey(gid)) {
        final groupData = ug['groups'] as Map<String, dynamic>?;
        if (groupData != null) {
          latestMessages[gid] = {
            'group_id': gid,
            'sender_id': groupData['created_by'],
            'content': 'Group created',
            'type': 'text',
            'created_at': groupData['created_at'],
          };
        }
      }
    }

    final result = latestMessages.values.toList();
    // Sort by created_at descending
    result.sort(
      (a, b) =>
          (b['created_at'] as String).compareTo(a['created_at'] as String),
    );
    return result;
  }

  Future<List<Map<String, dynamic>>> history({
    required String myId,
    String? peerId,
    String? groupId,
    int limit = 30,
    String? createdBefore, // Timestamp for cursor
    String? createdAfter, // Timestamp for cleared chat
  }) async {
    var query = _client
        .from('messages')
        .select('*, sender:sender_id(name, avatar_url, privacy_profile_photo)');

    if (groupId != null) {
      query = query.eq('group_id', groupId);
    } else if (peerId != null) {
      query = query.or(
        'and(sender_id.eq.$myId,receiver_id.eq.$peerId),and(sender_id.eq.$peerId,receiver_id.eq.$myId)',
      );
    }

    if (createdBefore != null) {
      query = query.lt('created_at', createdBefore);
    }

    if (createdAfter != null) {
      query = query.gt('created_at', createdAfter);
    }

    final data = await query.order('created_at', ascending: false).limit(limit);

    // Enforce Privacy on Joined Sender Data
    for (final row in data) {
      final sender = row['sender'];
      if (sender is Map) {
        final privacy =
            sender['privacy_profile_photo'] as String? ?? 'everyone';
        if (privacy != 'everyone') {
          sender['avatar_url'] = ''; // Redact
        }
      }
    }

    return List<Map<String, dynamic>>.from(data);
  }

  Future<List<Map<String, dynamic>>> searchMessages({
    required String query,
    required String myId,
    int limit = 20,
  }) async {
    // 1. Get groups user is in (to search group messages)
    debugPrint('[ChatRepo] Fetching groups for $myId');
    final groupRes = await _client
        .from('group_members')
        .select('group_id')
        .eq('user_id', myId);

    final groupIds = (groupRes as List)
        .map((e) => e['group_id'] as String)
        .toList();
    debugPrint('[ChatRepo] User is in ${groupIds.length} groups');
    final groupFilter = groupIds.isNotEmpty
        ? ',group_id.in.(${groupIds.join(',')})'
        : '';

    // 2. Search
    debugPrint('[ChatRepo] Searching messages for query: $query, myId: $myId');
    try {
      final res = await _client
          .from('messages')
          .select(
            '*, sender:sender_id(uid, name, avatar_url, phone), receiver:receiver_id(uid, name, avatar_url, phone), groups:group_id(name)',
          )
          .ilike('content', '%$query%')
          .or('sender_id.eq.$myId,receiver_id.eq.$myId$groupFilter')
          .order('created_at', ascending: false)
          .limit(limit);

      debugPrint('[ChatRepo] Search completed. Found ${res.length} messages.');
      return List<Map<String, dynamic>>.from(res as List);
    } catch (e, stack) {
      debugPrint('[ChatRepo] Search error: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  Stream<List<Map<String, dynamic>>> subscribeToChat(
    String myId,
    String peerId,
  ) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((rows) {
          // Filter locally for now, or trust the stream query to be generic?
          // Stream filtering is limited.
          // Better to listen to all my messages?
          return rows.where((row) {
            final sid = row['sender_id'];
            final rid = row['receiver_id'];
            return (sid == myId && rid == peerId) ||
                (sid == peerId && rid == myId);
          }).toList();
        });
  }

  Future<void> deleteMessage(String messageId) async {
    await _client.from('messages').delete().eq('id', messageId);
  }

  Future<void> revokeMessage(String messageId) async {
    await _client
        .from('messages')
        .update({'type': 'revoked'})
        .eq('id', messageId);
  }

  Future<void> markRead(String messageId) async {
    await _client
        .from('messages')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toIso8601String(),
          'status': 'read',
        })
        .eq('id', messageId);
  }

  Future<void> toggleReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    // Fetch current reactions
    final res = await _client
        .from('messages')
        .select('reactions')
        .eq('id', messageId)
        .maybeSingle();

    // 1. Safe Cast & Clone
    final rawMap = res?['reactions'] as Map<String, dynamic>? ?? {};
    final Map<String, List<String>> reactions = {};

    rawMap.forEach((key, value) {
      if (value is List) {
        reactions[key] = List<String>.from(value.map((e) => e.toString()));
      }
    });

    // 2. Check current state for the target emoji
    final usersInTarget = reactions[emoji] ?? [];
    final bool wasReacted = usersInTarget.contains(userId);

    // 3. Remove user from ALL emojis (enforce single reaction)
    reactions.forEach((key, users) {
      users.remove(userId);
    });

    // 4. Toggle Logic: If they weren't reacted with THIS emoji, add them.
    // If they WERE reacted, we just removed them (Toggle Off).
    if (!wasReacted) {
      if (reactions[emoji] == null) {
        reactions[emoji] = [];
      }
      reactions[emoji]!.add(userId);
    }

    // 5. Cleanup empty keys
    reactions.removeWhere((key, users) => users.isEmpty);

    await _client
        .from('messages')
        .update({'reactions': reactions})
        .eq('id', messageId);
  }

  Future<void> markDelivered(String messageId) async {
    // Only mark delivered if it's currently 'sent'
    await _client
        .from('messages')
        .update({
          'status': 'delivered',
          // 'delivered_at': DateTime.now().toIso8601String(), // Removed due to missing DB column
        })
        .eq('id', messageId)
        .eq('status', 'sent');
  }

  Future<void> markAllAsRead(String myId, String peerId) async {
    await _client
        .from('messages')
        .update({
          'is_read': true,
          'read_at': DateTime.now().toIso8601String(),
          'status': 'read',
        })
        .eq('receiver_id', myId)
        .eq('sender_id', peerId)
        .eq('is_read', false);
  }

  Future<void> markAllAsDelivered(String myId, String peerId) async {
    await _client
        .from('messages')
        .update({
          'status': 'delivered',
          // 'delivered_at': DateTime.now().toIso8601String(), // Removed due to missing DB column
        })
        .eq('receiver_id', myId)
        .eq('sender_id', peerId)
        .eq('status', 'sent');
  }

  // Realtime subscription specifically for this chat
  RealtimeChannel subscribeRealtime({
    required String myId,
    String? peerId,
    String? groupId,
    required Function(Map<String, dynamic> payload, PostgresChangeEvent event)
    onChange,
  }) {
    // Unique channel name for this chat session
    final channelName = groupId != null
        ? 'group_room:$groupId'
        : 'chat_room:$myId:$peerId';

    final channel = _client.channel(channelName);

    if (groupId != null) {
      return channel
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'group_id',
              value: groupId,
            ),
            callback: (payload) {
              onChange(payload.newRecord, payload.eventType);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'group_id',
              value: groupId,
            ),
            callback: (payload) {
              onChange(payload.newRecord, payload.eventType);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'group_id',
              value: groupId,
            ),
            callback: (payload) {
              onChange(payload.oldRecord, payload.eventType);
            },
          )
          .subscribe((status, [error]) {
            debugPrint(
              '[ChatRepo] Group Realtime Status ($channelName): $status',
            );
          });
    }

    return channel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: myId,
          ),
          callback: (payload) {
            if (payload.newRecord['sender_id'] == peerId) {
              onChange(payload.newRecord, payload.eventType);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: myId,
          ),
          callback: (payload) {
            if (payload.newRecord['receiver_id'] == peerId) {
              onChange(payload.newRecord, payload.eventType);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: myId,
          ),
          callback: (payload) {
            if (payload.newRecord['sender_id'] == peerId) {
              onChange(payload.newRecord, payload.eventType);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: myId,
          ),
          callback: (payload) {
            if (payload.newRecord['receiver_id'] == peerId) {
              onChange(payload.newRecord, payload.eventType);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: myId,
          ),
          callback: (payload) {
            if (payload.oldRecord['receiver_id'] == peerId) {
              onChange(payload.oldRecord, payload.eventType);
            }
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: myId,
          ),
          callback: (payload) {
            if (payload.oldRecord['sender_id'] == peerId) {
              onChange(payload.oldRecord, payload.eventType);
            }
          },
        )
        .subscribe((status, [error]) {
          debugPrint('[ChatRepo] P2P Realtime Status ($channelName): $status');
          if (error != null) {
            debugPrint('[ChatRepo] Realtime Error: $error');
          }
        });
  }

  Future<String> getOrCreateOneToOneChat({
    required String myUserId,
    required String peerUserId,
  }) async {
    // For Supabase P2P chat based on messages table,
    // we don't necessarily need a 'chats' table if we just query by participants.
    // BUT existing code expects a chatId.
    // If migration plan said "Create messages table", maybe we didn't migrate 'chats' and 'chat_participants'?
    // Let's check if those tables exist or if we should just return peerUserId as chatId (common in simple apps).
    // The ChatNotifier uses peerId as chatId usually.
    // Let's assume for now we return peerUserId as the "ID" of the conversation for consistency
    // with the new 1:1 message table approach where we query by sender/receiver.
    return peerUserId;

    // OLD Logic used real tables:
    /*
    final existing = ...
    */
  }

  // ───────────────── Blocking ─────────────────

  Future<void> blockUser(String myId, String peerId) async {
    await _client.from('blocked_users').insert({
      'blocker_id': myId,
      'blocked_id': peerId,
    });
  }

  Future<void> unblockUser(String myId, String peerId) async {
    await _client
        .from('blocked_users')
        .delete()
        .eq('blocker_id', myId)
        .eq('blocked_id', peerId);
  }

  Future<bool> isBlocked(String myId, String peerId) async {
    final res = await _client
        .from('blocked_users')
        .select()
        .eq('blocker_id', myId)
        .eq('blocked_id', peerId)
        .maybeSingle();
    return res != null;
  }

  Future<List<String>> getBlockedUsers(String myId) async {
    final res = await _client
        .from('blocked_users')
        .select('blocked_id')
        .eq('blocker_id', myId);

    return List<String>.from(res.map((e) => e['blocked_id'] as String));
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    try {
      // Assuming 'users' table has 'uid' as the identifier matching sender_id
      final res = await _client
          .from('users')
          .select(
            'name, avatar_url, last_seen, privacy_last_seen, privacy_profile_photo',
          )
          .eq('uid', userId)
          .maybeSingle();

      if (res != null) {
        // Enforce Privacy
        final privacyLastSeen =
            res['privacy_last_seen'] as String? ?? 'everyone';
        final privacyProfilePhoto =
            res['privacy_profile_photo'] as String? ?? 'everyone';

        if (privacyLastSeen != 'everyone') {
          res.remove('last_seen');
        }

        if (privacyProfilePhoto != 'everyone') {
          res['avatar_url'] = ''; // Or null
        }
      }

      return res;
    } catch (e) {
      debugPrint('[ChatRepo] Get user profile error: $e');
      return null;
    }
  }
}
