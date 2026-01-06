import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heylo/features/auth/view_model/notifiers/auth_notifier.dart';
import 'package:heylo/features/chat/view_models/notifiers/global_typing_notifier.dart';
import 'package:heylo/features/chat/view_models/notifiers/user_presence_notifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/providers/contact_provider.dart';
import '../../../../core/router/route_generator.dart';
import '../../view_models/notifiers/conversation_notifier.dart';
import '../../view_models/states/chat_search_query_provider.dart';
import '../../view_models/states/message_search_provider.dart';
import '../widgets/chat_list_shimmer.dart';
import '../widgets/chat_tile.dart';
import '../widgets/empty_state_widget.dart';

class ChatsTab extends ConsumerWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationAsync = ref.watch(conversationProvider);
    final searchQuery = ref.watch(chatSearchQueryProvider).toLowerCase();

    // Get current user ID robustly via authProvider
    final authState = ref.watch(authProvider);
    final currentUserId =
        authState.userId ?? Supabase.instance.client.auth.currentUser?.id;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: conversationAsync.when(
        data: (state) {
          final allConversations = state.items;
          final conversations = searchQuery.isEmpty
              ? allConversations
              : allConversations
                    .where((c) => c.name.toLowerCase().contains(searchQuery))
                    .toList();

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(conversationProvider.future);
              if (searchQuery.isNotEmpty) {
                return ref.refresh(messageSearchProvider.future);
              }
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                if (conversations.isNotEmpty) ...[
                  if (searchQuery.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "Contacts",
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final item = conversations[i];
                      // Presence
                      final presenceState = ref.watch(userPresenceProvider);
                      final isOnline =
                          !item.isGroup &&
                          (presenceState[item.peerId] ?? false);
                      // Typing
                      final typingState = ref.watch(globalTypingProvider);
                      final typingUsers = typingState[item.peerId] ?? [];

                      return Consumer(
                        builder: (context, ref, child) {
                          final savedName = item.profile?.phone != null
                              ? ref.watch(
                                  contactNameProvider(item.profile!.phone),
                                )
                              : null;
                          final String displayName =
                              savedName ??
                              (item.name.isNotEmpty ? item.name : item.peerId);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ChatTile(
                              name: displayName,
                              message: item.lastMessageContent,
                              time:
                                  "${item.timestamp.hour}:${item.timestamp.minute.toString().padLeft(2, '0')}",
                              avatarUrl: item.avatarUrl,
                              unread: item.unreadCount,
                              peerId: item.peerId,
                              muted: false,
                              isOnline: isOnline,
                              heroTag: 'chat_${item.peerId}',
                              onTap: () {
                                final heroTag = 'chat_${item.peerId}';
                                Navigator.pushNamed(
                                  context,
                                  RouteGenerator.chatRoom,
                                  arguments: ChatRoomArgs(
                                    name: displayName,
                                    peerId: item.peerId,
                                    avatarUrl: item.avatarUrl,
                                    phone: item.profile?.phone ?? '',
                                    isGroup: item.isGroup,
                                    groupId: item.isGroup ? item.peerId : null,
                                    heroTag: heroTag,
                                  ),
                                );
                              },
                              typingUsers: typingUsers,
                              isGroup: item.isGroup,
                              searchQuery: searchQuery,
                            ),
                          );
                        },
                      );
                    }, childCount: conversations.length),
                  ),
                ],

                // Message Search Results
                if (searchQuery.isNotEmpty) ...[
                  Consumer(
                    builder: (context, ref, _) {
                      final messageSearch = ref.watch(messageSearchProvider);
                      return messageSearch.when(
                        data: (messages) {
                          if (messages.isEmpty) {
                            if (conversations.isEmpty) {
                              return SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Text(
                                    'No results found for "$searchQuery"',
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withOpacity(0.6),
                                        ),
                                  ),
                                ),
                              );
                            }
                            return const SliverToBoxAdapter(
                              child: SizedBox.shrink(),
                            );
                          }

                          return SliverMainAxisGroup(
                            slivers: [
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    0,
                                    16,
                                    0,
                                    8,
                                  ),
                                  child: Text(
                                    "Messages",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                              ),
                              SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  i,
                                ) {
                                  final msg = messages[i];
                                  final content = msg['content'] as String;
                                  final createdAt = DateTime.parse(
                                    msg['created_at'],
                                  );

                                  final sender =
                                      msg['sender'] as Map<String, dynamic>? ??
                                      {};
                                  final receiver =
                                      msg['receiver']
                                          as Map<String, dynamic>? ??
                                      {};

                                  final senderName = sender['name'] as String?;
                                  final senderPhone =
                                      sender['phone'] as String?;
                                  final senderAvatar =
                                      sender['avatar_url'] as String?;

                                  final receiverName =
                                      receiver['name'] as String?;
                                  final receiverPhone =
                                      receiver['phone'] as String?;
                                  final receiverAvatar =
                                      receiver['avatar_url'] as String?;

                                  final groupInfo =
                                      msg['groups'] as Map<String, dynamic>?;
                                  final groupName =
                                      groupInfo?['name'] as String?;
                                  final isGroupMsg = groupName != null;

                                  // Identify "Me" accurately
                                  final myId = currentUserId;
                                  final msgSenderId = msg['sender_id']
                                      ?.toString();
                                  final msgReceiverId = msg['receiver_id']
                                      ?.toString();

                                  // Boolean check: Did I send this?
                                  final isMe = (msgSenderId == myId);

                                  // DISPLAY LOGIC
                                  String displayName;
                                  String messagePrefix = '';

                                  if (isGroupMsg) {
                                    displayName = groupName ?? 'Group';
                                    final sName =
                                        (senderName != null &&
                                            senderName.isNotEmpty)
                                        ? senderName
                                        : (senderPhone ?? 'Unknown');
                                    messagePrefix = isMe ? 'You: ' : '$sName: ';
                                  } else {
                                    // 1:1 Chat - The Title should ALWAYS represent the OTHER person
                                    if (isMe) {
                                      // I sent it -> Title is the Receiver
                                      displayName =
                                          (receiverName != null &&
                                              receiverName.isNotEmpty)
                                          ? receiverName
                                          : (receiverPhone ??
                                                msgReceiverId ??
                                                'Chat');
                                      messagePrefix = 'You: ';
                                    } else {
                                      // I received it -> Title is the Sender
                                      displayName =
                                          (senderName != null &&
                                              senderName.isNotEmpty)
                                          ? senderName
                                          : (senderPhone ??
                                                msgSenderId ??
                                                'Unknown');
                                      messagePrefix =
                                          ''; // No "Sender:" prefix in 1:1 subtitle
                                    }
                                  }
                                  final targetPeerId = isGroupMsg
                                      ? (msg['group_id'] ?? '')
                                      : (isMe
                                            ? (msgReceiverId ?? '')
                                            : (msgSenderId ?? ''));

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: ChatTile(
                                      name: displayName,
                                      peerId: targetPeerId,
                                      message: '$messagePrefix$content',
                                      time:
                                          "${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}",
                                      unread: 0,
                                      muted: false,
                                      onTap: () {
                                        // NAVIGATION LOGIC
                                        final targetNameForNav = displayName;
                                        String targetPeerId;
                                        String targetAvatar;
                                        bool isGroup = isGroupMsg;

                                        if (isGroup) {
                                          targetPeerId = msg['group_id'] ?? '';
                                          targetAvatar = '';
                                        } else {
                                          if (isMe) {
                                            // Message sent by me -> Navigate to Receiver's chat room
                                            targetPeerId = msgReceiverId ?? '';
                                            targetAvatar = receiverAvatar ?? '';
                                          } else {
                                            // Message received by me -> Navigate to Sender's chat room
                                            targetPeerId = msgSenderId ?? '';
                                            targetAvatar = senderAvatar ?? '';
                                          }
                                        }

                                        if (targetPeerId.isEmpty) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Cannot navigate: Target ID is missing.',
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        Navigator.pushNamed(
                                          context,
                                          RouteGenerator.chatRoom,
                                          arguments: ChatRoomArgs(
                                            name: targetNameForNav,
                                            peerId: targetPeerId,
                                            avatarUrl: targetAvatar,
                                            phone: '',
                                            isGroup: isGroup,
                                            groupId: isGroup
                                                ? targetPeerId
                                                : null,
                                            highlightMessageId: msg['id'],
                                          ),
                                        );
                                      },
                                      avatarUrl: isMe
                                          ? receiverAvatar
                                          : senderAvatar,
                                      searchQuery: searchQuery,
                                    ),
                                  );
                                }, childCount: messages.length),
                              ),
                            ],
                          );
                        },
                        loading: () =>
                            const SliverToBoxAdapter(child: ChatListShimmer()),
                        error: (err, _) => SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              'Error searching messages: $err',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],

                if (conversations.isEmpty && searchQuery.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyStateWidget(
                      title: "It's quiet here...",
                      subtitle:
                          "Start a new conversation to connect with your friends instantly.",
                      icon: Icons.chat_bubble_outline_rounded,
                      actionLabel: "Start Messaging",
                      onAction: () => Navigator.pushNamed(
                        context,
                        RouteGenerator.newChatContact,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () => const SingleChildScrollView(child: ChatListShimmer()),
        error: (err, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Error loading chats: $err"),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.refresh(conversationProvider),
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ChatRoomArgs {
  final String name;
  final String peerId;
  final String avatarUrl;
  final String phone;
  final bool isGroup;
  final String? groupId;
  final String? highlightMessageId;
  final String? heroTag;

  ChatRoomArgs({
    required this.name,
    required this.peerId,
    required this.avatarUrl,
    required this.phone,
    this.isGroup = false,
    this.groupId,
    this.highlightMessageId,
    this.heroTag,
  });
}
