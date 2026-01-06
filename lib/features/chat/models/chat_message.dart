import 'package:flutter/foundation.dart';

enum ChatDeliveryStatus { sending, sent, delivered, seen, failed }

enum ChatMessageType { text, image, voice, file, revoked, contact, call }

@immutable
class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String content;
  final ChatMessageType type;
  final DateTime timestamp;
  final bool isMe;
  final ChatDeliveryStatus status;

  // Replied message metadata
  final ChatMessage? repliedTo;
  final String? replyToId;

  // Revocation status
  final bool isRevoked;

  // Status timestamps (for Info screen)
  final DateTime? deliveredAt;
  final DateTime? seenAt;

  // voice-only UI metadata (NOT persisted)
  final Duration? voiceDuration;
  final List<double>? waveform;

  // Reactions: mapping of emoji to list of user IDs who reacted
  final Map<String, List<String>> reactions;

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    this.senderName = '',
    required this.content,
    required this.type,
    required this.timestamp,
    required this.isMe,
    required this.status,
    this.repliedTo,
    this.replyToId,
    this.isRevoked = false,
    this.deliveredAt,
    this.seenAt,
    this.voiceDuration,
    this.waveform,
    this.reactions = const {},
  });

  // ───────────── Outgoing ─────────────

  factory ChatMessage.outgoingText({
    required String tempId,
    required String chatId,
    required String senderId,
    required String content,
    ChatMessage? repliedTo,
  }) => ChatMessage(
    id: tempId,
    chatId: chatId,
    senderId: senderId,
    content: content,
    type: ChatMessageType.text,
    timestamp: DateTime.now(),
    isMe: true,
    status: ChatDeliveryStatus.sending,
    repliedTo: repliedTo,
  );

  factory ChatMessage.outgoingImage({
    required String tempId,
    required String chatId,
    required String senderId,
    required String localPath,
    ChatMessage? repliedTo,
  }) => ChatMessage(
    id: tempId,
    chatId: chatId,
    senderId: senderId,
    content: localPath,
    type: ChatMessageType.image,
    timestamp: DateTime.now(),
    isMe: true,
    status: ChatDeliveryStatus.sending,
    repliedTo: repliedTo,
  );

  factory ChatMessage.outgoingFile({
    required String tempId,
    required String chatId,
    required String senderId,
    required String localPath,
    ChatMessage? repliedTo,
  }) => ChatMessage(
    id: tempId,
    chatId: chatId,
    senderId: senderId,
    content: localPath,
    type: ChatMessageType.file,
    timestamp: DateTime.now(),
    isMe: true,
    status: ChatDeliveryStatus.sending,
    repliedTo: repliedTo,
  );

  factory ChatMessage.outgoingVoice({
    required String tempId,
    required String chatId,
    required String senderId,
    required String localPath,
    required Duration duration,
    List<double>? waveform,
    ChatMessage? repliedTo,
  }) => ChatMessage(
    id: tempId,
    chatId: chatId,
    senderId: senderId,
    content: localPath,
    type: ChatMessageType.voice,
    timestamp: DateTime.now(),
    isMe: true,
    status: ChatDeliveryStatus.sending,
    voiceDuration: duration,
    waveform: waveform,
    repliedTo: repliedTo,
  );

  // ───────────── Incoming (from ZIM) ─────────────

  factory ChatMessage.incoming({
    required String id,
    required String chatId,
    required String senderId,
    required String senderName,
    required String content,
    required ChatMessageType type,
    required DateTime timestamp,
    required bool isMe,
    Duration? voiceDuration,
    ChatMessage? repliedTo,
    String? replyToId,
    bool isRevoked = false,
  }) => ChatMessage(
    id: id,
    chatId: chatId,
    senderId: senderId,
    senderName: senderName,
    content: content,
    type: type,
    timestamp: timestamp,
    isMe: isMe,
    status: ChatDeliveryStatus.delivered,
    voiceDuration: voiceDuration,
    repliedTo: repliedTo,
    replyToId: replyToId,
    isRevoked: isRevoked,
  );

  ChatMessage copyWith({
    String? id,
    String? chatId,
    String? content,
    ChatDeliveryStatus? status,
    bool? isRevoked,
    DateTime? deliveredAt,
    DateTime? seenAt,
    ChatMessage? repliedTo,
    String? replyToId,
    Map<String, List<String>>? reactions,
  }) => ChatMessage(
    id: id ?? this.id,
    chatId: chatId ?? this.chatId,
    senderId: senderId,
    content: content ?? this.content,
    type: type,
    timestamp: timestamp,
    isMe: isMe,
    status: status ?? this.status,
    repliedTo: repliedTo ?? this.repliedTo,
    replyToId: replyToId ?? this.replyToId,
    isRevoked: isRevoked ?? this.isRevoked,
    deliveredAt: deliveredAt ?? this.deliveredAt,
    seenAt: seenAt ?? this.seenAt,
    voiceDuration: voiceDuration,
    waveform: waveform,
    reactions: reactions ?? this.reactions,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'sender_id': senderId,
    'sender_name': senderName,
    'content': content,
    'type': type.name,
    'created_at': timestamp.toIso8601String(),
    'status': status.name,
    'is_revoked': isRevoked,
    'delivered_at': deliveredAt?.toIso8601String(),
    'read_at': seenAt?.toIso8601String(),
    'duration_ms': voiceDuration?.inMilliseconds,
    'reply_to_id': replyToId,
    'reactions': reactions,
  };

  factory ChatMessage.fromMap(Map<String, dynamic> map, String currentUserId) {
    final typeStr = map['type'] as String? ?? 'text';
    final type = ChatMessageType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => ChatMessageType.text,
    );
    final statusStr = map['status'] as String? ?? 'sent';
    final status = ChatDeliveryStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => ChatDeliveryStatus.sent,
    );

    return ChatMessage(
      id: map['id'],
      chatId: '', // Adjusted later
      senderId: map['sender_id'],
      senderName: map['sender_name'] ?? '',
      content: _resolveContent(map, type),
      type: type,
      timestamp: DateTime.parse(map['created_at']),
      isMe: map['sender_id'] == currentUserId,
      status: status,
      isRevoked: map['is_revoked'] ?? false,
      deliveredAt: map['delivered_at'] != null
          ? DateTime.parse(map['delivered_at'])
          : null,
      seenAt: map['read_at'] != null ? DateTime.parse(map['read_at']) : null,
      voiceDuration: map['duration_ms'] != null
          ? Duration(milliseconds: map['duration_ms'])
          : null,
      replyToId: map['reply_to_id'],
      reactions:
          (map['reactions'] as Map<dynamic, dynamic>?)?.map(
            (k, v) => MapEntry(k.toString(), List<String>.from(v as List)),
          ) ??
          const {},
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  static String _resolveContent(
    Map<String, dynamic> map,
    ChatMessageType type,
  ) {
    final content = map['content'] as String? ?? '';
    final mediaUrl = map['media_url'] as String?;

    if (mediaUrl == null || mediaUrl.isEmpty) return content;

    switch (type) {
      case ChatMessageType.voice:
      case ChatMessageType.image:
        return mediaUrl;
      case ChatMessageType.file:
        return '$content|$mediaUrl';
      default:
        return content;
    }
  }
}
