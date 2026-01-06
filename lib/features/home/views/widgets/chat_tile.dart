import 'package:flutter/material.dart';
import 'package:heylo/core/widgets/avatar_image.dart';

class ChatTile extends StatelessWidget {
  final String name;
  final String message;
  final String time;
  final int unread;
  final bool muted;
  final String? avatarUrl;
  final bool isOnline;
  final VoidCallback onTap;
  final List<String> typingUsers;
  final bool isGroup;
  final String? searchQuery;
  final String peerId;

  const ChatTile({
    super.key,
    required this.name,
    required this.message,
    required this.time,
    required this.unread,
    required this.muted,
    required this.onTap,
    required this.peerId,
    this.avatarUrl,
    this.isOnline = false,
    this.typingUsers = const [],
    this.isGroup = false,
    this.searchQuery,
    this.heroTag,
  });

  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  AvatarImage(
                    url: avatarUrl,
                    radius: 26,
                    fallbackName: name,
                    heroTag: heroTag ?? 'avatar_$peerId',
                  ),
                  if (isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.scaffoldBackgroundColor,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: searchQuery != null && searchQuery!.isNotEmpty
                              ? _buildHighlightedText(
                                  context,
                                  theme,
                                  name,
                                  baseWeight: FontWeight.w600,
                                )
                              : Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                        Text(
                          time,
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: typingUsers.isNotEmpty
                              ? Text(
                                  typingUsers.isNotEmpty
                                      ? (isGroup
                                            ? (typingUsers.length == 1
                                                  ? '${typingUsers.first} is typing...'
                                                  : '${typingUsers.length} people are typing...')
                                            : 'Typing...')
                                      : message,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: typingUsers.isNotEmpty
                                        ? theme.colorScheme.primary
                                        : (unread > 0
                                              ? theme.colorScheme.onSurface
                                              : theme.colorScheme.onSurface
                                                    .withOpacity(0.6)),
                                    fontSize: 14,
                                    fontWeight:
                                        unread > 0 || typingUsers.isNotEmpty
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontStyle: typingUsers.isNotEmpty
                                        ? FontStyle.italic
                                        : FontStyle.normal,
                                  ),
                                )
                              : searchQuery != null && searchQuery!.isNotEmpty
                              ? _buildHighlightedText(
                                  context,
                                  theme,
                                  message,
                                  baseColor: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                )
                              : Text(
                                  message,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: unread > 0
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.onSurface
                                              .withOpacity(0.6),
                                    fontSize: 14,
                                    fontWeight: unread > 0
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    fontStyle: FontStyle.normal,
                                  ),
                                ),
                        ),
                        if (muted) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.volume_off_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ],
                        if (unread > 0) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              unread > 9 ? '9+' : unread.toString(),
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText(
    BuildContext context,
    ThemeData theme,
    String text, {
    Color? baseColor,
    FontWeight baseWeight = FontWeight.normal,
  }) {
    if (searchQuery == null || searchQuery!.isEmpty) {
      return Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: baseColor ?? theme.colorScheme.onSurface,
          fontWeight: baseWeight,
          fontSize: 14,
        ).copyWith(fontSize: baseWeight == FontWeight.w600 ? 16 : 14),
      );
    }

    final query = searchQuery!.toLowerCase();
    final textLower = text.toLowerCase();
    final matches = <TextSpan>[];

    int lastMatchEnd = 0;
    int index = textLower.indexOf(query);

    while (index != -1) {
      if (index > lastMatchEnd) {
        matches.add(
          TextSpan(
            text: text.substring(lastMatchEnd, index),
            style: TextStyle(
              color: baseColor ?? theme.colorScheme.onSurface,
              fontWeight: baseWeight,
              fontSize: baseWeight == FontWeight.w600 ? 16 : 14,
            ),
          ),
        );
      }

      matches.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: TextStyle(
            backgroundColor: theme.colorScheme.primaryContainer,
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w900,
            fontSize: baseWeight == FontWeight.w600 ? 16 : 14,
          ),
        ),
      );

      lastMatchEnd = index + query.length;
      index = textLower.indexOf(query, lastMatchEnd);
    }

    if (lastMatchEnd < text.length) {
      matches.add(
        TextSpan(
          text: text.substring(lastMatchEnd),
          style: TextStyle(
            color: baseColor ?? theme.colorScheme.onSurface,
            fontWeight: baseWeight,
            fontSize: baseWeight == FontWeight.w600 ? 16 : 14,
          ),
        ),
      );
    }

    return RichText(
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      text: TextSpan(children: matches),
    );
  }
}
