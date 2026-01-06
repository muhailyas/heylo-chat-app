import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heylo/core/services/voice_player_service.dart';
import 'package:heylo/features/chat/models/chat_message.dart';

class MessageInfoScreen extends ConsumerWidget {
  const MessageInfoScreen({
    super.key,
    required this.message,
    required this.peerName,
    required this.peerAvatar,
    required this.peerId,
  });

  final ChatMessage message;
  final String peerName;
  final String peerAvatar;
  final String peerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Details',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 32),

          // Simplified Message Preview
          Align(
            alignment: Alignment.centerRight,
            child: Hero(
              tag: message.id,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: message.isMe
                      ? theme.primaryColor
                      : (isDark ? Colors.grey[900] : Colors.grey[200]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: _MessageContent(
                  message: message,
                  color: message.isMe
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),

          const SizedBox(height: 48),

          // Clean Status List
          _buildInfoRow(
            context,
            icon: Icons.done_all_rounded,
            title: 'Read',
            time: message.seenAt,
            color: Colors.blueAccent,
            isActive: message.status == ChatDeliveryStatus.seen,
          ),
          _buildDivider(theme),
          _buildInfoRow(
            context,
            icon: Icons.done_all_rounded,
            title: 'Delivered',
            time:
                message.deliveredAt ??
                (message.status != ChatDeliveryStatus.sending
                    ? message.timestamp
                    : null),
            color: theme.colorScheme.onSurface,
            isActive:
                message.status == ChatDeliveryStatus.delivered ||
                message.status == ChatDeliveryStatus.seen,
          ),
          _buildDivider(theme),
          _buildInfoRow(
            context,
            icon: Icons.check_rounded,
            title: 'Sent',
            time: message.timestamp,
            color: theme.colorScheme.onSurface,
            isActive: true,
          ),

          const SizedBox(height: 60),

          // Bare recipient info
          Center(
            child: Text(
              'Sent to $peerName',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.4),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required DateTime? time,
    required Color color,
    required bool isActive,
  }) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isActive ? color : onSurface.withOpacity(0.1),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isActive ? onSurface : onSurface.withOpacity(0.2),
            ),
          ),
          const Spacer(),
          if (time != null)
            Text(
              _formatDateTime(time),
              style: TextStyle(fontSize: 14, color: onSurface.withOpacity(0.4)),
            )
          else
            Text('—', style: TextStyle(color: onSurface.withOpacity(0.1))),
        ],
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Divider(
      height: 1,
      thickness: 0.5,
      color: theme.dividerColor.withOpacity(0.05),
      indent: 36,
    );
  }

  String _formatDateTime(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }
}

class _MessageContent extends ConsumerWidget {
  const _MessageContent({required this.message, required this.color});
  final ChatMessage message;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    switch (message.type) {
      case ChatMessageType.text:
        return Text(
          message.content,
          style: TextStyle(color: color, fontSize: 16, height: 1.4),
        );
      case ChatMessageType.voice:
        final isPlaying = ref
            .watch(voicePlayerServiceProvider.notifier)
            .isPlaying(message.content);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: color,
            ),
            const SizedBox(width: 8),
            Text('Voice message', style: TextStyle(color: color)),
          ],
        );
      case ChatMessageType.image:
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(message.content, fit: BoxFit.cover),
        );
      case ChatMessageType.file:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file_rounded, color: color),
            const SizedBox(width: 8),
            const Text('Document', style: TextStyle(color: Colors.white)),
          ],
        );
      default:
        return Text('Message', style: TextStyle(color: color));
    }
  }
}
