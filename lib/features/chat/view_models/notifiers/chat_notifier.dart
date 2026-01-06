import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:record/record.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/contact_provider.dart';
import '../../../../core/session/session_store.dart';
import '../../models/chat_message.dart';
import '../../repositories/chat_repo.dart';
import '../../repositories/group_repo.dart';
import '../state/chat_room_state.dart';

part 'chat_notifier.g.dart';

@riverpod
class ChatNotifier extends _$ChatNotifier {
  late final ChatRepo _repo;
  RealtimeChannel? _realtimeChannel;
  RealtimeChannel? _typingChannel;
  Timer? _typingTimer;
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _soundPlayer = AudioPlayer();

  String? _myId;
  late final String _chatRoomId;
  late final String _fullRoomId;
  late final bool _isGroup;
  String? _myName;

  // Pagination
  String? _lastCreatedAt; // Timestamp cursor for Supabase
  String? _clearedAt; // Local timestamp for "Clear Chat"
  static const int _page = 20;

  // Voice Recording
  DateTime? _recordStart;
  final List<double> _wave = [];
  Timer? _waveTimer;

  @override
  ChatRoomState build(String roomId) {
    _fullRoomId = roomId;
    if (roomId.startsWith('group:')) {
      _isGroup = true;
      _chatRoomId = roomId.substring(6);
    } else {
      _isGroup = false;
      _chatRoomId = roomId;
    }
    _repo = ChatRepo(Supabase.instance.client);
    _init();

    ref.onDispose(() {
      _realtimeChannel?.unsubscribe();
      _typingChannel?.unsubscribe();
      _typingTimer?.cancel();
      _soundPlayer.dispose();
    });

    return const ChatRoomState();
  }

  Future<void> _init() async {
    try {
      _myId = await SessionStore.readUid();
      if (!ref.mounted || _myId == null) return;

      if (_isGroup) {
        final groupRepo = GroupRepo(Supabase.instance.client);
        final role = await groupRepo.getMyGroupRole(_chatRoomId, _myId!);
        if (!ref.mounted) return;
        if (role == 'ex_member') {
          state = state.copyWith(isLeftGroup: true);
        }
      }

      await _loadInitial();
      if (!ref.mounted) return;
      if (!state.isLeftGroup) {
        _listenRealtime();
        _listenPresence();
      }

      if (!_isGroup) {
        // Check blocked status
        final blocked = await _repo.isBlocked(_myId!, _chatRoomId);
        if (!ref.mounted) return;
        state = state.copyWith(isBlocked: blocked);

        // Mark all current as read/delivered on entry
        await _repo.markAllAsDelivered(_myId!, _chatRoomId);
        await _repo.markAllAsRead(_myId!, _chatRoomId);
      }

      // Fetch my name for typing indicator
      final myProfile = await _repo.getUserProfile(_myId!);
      if (ref.mounted && myProfile != null) {
        _myName = myProfile['name'] as String?;
      }

      if (!_isGroup) {
        // Resolve stranger status
        final peerProfile = await _repo.getUserProfile(_chatRoomId);
        if (!ref.mounted) return;
        state = state.copyWith(peerName: peerProfile?['name'] as String?);
        final peerPhone = peerProfile?['phone'] as String?;
        if (peerPhone != null) {
          final contacts = await ref.read(localContactsProvider.future);
          if (!ref.mounted) return;
          final isSaved = contacts.containsKey(peerPhone);

          if (!isSaved) {
            // Check if we have incoming messages from this peer
            final hasIncoming = state.messages.any((m) => !m.isMe);
            state = state.copyWith(
              isStranger: true,
              showStrangerOptions: hasIncoming && !state.isBlocked,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[ChatNotifier] Init error: $e');
      if (ref.mounted) {
        state = state.copyWith(error: 'Failed to connect: $e');
      }
    }
  }

  Future<void> _loadClearedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _clearedAt = prefs.getString('cleared_at_$_fullRoomId');
  }

  Future<void> _playSentSound() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('pref_conversation_tones') ?? true;
      if (!enabled) return;

      // Ensure the asset path is correct and added to pubspec.yaml
      await _soundPlayer.setAsset(
        'assets/sounds/708605__marevnik__ui_pop_up.mp3',
      );
      await _soundPlayer.play();
    } catch (e) {
      debugPrint('Error playing sent sound: $e');
    }
  }

  // ───────────────── History ─────────────────

  Future<void> _loadInitial() async {
    if (_myId == null) return;

    await _loadClearedStatus();
    if (!ref.mounted) return;

    // Load from cache first
    await _loadCache();
    if (!ref.mounted) return;

    state = state.copyWith(isPaginating: true);
    try {
      final list = await _repo.history(
        myId: _myId!,
        peerId: _isGroup ? null : _chatRoomId,
        groupId: _isGroup ? _chatRoomId : null,
        limit: _page,
        createdAfter: _clearedAt,
      );
      if (!ref.mounted) return;

      if (list.isNotEmpty) {
        _lastCreatedAt = list.last['created_at'];
      }

      final mapped = list.map(_map).whereType<ChatMessage>().toList();
      state = state.copyWith(
        messages: _linkReplies(mapped),
        hasMore: list.length == _page,
        isPaginating: false,
        error: null,
      );

      // Save to cache
      _saveCache();
    } catch (e) {
      debugPrint('[ChatNotifier] Load initial error: $e');
      if (ref.mounted) {
        state = state.copyWith(
          isPaginating: false,
          error: state.messages.isEmpty
              ? 'Connection error. Please check your internet.'
              : null,
        );
      }
    }
  }

  Future<void> blockStranger() async {
    if (_myId == null || _isGroup) return;
    try {
      await _repo.blockUser(_myId!, _chatRoomId);
      if (ref.mounted) {
        state = state.copyWith(isBlocked: true, showStrangerOptions: false);
      }
    } catch (e) {
      debugPrint('[ChatNotifier] Block error: $e');
    }
  }

  void ignoreStranger() {
    state = state.copyWith(showStrangerOptions: false);
  }

  Future<void> refreshStrangerStatus() async {
    if (_isGroup) return;
    try {
      // Invalidate contacts to get fresh system data
      ref.invalidate(localContactsProvider);
      final contacts = await ref.read(localContactsProvider.future);
      if (!ref.mounted) return;

      final peerProfile = await _repo.getUserProfile(_chatRoomId);
      if (!ref.mounted) return;
      final peerPhone = peerProfile?['phone'] as String?;

      if (peerPhone != null && contacts.containsKey(peerPhone)) {
        state = state.copyWith(isStranger: false, showStrangerOptions: false);
      }
    } catch (e) {
      debugPrint('[ChatNotifier] Refresh stranger error: $e');
    }
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = state.messages.take(50).map((m) => m.toMap()).toList();
      await prefs.setString('chat_cache_$_fullRoomId', jsonEncode(data));
    } catch (e) {
      debugPrint('[ChatNotifier] Cache save error: $e');
    }
  }

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('chat_cache_$_fullRoomId');
      if (raw != null && _myId != null) {
        final List<dynamic> list = jsonDecode(raw);
        final messages = list
            .map(
              (m) =>
                  ChatMessage.fromMap(m, _myId!).copyWith(chatId: _fullRoomId),
            )
            .toList();
        state = state.copyWith(messages: _linkReplies(messages));
      }
    } catch (e) {
      debugPrint('[ChatNotifier] Cache load error: $e');
    }
  }

  Future<void> loadMore() async {
    if (state.isPaginating || !state.hasMore || _myId == null) return;

    state = state.copyWith(isPaginating: true);

    try {
      final list = await _repo.history(
        myId: _myId!,
        peerId: _isGroup ? null : _chatRoomId,
        groupId: _isGroup ? _chatRoomId : null,
        limit: _page,
        createdBefore: _lastCreatedAt,
        createdAfter: _clearedAt,
      );
      if (!ref.mounted) return;

      if (list.isEmpty) {
        state = state.copyWith(isPaginating: false, hasMore: false);
        return;
      }

      _lastCreatedAt = list.last['created_at'];
      final mapped = list.map(_map).whereType<ChatMessage>().toList();

      state = state.copyWith(
        messages: _linkReplies([...state.messages, ...mapped]),
        isPaginating: false,
        hasMore: list.length == _page,
      );
    } catch (e) {
      debugPrint('[ChatNotifier] Load more error: $e');
      if (ref.mounted) {
        state = state.copyWith(isPaginating: false);
      }
    }
  }

  // ───────────────── Realtime ─────────────────

  void _listenRealtime() {
    if (_myId == null) return;

    // Listen to NEW and UPDATED messages
    _realtimeChannel = _repo.subscribeRealtime(
      myId: _myId!,
      peerId: _isGroup ? null : _chatRoomId,
      groupId: _isGroup ? _chatRoomId : null,
      onChange: (payload, changeEvent) async {
        if (changeEvent == PostgresChangeEvent.insert) {
          // Fetch sender info if missing (for Realtime payloads)
          if (payload['sender'] == null) {
            final senderId = payload['sender_id'] as String?;
            if (senderId != null && senderId != _myId) {
              final profile = await _repo.getUserProfile(senderId);
              if (!ref.mounted) return;
              if (profile != null) {
                payload['sender'] = profile;
              }
            }
          }

          if (!ref.mounted) return;

          final newMsg = _map(payload);
          if (newMsg == null) return;

          // Prevent duplicates
          final exists = state.messages.any(
            (m) =>
                m.id == newMsg.id ||
                (m.status == ChatDeliveryStatus.sending &&
                    m.content == newMsg.content),
          );

          if (!exists) {
            state = state.copyWith(
              messages: _linkReplies([newMsg, ...state.messages]),
            );
            _saveCache();
          } else if (newMsg.isMe) {
            // Replace optimistic
            final index = state.messages.indexWhere(
              (m) =>
                  m.content == newMsg.content &&
                  m.status == ChatDeliveryStatus.sending,
            );
            if (index != -1) {
              final updated = List<ChatMessage>.from(state.messages);
              updated[index] = newMsg;
              state = state.copyWith(messages: _linkReplies(updated));
              _saveCache();
            }
          }

          if (!newMsg.isMe) {
            _repo.markDelivered(newMsg.id);
            _repo.markRead(newMsg.id);
          }
        } else if (changeEvent == PostgresChangeEvent.update) {
          final id = payload['id'];
          final updatedMsg = _map(payload);
          if (updatedMsg == null) return;

          final index = state.messages.indexWhere((m) => m.id == id);
          if (index != -1) {
            final oldMsg = state.messages[index];
            // Only update if something meaningful changed (status, content, type)
            if (oldMsg.status != updatedMsg.status ||
                oldMsg.type != updatedMsg.type ||
                oldMsg.isRevoked != updatedMsg.isRevoked ||
                oldMsg.content != updatedMsg.content ||
                !mapEquals(oldMsg.reactions, updatedMsg.reactions)) {
              final newItems = List<ChatMessage>.from(state.messages);
              newItems[index] = updatedMsg;
              state = state.copyWith(messages: _linkReplies(newItems));
              _saveCache();
            }
          }
        } else if (changeEvent == PostgresChangeEvent.delete) {
          final id = payload['id'];
          if (id != null) {
            state = state.copyWith(
              messages: state.messages.where((m) => m.id != id).toList(),
            );
            _saveCache();
          }
        }
      },
    );
  }

  void _listenPresence() {
    if (_myId == null) return;
    String channelId;
    if (_isGroup) {
      channelId = 'room:$_fullRoomId';
    } else {
      final ids = [_myId!, _chatRoomId]..sort();
      channelId = 'room:dm:${ids.join('_')}';
    }
    _typingChannel = Supabase.instance.client.channel(channelId);

    _typingChannel!
        .onPresenceSync((payload) => _updatePresence())
        .onPresenceJoin((payload) => _updatePresence())
        .onPresenceLeave((payload) => _updatePresence())
        .subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            // Just subscribed
          }
        });
  }

  void _updatePresence() {
    if (_typingChannel == null) return;
    final state_ = _typingChannel!.presenceState();
    final typingUsers = <String, String>{};

    for (final pState in state_) {
      for (final presence in pState.presences) {
        final payload = presence.payload;
        if (payload['is_typing'] == true && payload['user_id'] != _myId) {
          final uid = payload['user_id'] as String;
          final name = payload['name'] as String? ?? 'Someone';
          typingUsers[uid] = name;
        }
      }
    }
    state = state.copyWith(typingUsers: typingUsers);
  }

  Future<void> setTyping(bool typing) async {
    if (_myId == null || _typingChannel == null) return;

    // Throttle / Debounce
    if (typing) {
      await _typingChannel!.track({
        'user_id': _myId,
        'name': _myName ?? 'User',
        'is_typing': true,
      });
      if (!ref.mounted) return;
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 4), () {
        setTyping(false);
      });
    } else {
      await _typingChannel!.track({
        'user_id': _myId,
        'name': _myName ?? 'User',
        'is_typing': false,
      });
      if (!ref.mounted) return;
      _typingTimer?.cancel();
    }
  }

  // ───────────────── Mapping ─────────────────

  ChatMessage? _map(Map<String, dynamic> row) {
    // Map Supabase row to ChatMessage
    final typeStr = row['type'] as String? ?? 'text';
    ChatMessageType type = switch (typeStr) {
      'image' => ChatMessageType.image,
      'voice' => ChatMessageType.voice,
      'file' => ChatMessageType.file,
      'call' => ChatMessageType.call,
      'revoked' => ChatMessageType.revoked,
      'contact' => ChatMessageType.contact,
      _ => ChatMessageType.text,
    };

    final isMe = row['sender_id'] == _myId;
    final dbStatusStr = row['status'] as String? ?? 'sent';
    final deliveryStatus = switch (dbStatusStr) {
      'delivered' => ChatDeliveryStatus.delivered,
      'read' => ChatDeliveryStatus.seen,
      _ => ChatDeliveryStatus.sent,
    };

    final deliveredAt = row['delivered_at'] as String?;
    final readAt = row['read_at'] as String?;

    final senderData = row['sender'] as Map<String, dynamic>?;
    final senderName =
        senderData?['name'] as String? ??
        (isMe ? 'You' : (state.peerName ?? 'User'));

    return ChatMessage(
      id: row['id'],
      chatId: _fullRoomId, // Use full prefixed ID for provider lookup
      senderId: row['sender_id'],
      senderName: senderName,
      content:
          row['content'] ??
          (type == ChatMessageType.text
              ? ''
              : row['media_url']), // Logic adjustment
      type: type,
      timestamp: DateTime.parse(row['created_at']).toLocal(),
      isMe: isMe,
      status: deliveryStatus,
      deliveredAt: deliveredAt != null
          ? DateTime.parse(deliveredAt).toLocal()
          : null,
      seenAt: readAt != null ? DateTime.parse(readAt).toLocal() : null,
      replyToId: (row['reply_to_id'] as Object?)?.toString(),
      // voice details
      voiceDuration: row['duration_ms'] != null
          ? Duration(milliseconds: row['duration_ms'])
          : null,
      isRevoked: row['is_revoked'] == true || type == ChatMessageType.revoked,
      reactions:
          (row['reactions'] as Map<dynamic, dynamic>?)?.map(
            (k, v) => MapEntry(k.toString(), List<String>.from(v as List)),
          ) ??
          const {},
    );
  }

  List<ChatMessage> _linkReplies(List<ChatMessage> messages) {
    if (messages.isEmpty) return [];
    final map = {for (var m in messages) m.id: m};
    return messages.map((m) {
      if (m.replyToId != null && m.repliedTo == null) {
        final parent = map[m.replyToId];
        if (parent != null) {
          return m.copyWith(repliedTo: parent);
        }
      }
      return m;
    }).toList();
  }

  // NOTE: ChatMessage definition check.
  // Previous _map used content = url for media.
  //  content: content, // REMOTE URL

  // ───────────────── Sending ─────────────────

  Future<void> sendText(String text) async {
    if (state.isBlocked || state.isLeftGroup) return;
    if (text.isEmpty || _myId == null) return;

    final replyTo = state.replyingTo;

    // Optimistic Update: Insert fake message immediately
    final fakeMsg = ChatMessage(
      id: DateTime.now().toString(), // Temp ID
      chatId: _chatRoomId,
      senderId: _myId!,
      content: text,
      type: ChatMessageType.text,
      timestamp: DateTime.now(),
      isMe: true,
      status: ChatDeliveryStatus.sending,
      repliedTo: replyTo,
      replyToId: replyTo?.id,
    );

    // Update state immediately to show message
    state = state.copyWith(
      messages: [fakeMsg, ...state.messages],
      replyingTo: null,
      clearReply: true,
    );

    try {
      await _repo.sendText(
        senderId: _myId!,
        peerId: _isGroup ? null : _chatRoomId,
        groupId: _isGroup ? _chatRoomId : null,
        text: text,
        replyTo: replyTo,
      );
      _playSentSound();
    } catch (e) {
      debugPrint('Send error: $e');
      // Remove the message if failed
      if (ref.mounted) {
        state = state.copyWith(
          messages: state.messages.where((m) => m.id != fakeMsg.id).toList(),
        );
      }
    }
  }

  Future<void> sendImage() async {
    if (state.isBlocked || state.isLeftGroup) return;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (!ref.mounted || file == null || _myId == null) return;

    final replyTo = state.replyingTo;

    try {
      await _repo.sendImage(
        senderId: _myId!,
        peerId: _isGroup ? null : _chatRoomId,
        groupId: _isGroup ? _chatRoomId : null,
        chatId: _chatRoomId,
        file: File(file.path),
        replyTo: replyTo,
      );
      _playSentSound();
      if (ref.mounted) {
        state = state.copyWith(replyingTo: null, clearReply: true);
      }
    } catch (e) {
      debugPrint('Send image error: $e');
    }
  }

  Future<void> sendFile() async {
    if (state.isBlocked || state.isLeftGroup) return;
    final res = await FilePicker.platform.pickFiles();
    if (!ref.mounted) return;
    final path = res?.files.single.path;
    if (path == null || _myId == null) return;

    final replyTo = state.replyingTo;

    try {
      await _repo.sendFile(
        senderId: _myId!,
        peerId: _isGroup ? null : _chatRoomId,
        groupId: _isGroup ? _chatRoomId : null,
        chatId: _chatRoomId,
        file: File(path),
        replyTo: replyTo,
      );
      _playSentSound();
      if (ref.mounted) {
        state = state.copyWith(replyingTo: null, clearReply: true);
      }
    } catch (e) {
      print(e);
    }
  }

  // ───────────────── Helpers & Missing Methods ─────────────────

  void setPeerName(String name) {
    if (state.peerName == name) return;
    state = state.copyWith(peerName: name);
  }

  // Reply Logic
  void setReplyingTo(ChatMessage? message) {
    state = state.copyWith(replyingTo: message, clearReply: message == null);
  }

  // Deletion
  Future<void> deleteForMe(String messageId) async {
    // Stub: hide locally
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != messageId).toList(),
    );
  }

  Future<void> deleteForEveryone(ChatMessage message) async {
    if (message.isMe) {
      await _repo.revokeMessage(message.id);
    }
    if (!ref.mounted) return;
    // Optimistic remove depends on if you want to keep 'Revoked' msg or remove it.
    // Usually 'Unsend' replaces with 'This message was unsent'.
    // If we want to hide it completely:
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != message.id).toList(),
    );
  }

  Future<void> toggleReaction(String messageId, String emoji) async {
    if (_myId == null) return;
    try {
      await _repo.toggleReaction(
        messageId: messageId,
        userId: _myId!,
        emoji: emoji,
      );
    } catch (e) {
      debugPrint('Toggle reaction error: $e');
    }
  }

  // Camera
  Future<void> sendCamera() async {
    if (state.isBlocked || state.isLeftGroup) return;
    final file = await ImagePicker().pickImage(source: ImageSource.camera);
    if (!ref.mounted || file == null || _myId == null) return;
    try {
      await _repo.sendImage(
        senderId: _myId!,
        peerId: _isGroup ? null : _chatRoomId,
        groupId: _isGroup ? _chatRoomId : null,
        chatId: _chatRoomId,
        file: File(file.path),
        replyTo: state.replyingTo,
      );
      _playSentSound();
      if (ref.mounted) {
        state = state.copyWith(replyingTo: null);
      }
    } catch (e) {
      print(e);
    }
  }

  // Contact
  Future<void> sendContact(String name, String phone) async {
    if (state.isBlocked || state.isLeftGroup) return;
    if (_myId == null) return;

    final replyTo = state.replyingTo;

    // Optimistic Update
    final fakeMsg = ChatMessage(
      id: DateTime.now().toString(),
      chatId: _chatRoomId,
      senderId: _myId!,
      senderName: 'You',
      content: '$name|$phone',
      type: ChatMessageType.contact,
      timestamp: DateTime.now(),
      isMe: true,
      status: ChatDeliveryStatus.sending,
      repliedTo: replyTo,
      replyToId: replyTo?.id,
    );

    state = state.copyWith(
      messages: _linkReplies([fakeMsg, ...state.messages]),
      replyingTo: null,
      clearReply: true,
    );

    try {
      await _repo.sendContact(
        senderId: _myId!,
        peerId: _isGroup ? null : _chatRoomId,
        groupId: _isGroup ? _chatRoomId : null,
        name: name,
        phone: phone,
        replyTo: replyTo,
      );
      _playSentSound();
    } catch (e) {
      debugPrint('Send contact error: $e');
      if (ref.mounted) {
        state = state.copyWith(
          messages: state.messages.where((m) => m.id != fakeMsg.id).toList(),
        );
      }
    }
  }

  // Clear Unread
  Future<void> clearUnread() async {
    // Stub: Supabase doesn't track unread count natively without a separate table.
    // We assume opening the specific chat clears it in UI state if we were tracking it.
  }
  Future<void> clearChat() async {
    if (state.messages.isEmpty) return;

    // Use the timestamp of the most recent message as the "cleared" point.
    // This relies on Server Time (via the message) rather than Local Time,
    // avoiding issues where Local Time > Server Time (Clock Skew) would cause
    // valid new messages to be hidden.
    final latestMessageTime = state.messages.first.timestamp.toUtc();
    final cutoff = latestMessageTime.toIso8601String();

    // 1. Update State
    state = state.copyWith(messages: []);

    // 2. Clear Persistence Cache
    _saveCache();

    // 3. Save Cleared Timestamp Locally
    _clearedAt = cutoff;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cleared_at_$_fullRoomId', cutoff);
  }

  // Voice Cancel
  Future<void> cancelVoice() async {
    _waveTimer?.cancel();
    await _recorder.stop();
    state = state.copyWith(
      recordingDuration: Duration.zero,
      recordingWaveform: [],
    );
    // Do not send
  }

  // Load until found (deep linking/search support)
  Future<bool> loadUntilMessageFound(String id) async {
    if (state.messages.any((m) => m.id == id)) return true;
    // Naive implementation: load more until found
    int safety = 0;
    while (state.hasMore && safety < 10) {
      final oldLen = state.messages.length;
      await loadMore();
      if (state.messages.any((m) => m.id == id)) return true;
      if (state.messages.length == oldLen) break;
      safety++;
    }
    return false;
  }

  Future<void> startVoice() async {
    if (state.isBlocked || state.isLeftGroup) return;
    if (!await _recorder.hasPermission()) return;

    _wave.clear();
    _recordStart = DateTime.now();

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path:
          '${Directory.systemTemp.path}/${DateTime.now().millisecondsSinceEpoch}.m4a',
    );

    // UI Waveform & Duration
    _waveTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      final amp = await _recorder.getAmplitude();
      final val = (amp.current + 160) / 160; // Normalize -160..0 db to 0..1
      _wave.add(val.clamp(0.0, 1.0));

      // Keep only last 40 points for visualization
      if (_wave.length > 40) {
        _wave.removeAt(0);
      }

      if (_recordStart != null) {
        state = state.copyWith(
          recordingDuration: DateTime.now().difference(_recordStart!),
          recordingWaveform: List.from(_wave),
        );
      }
    });
  }

  Future<void> logCallMessage({
    required bool isVideo,
    required int durationSeconds,
  }) async {
    if (_myId == null) return;
    try {
      await _repo.sendCallMessage(
        senderId: _myId!,
        peerId: _isGroup ? null : _chatRoomId,
        isVideo: isVideo,
        durationSeconds: durationSeconds,
      );
    } catch (e) {
      debugPrint('[ChatNotifier] Log call error: $e');
    }
  }

  Future<void> stopVoice() async {
    _waveTimer?.cancel();
    final path = await _recorder.stop();
    if (!ref.mounted) return;

    final replyTo = state.replyingTo;

    state = state.copyWith(
      recordingDuration: Duration.zero,
      recordingWaveform: [],
    );

    if (path == null || _myId == null || _recordStart == null) return;

    final duration = DateTime.now().difference(_recordStart!);

    try {
      await _repo.sendVoice(
        senderId: _myId!,
        peerId: _isGroup ? null : _chatRoomId,
        groupId: _isGroup ? _chatRoomId : null,
        chatId: _chatRoomId,
        file: File(path),
        duration: duration,
        replyTo: replyTo,
      );
      _playSentSound();
      if (ref.mounted) {
        state = state.copyWith(replyingTo: null, clearReply: true);
      }
    } catch (e) {
      print(e);
    }
  }

  // ───────────────── Blocking ─────────────────

  Future<void> blockUser() async {
    if (_isGroup) return; // Cannot block groups in this simple flow
    if (_myId == null) return;
    try {
      await _repo.blockUser(_myId!, _chatRoomId);
      state = state.copyWith(isBlocked: true);
    } catch (e) {
      debugPrint('Block user error: $e');
    }
  }

  Future<void> unblockUser() async {
    if (_isGroup) return;
    if (_myId == null) return;
    try {
      await _repo.unblockUser(_myId!, _chatRoomId);
      state = state.copyWith(isBlocked: false);
    } catch (e) {
      debugPrint('Unblock user error: $e');
    }
  }
}
