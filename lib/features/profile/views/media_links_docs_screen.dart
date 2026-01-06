import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/models/chat_message.dart';
import '../../chat/view_models/notifiers/chat_notifier.dart';

class MediaLinksDocsScreen extends ConsumerStatefulWidget {
  const MediaLinksDocsScreen({super.key, required this.peerId});

  final String peerId;

  static Future<T?> open<T>(BuildContext context, String peerId) {
    return Navigator.of(context).push<T>(
      MaterialPageRoute(builder: (_) => MediaLinksDocsScreen(peerId: peerId)),
    );
  }

  @override
  ConsumerState<MediaLinksDocsScreen> createState() =>
      _MediaLinksDocsScreenState();
}

class _MediaLinksDocsScreenState extends ConsumerState<MediaLinksDocsScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      animationDuration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatProvider(widget.peerId)).messages;

    final mediaItems = messages
        .where((m) => m.type == ChatMessageType.image)
        .toList();
    final linkItems = messages
        .where(
          (m) =>
              m.type == ChatMessageType.text &&
              (m.content.contains('http://') || m.content.contains('https://')),
        )
        .toList();
    final docItems = messages
        .where((m) => m.type == ChatMessageType.file)
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        title: Text(
          "Media, Links & Docs",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _tabBar(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const BouncingScrollPhysics(),
        children: [
          _mediaView(mediaItems),
          _linksView(linkItems),
          _docsView(docItems),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Container(
      color: Theme.of(context).cardColor,
      child: TabBar(
        dividerColor: Theme.of(context).colorScheme.primary,
        controller: _tabController,
        labelColor: Theme.of(context).colorScheme.onSurface,
        unselectedLabelColor: Theme.of(
          context,
        ).colorScheme.onSurface.withOpacity(.45),
        indicatorColor: Theme.of(context).colorScheme.primary,
        indicatorWeight: 2.8,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        tabs: const [
          Tab(text: "MEDIA"),
          Tab(text: "LINKS"),
          Tab(text: "DOCS"),
        ],
      ),
    );
  }

  Widget _mediaView(List<ChatMessage> items) {
    if (items.isEmpty) return _empty("No media found");

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemBuilder: (_, i) => _mediaTile(items[i]),
    );
  }

  Widget _mediaTile(ChatMessage m) {
    return InkWell(
      onTap: () {
        // Future: Media Preview
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          m.content,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: Theme.of(context).cardColor,
            child: const Icon(
              Icons.broken_image_rounded,
              color: Colors.white24,
            ),
          ),
        ),
      ),
    );
  }

  Widget _linksView(List<ChatMessage> items) {
    var theme = Theme.of(context);
    if (items.isEmpty) return _empty("No links shared");

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final m = items[i];
        return InkWell(
          onTap: () {
            // Future: Open Link
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: theme.colorScheme.onSurface.withOpacity(.07),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        theme.primaryColor.withOpacity(0.8),
                        theme.primaryColor,
                      ],
                    ),
                  ),
                  child: Icon(
                    Icons.link_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    m.content,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _docsView(List<ChatMessage> items) {
    var theme = Theme.of(context);
    if (items.isEmpty) return _empty("No documents found");

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final m = items[i];
        final parts = m.content.split('|');
        final name = parts.length == 2 ? parts[0] : parts[0].split('/').last;

        return InkWell(
          onTap: () {
            // Future: Open Document
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(.07)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        theme.primaryColor.withOpacity(0.8),
                        theme.primaryColor,
                      ],
                    ),
                  ),
                  child: const Icon(
                    Icons.insert_drive_file_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _empty(String label) {
    return Center(
      child: Text(
        label,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(.45),
          fontSize: 14,
        ),
      ),
    );
  }
}
