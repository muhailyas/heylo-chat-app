// Calls tab — displays recent call logs
// File: lib/features/home/tabs/calls_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heylo/core/providers/contact_provider.dart';
import 'package:heylo/core/router/route_generator.dart';
import 'package:heylo/features/auth/view_model/notifiers/auth_notifier.dart';
import 'package:heylo/features/calls/view_models/notifiers/call_history_notifier.dart';
import 'package:heylo/features/home/views/tabs/chats_tab.dart';
import 'package:heylo/features/home/views/widgets/calls_tile.dart';
import 'package:heylo/features/home/views/widgets/empty_state_widget.dart';
import 'package:heylo/features/profile/view_models/notifiers/profile_notifier.dart';

class CallsTab extends ConsumerWidget {
  const CallsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authProvider).userId;
    if (userId == null) return const Center(child: Text("Not signed in"));

    final historyAsync = ref.watch(callHistoryProvider(userId));

    return historyAsync.when(
      data: (records) {
        if (records.isEmpty) {
          return Center(
            child: EmptyStateWidget(
              icon: Icons.call_rounded,
              title: "No call history yet",
              subtitle: "Your recent calls will appear here",
              actionLabel: "Start a call",
              onAction: () {
                Navigator.pushNamed(context, RouteGenerator.newChatContact);
              },
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const BouncingScrollPhysics(),
          itemCount: records.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final record = records[i];
            final isIncoming = record.receiverId == userId;
            final peerId = isIncoming ? record.callerId : record.receiverId;

            return Consumer(
              builder: (context, ref, child) {
                final profileAsync = ref.watch(profileByUidProvider(peerId));
                final userModel = profileAsync.value;
                final phone = userModel?.phone;

                final savedName = phone != null
                    ? ref.watch(contactNameProvider(phone))
                    : null;

                final String displayName;
                final String? secondaryName;

                if (savedName != null) {
                  displayName = savedName;
                  secondaryName = null;
                } else if (phone != null) {
                  displayName = phone;
                  secondaryName = userModel?.name;
                } else {
                  displayName = userModel?.name ?? peerId;
                  secondaryName = null;
                }

                final heroTag = 'call_${record.id}';

                return CallTile(
                  name: displayName,
                  peerId: peerId,
                  secondaryName: secondaryName,
                  avatarUrl: userModel?.avatarUrl,
                  type: record.callType.toLowerCase() == 'video'
                      ? "Video"
                      : "Voice",
                  time: _formatTime(record.startedAt),
                  isIncoming: isIncoming,
                  status: record.status,
                  heroTag: heroTag,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      RouteGenerator.chatRoom,
                      arguments: ChatRoomArgs(
                        name: displayName,
                        peerId: peerId,
                        avatarUrl: userModel?.avatarUrl ?? '',
                        phone: phone ?? '',
                        heroTag: heroTag,
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text("Error: $e")),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24 && date.day == now.day) {
      final h = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final m = date.minute.toString().padLeft(2, '0');
      final p = date.hour >= 12 ? "PM" : "AM";
      return "$h:$m $p";
    }
    if (diff.inDays < 7) {
      final days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
      return days[date.weekday - 1];
    }
    return "${date.day}/${date.month}/${date.year}";
  }
}
