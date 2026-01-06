import 'package:flutter/foundation.dart';

import '../../models/chat_message.dart';

@immutable
class ChatRoomState {
  final List<ChatMessage> messages;
  final bool isPaginating;
  final bool hasMore;
  final String? error;
  final ChatMessage? replyingTo;
  final String? peerName;
  final Duration recordingDuration;
  final bool isBlocked;
  final bool isLeftGroup;
  final bool isStranger;
  final bool showStrangerOptions;
  final Map<String, String> typingUsers;

  const ChatRoomState({
    this.messages = const [],
    this.isPaginating = true,
    this.hasMore = true,
    this.error,
    this.replyingTo,
    this.peerName,
    this.recordingDuration = Duration.zero,
    this.isBlocked = false,
    this.isLeftGroup = false,
    this.isStranger = false,
    this.showStrangerOptions = false,
    this.typingUsers = const {},
    this.recordingWaveform = const [],
  });

  final List<double> recordingWaveform;

  ChatRoomState copyWith({
    List<ChatMessage>? messages,
    bool? isPaginating,
    bool? hasMore,
    String? error,
    ChatMessage? replyingTo,
    String? peerName,
    Duration? recordingDuration,
    bool? isBlocked,
    bool? isLeftGroup,
    bool? isStranger,
    bool? showStrangerOptions,
    Map<String, String>? typingUsers,
    List<double>? recordingWaveform,
    bool clearReply = false,
  }) => ChatRoomState(
    messages: messages ?? this.messages,
    isPaginating: isPaginating ?? this.isPaginating,
    hasMore: hasMore ?? this.hasMore,
    error: error,
    replyingTo: clearReply ? null : (replyingTo ?? this.replyingTo),
    peerName: peerName ?? this.peerName,
    recordingDuration: recordingDuration ?? this.recordingDuration,
    isBlocked: isBlocked ?? this.isBlocked,
    isLeftGroup: isLeftGroup ?? this.isLeftGroup,
    isStranger: isStranger ?? this.isStranger,
    showStrangerOptions: showStrangerOptions ?? this.showStrangerOptions,
    typingUsers: typingUsers ?? this.typingUsers,
    recordingWaveform: recordingWaveform ?? this.recordingWaveform,
  );
}
