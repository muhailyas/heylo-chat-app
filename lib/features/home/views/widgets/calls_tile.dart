import 'package:flutter/material.dart';
import 'package:heylo/core/widgets/avatar_image.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

class CallTile extends StatelessWidget {
  final String name;
  final String? secondaryName;
  final String? avatarUrl;
  final String type; // 'Video' or 'Voice'
  final String time;
  final bool isIncoming;
  final String status; // 'completed', 'missed', 'rejected', 'cancelled'
  final String peerId;
  final VoidCallback? onTap;
  final String? heroTag;

  const CallTile({
    super.key,
    required this.name,
    required this.peerId,
    this.secondaryName,
    this.avatarUrl,
    required this.type,
    required this.time,
    required this.isIncoming,
    required this.status,
    this.onTap,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Status Logic
    final bool isMissed = status == 'missed' || status == 'rejected';

    // Icon and Color for the direction indicator
    IconData directionIcon;
    Color directionColor;
    String statusText;

    if (isIncoming) {
      if (isMissed) {
        directionIcon = Icons.call_missed_rounded;
        directionColor = theme.colorScheme.error;
        statusText = status == 'missed' ? "Missed" : "Declined";
      } else {
        directionIcon = Icons.call_received_rounded;
        directionColor = const Color(0xFF34C759); // Green
        statusText = "Incoming";
      }
    } else {
      directionIcon = Icons.call_made_rounded;
      if (status == 'cancelled') {
        directionColor = theme.colorScheme.onSurface.withOpacity(0.4);
        statusText = "Cancelled";
      } else if (isMissed) {
        directionColor = theme.colorScheme.error;
        statusText = "Not reached";
      } else {
        directionColor = theme.colorScheme.primary;
        statusText = "Outgoing";
      }
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: AvatarImage(
        url: avatarUrl,
        radius: 24,
        heroTag: heroTag ?? 'avatar_$peerId',
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: isMissed
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          if (secondaryName != null && secondaryName!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              secondaryName!,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.4),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Row(
          children: [
            Icon(directionIcon, size: 14, color: directionColor),
            const SizedBox(width: 4),
            Text(
              "$statusText  •  $time",
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
      trailing: ZegoSendCallInvitationButton(
        isVideoCall: type == 'Video',
        invitees: [ZegoUIKitUser(id: peerId, name: name)],
        resourceID: "heylo_call",
        iconSize: const Size(40, 40),
        buttonSize: const Size(44, 44),
        icon: ButtonIcon(
          icon: Icon(
            type == 'Video' ? Icons.videocam_rounded : Icons.call_rounded,
            color: theme.colorScheme.primary,
            size: 26,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}
