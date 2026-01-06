import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heylo/core/providers/connectivity_provider.dart';
import 'package:heylo/core/widgets/avatar_image.dart';
import 'package:heylo/core/widgets/empty_chat_state.dart';
import 'package:heylo/features/chat/view_models/notifiers/user_presence_notifier.dart';
import 'package:heylo/features/chat/views/message_info_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

import '../../../core/router/route_generator.dart';
import '../../../core/services/voice_player_service.dart';
import '../../../core/widgets/system_ui_handler.dart';
import '../../auth/view_model/notifiers/auth_notifier.dart';
import '../models/chat_message.dart';
import '../view_models/notifiers/chat_notifier.dart';
import 'media_viewer_screen.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.name,
    required this.peerId,
    required this.avatarUrl,
    required this.phone,
    this.isGroup = false,
    this.groupId,
    this.highlightMessageId,
    this.heroTag,
  });

  final String name;
  final String peerId;
  final String avatarUrl;
  final String phone;
  final bool isGroup;
  final String? groupId;
  final String? highlightMessageId;
  final String? heroTag;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  bool _hasText = false;
  bool _recording = false;
  final Map<String, GlobalKey> _messageKeys = {};
  bool _showScrollToBottom = false;
  String? _highlightedMessageId;
  List<String> _searchResults = [];
  int _currentMatchIndex = 0;

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _searchResults.clear();
      _currentMatchIndex = 0;
    });

    if (query.isEmpty) return;

    final messages = ref.read(chatProvider(_roomId)).messages;
    final matches = messages
        .where(
          (m) =>
              !m.isRevoked &&
              m.type == ChatMessageType.text &&
              m.content.toLowerCase().contains(query.toLowerCase()),
        )
        .toList();

    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No result found'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() {
      _searchResults = matches.map((m) => m.id).toList();
      // Start with the most recent (effectively the first found in standard iteration if list is desc?
      // Actually messages are simplified desc usually.
      // Let's assume list order.
      _currentMatchIndex = 0;
    });

    _scrollToMessage(_searchResults[_currentMatchIndex]);
  }

  void _nextMatch() {
    if (_searchResults.isEmpty) return;
    setState(() {
      if (_currentMatchIndex < _searchResults.length - 1) {
        _currentMatchIndex++;
      } else {
        _currentMatchIndex = 0; // Wrap around
      }
    });
    _scrollToMessage(_searchResults[_currentMatchIndex]);
  }

  void _prevMatch() {
    if (_searchResults.isEmpty) return;
    setState(() {
      if (_currentMatchIndex > 0) {
        _currentMatchIndex--;
      } else {
        _currentMatchIndex = _searchResults.length - 1; // Wrap around
      }
    });
    _scrollToMessage(_searchResults[_currentMatchIndex]);
  }

  void _clearSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchQuery = '';
        _searchController.clear();
        _searchResults.clear();
        _currentMatchIndex = 0;
      }
    });
  }

  String get _roomId =>
      widget.isGroup ? 'group:${widget.peerId}' : widget.peerId;

  Future<void> _scrollToMessage(String id) async {
    // 0. Wait for initial load to complete (otherwise loadUntilMessageFound will fail due to pagination lock)
    int waitCycles = 0;
    while (ref.read(chatProvider(_roomId)).isPaginating && waitCycles < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCycles++;
    }

    // 1. Check if message is already loaded
    // Read state directly
    final currentMessages = ref.read(chatProvider(_roomId)).messages;

    // Attempt to find message in current state
    bool found = currentMessages.any((m) => m.id == id);
    if (!found) {
      // Load history until found
      debugPrint('[ChatRoom] Message $id not loaded, searching history...');
      found = await ref
          .read(chatProvider(_roomId).notifier)
          .loadUntilMessageFound(id);
    }

    if (!found) {
      debugPrint('[ChatRoom] Target message $id could not be found.');
      return;
    }

    // 2. Wait for UI to rebuild with new messages
    await Future.delayed(const Duration(milliseconds: 300));

    // 3. Try to find the RenderObject via GlobalKey
    GlobalKey? key = _messageKeys[id];
    if (key?.currentContext == null) {
      // 4. If key is null, it means it's off-screen.
      // Re-read messages to get index accounting for Date Separators
      final messages = ref.read(chatProvider(_roomId)).messages;

      final List<dynamic> uiItems = [];
      final typingUsers = ref.read(chatProvider(_roomId)).typingUsers;
      final typingCount = typingUsers.length;

      // Add typing bubbles at the start of the reversed list
      for (int i = 0; i < typingCount; i++) {
        uiItems.add('typing');
      }

      for (int i = 0; i < messages.length; i++) {
        final m = messages[i];
        uiItems.add(m);

        final next = i + 1 < messages.length ? messages[i + 1] : null;
        if (next == null || !DateUtils.isSameDay(m.timestamp, next.timestamp)) {
          uiItems.add(m.timestamp);
        }
      }

      final rawIndex = uiItems.indexWhere(
        (item) => item is ChatMessage && item.id == id,
      );

      if (rawIndex != -1) {
        if (rawIndex > 15 && _scroll.hasClients) {
          debugPrint(
            '[ChatRoom] Deep link detected (index $rawIndex). Jumping to max extent.',
          );
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        } else {
          // For recent messages, a rough jump is fine avoiding large jumps
          final roughOffset = rawIndex * 100.0;
          if (_scroll.hasClients) {
            _scroll.jumpTo(
              roughOffset.clamp(0.0, _scroll.position.maxScrollExtent),
            );
          }
        }

        // Wait for frame build / image layout
        await Future.delayed(const Duration(milliseconds: 600));
        key = _messageKeys[id];
      }
    }

    // 5. Final attempt to Ensure Visible
    if (key?.currentContext != null) {
      debugPrint(
        '[ChatRoom] Scroll target context found. Ensuring visible message $id.',
      );

      // Use PostFrameCallback to avoid semantics/layout assertion errors
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || key?.currentContext == null) return;

        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          alignment: 0.5,
        );

        setState(() => _highlightedMessageId = id);
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted && _highlightedMessageId == id) {
            setState(() => _highlightedMessageId = null);
          }
        });
      });
    } else {
      debugPrint(
        '[ChatRoom] Still cannot find context for message $id after scrolling.',
      );
    }
  }

  DateTime? _lastSeen;
  String? _avatarUrl;
  bool _canShowPresence = true;
  int _newMessagesCount = 0;
  bool _canShowReadReceipts = true;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  StreamSubscription? _peerSub;
  String? _wallpaperPath;

  @override
  void initState() {
    super.initState();
    _loadWallpaper();

    // Clear unread count - TODO: Implement for Supabase messages
    // ZegoZimService.instance.clearConversationUnreadMessageCount ...
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      ref.read(chatProvider(_roomId).notifier).clearUnread();
    });
    // Reset voice positions & playback when entering the room
    Future.microtask(() {
      if (mounted) {
        ref.read(voicePlayerServiceProvider.notifier).reset();
        ref.read(chatProvider(_roomId).notifier).setPeerName(widget.name);
        _avatarUrl = widget.avatarUrl;
        _fetchPeerInfo();

        if (widget.highlightMessageId != null) {
          debugPrint('Highlighting message: ${widget.highlightMessageId}');
          _scrollToMessage(widget.highlightMessageId!);
        }
      }
    });

    _scroll.addListener(_onScroll);
  }

  Future<void> _loadWallpaper() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('wallpaper_$_roomId');
    if (path != null && File(path).existsSync()) {
      setState(() => _wallpaperPath = path);
    }
  }

  @override
  void dispose() {
    _peerSub?.cancel();
    _scroll.dispose();
    _input.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPeerInfo() async {
    if (widget.isGroup) return;

    // Initial fetch
    await _updatePeerInfo();

    // Listen for real-time updates to peer's status/privacy
    _peerSub = Supabase.instance.client
        .from('users')
        .stream(primaryKey: ['uid'])
        .eq('uid', widget.peerId)
        .listen((data) {
          if (data.isNotEmpty) {
            _parsePeerInfo(data.first);
          }
        });
  }

  Future<void> _updatePeerInfo() async {
    try {
      final res = await Supabase.instance.client
          .from('users')
          .select()
          .eq('uid', widget.peerId)
          .maybeSingle();
      if (res != null) _parsePeerInfo(res);
    } catch (e) {
      debugPrint('[ChatRoom] Failed to fetch peer info: $e');
    }
  }

  void _parsePeerInfo(Map<String, dynamic> res) {
    if (!mounted) return;
    setState(() {
      // Last Seen Privacy
      final lsPrivacy = res['privacy_last_seen'] as String? ?? 'everyone';
      if (lsPrivacy == 'everyone') {
        _canShowPresence = true;
        if (res['last_seen'] != null) {
          _lastSeen = DateTime.parse(res['last_seen']).toLocal();
        }
      } else {
        _canShowPresence = false;
        _lastSeen = null;
      }

      // Profile Photo Privacy
      final ppPrivacy = res['privacy_profile_photo'] as String? ?? 'everyone';
      if (ppPrivacy == 'everyone') {
        _avatarUrl = res['avatar_url'] as String?;
      } else {
        _avatarUrl = null;
      }

      // Read Receipt Privacy
      final rrPrivacy = res['privacy_read_receipts'] as String? ?? 'everyone';
      _canShowReadReceipts = rrPrivacy == 'everyone';
    });
  }

  void _onScroll() {
    final show = _scroll.offset > 200;
    if (show != _showScrollToBottom) {
      if (!show) _newMessagesCount = 0;
      setState(() => _showScrollToBottom = show);
    }

    // Pagination: trigger loadMore when near the 'top' (maxScrollExtent in reverse list)
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      ref.read(chatProvider(_roomId).notifier).loadMore();
    }
  }

  // ... inside build method, pass _lastSeen to _ChatAppBar ...
  // ... inside _ChatAppBar definition ...

  // We will do this in multiple steps or a larger replace if context allows.
  // Let's do the State changes and _fetchLastSeen first.

  void _scrollToBottom() {
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  // Reversed ListView handles bottom focus and keyboard automatically
  // No manual _scrollToBottom needed for basic flow

  // ───────────────── Actions ─────────────────

  Future<void> _sendText() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() => _hasText = false);
    await ref.read(chatProvider(_roomId).notifier).sendText(text);
  }

  Future<void> _pickImage() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      await ref.read(chatProvider(_roomId).notifier).sendImage();
    }
  }

  Future<void> _pickCamera() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      await ref.read(chatProvider(_roomId).notifier).sendCamera();
    }
  }

  Future<void> _pickFile() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      await ref.read(chatProvider(_roomId).notifier).sendFile();
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AttachmentOption(
                    icon: Icons.image_rounded,
                    label: 'Gallery',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage();
                    },
                  ),
                  _AttachmentOption(
                    icon: Icons.insert_drive_file_rounded,
                    label: 'Document',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      _pickFile();
                    },
                  ),
                  _AttachmentOption(
                    icon: Icons.person_rounded,
                    label: 'Contact',
                    color: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      _pickPhoneContact();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickPhoneContact() async {
    try {
      if (await Permission.contacts.request().isGranted) {
        // Small delay to ensure any existing transitions (like menu closing) are processed
        await Future.delayed(const Duration(milliseconds: 100));

        // Use WidgetsBinding to ensure we are in a stable state before opening external UI
        // This helps avoid the "Invalid state transition from inactive to paused" assertion
        // which occurs when Zego is conflicting with Flutter's lifecycle management.
        final contact = await FlutterContacts.openExternalPick();

        if (contact != null) {
          // Fetch full contact details as picking only returns basic info
          final fullContact = await FlutterContacts.getContact(contact.id);
          if (fullContact != null && fullContact.phones.isNotEmpty) {
            final name = fullContact.displayName;
            // Clean up phone number (remove spaces, etc.) for consistency
            final phone = fullContact.phones.first.number
                .replaceAll(RegExp(r'\s+'), '')
                .replaceAll('(', '')
                .replaceAll(')', '')
                .replaceAll('-', '');

            if (mounted) {
              ref.read(chatProvider(_roomId).notifier).sendContact(name, phone);
            }
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contacts permission denied')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking contact: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking contact: $e')));
      }
    }
  }

  Future<void> _toggleVoice({bool cancel = false}) async {
    final notifier = ref.read(chatProvider(_roomId).notifier);
    if (_recording) {
      if (cancel) {
        await notifier.cancelVoice();
      } else {
        await notifier.stopVoice();
      }
    } else {
      await notifier.startVoice();
    }
    setState(() => _recording = !_recording);
  }

  String _timeLabel(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }

  void _showMessageInfo(ChatMessage message) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessageInfoScreen(
          message: message,
          peerName: widget.name,
          peerAvatar: widget.avatarUrl,
          peerId: widget.peerId,
        ),
      ),
    );
  }

  // ───────────────── UI ─────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatProvider(_roomId));
    // Find the latest message sent by me that has been seen by the peer
    String? lastReadId;

    // NO FILTERING based on search query here. We want to show all messages.
    final visibleMessages = state.messages.where((m) => !m.isRevoked).toList();

    if (visibleMessages.isNotEmpty && _canShowReadReceipts) {
      // Find the latest message sent by me that has been seen.
      // logic: If there is a NEWER message from the peer (received after my message),
      // effectively the "Seen" label is redundant (or user requested to hide it).
      for (final m in visibleMessages) {
        if (!m.isMe) {
          // Found a newer message from someone else -> hide "Seen" on older messages
          break;
        }
        if (m.isMe && m.status == ChatDeliveryStatus.seen) {
          lastReadId = m.id;
          break;
        }
      }
    }

    ref.listen(chatProvider(_roomId), (prev, next) {
      if (prev != null && next.messages.length > prev.messages.length) {
        final firstNext = next.messages.isNotEmpty ? next.messages.first : null;
        final firstPrev = prev.messages.isNotEmpty ? prev.messages.first : null;

        // Only scroll to bottom if a NEW message was added at the START of the list (index 0)
        // AND it's a message sent by "me".
        if (firstNext != null && firstNext.id != firstPrev?.id) {
          if (!firstNext.isMe && _showScrollToBottom) {
            _newMessagesCount++;
          }
          if (firstNext.isMe) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _scrollToBottom(),
            );
          }
        }
      }
    });

    final List<dynamic> items = [];
    for (int i = 0; i < visibleMessages.length; i++) {
      final m = visibleMessages[i];
      items.add(m);

      final next = i + 1 < visibleMessages.length
          ? visibleMessages[i + 1]
          : null;
      if (next == null || !DateUtils.isSameDay(m.timestamp, next.timestamp)) {
        items.add(m.timestamp);
      }
    }

    // Add typing bubbles at the bottom (beginning of reversed list)
    if (state.typingUsers.isNotEmpty) {
      // Sort or just take values.
      // For now, show all typing users stacked.
      for (final entry in state.typingUsers.entries) {
        final name = entry.value;
        // Avoid showing bubble for self (already filtered in notifier, but good to be safe)
        items.insert(
          0,
          _TypingBubble(
            key: ValueKey('typing_${entry.key}'),
            isGroup: widget.isGroup,
            name: name,
          ),
        );
      }
    }

    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    return SystemUIHandler(
      scaffoldBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _ChatAppBar(
        name: widget.name,
        profileName: state.peerName,
        peerId: widget.peerId,
        phone: widget.phone,
        avatarUrl: _avatarUrl,
        isGroup: widget.isGroup,
        isStranger: state.isStranger,
        isSearching: _isSearching,
        lastSeen: _lastSeen,
        searchController: _searchController,
        onSearchChanged: _onSearchChanged,
        onToggleSearch: _clearSearch,
        onNextMatch: _nextMatch,
        onPrevMatch: _prevMatch,
        currentMatchIndex: _currentMatchIndex,
        totalMatches: _searchResults.length,
        onInfoResult: (result) {
          _loadWallpaper();
          if (result == 'search_messages') {
            setState(() => _isSearching = true);
          }
        },
        canShowPresence: _canShowPresence,
        heroTag: widget.heroTag,
      ),
      floatingActionButton: _buildFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          image: _wallpaperPath != null && File(_wallpaperPath!).existsSync()
              ? DecorationImage(
                  image: FileImage(File(_wallpaperPath!)),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: Column(
          children: [
            if (state.showStrangerOptions)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      "The sender is not in your contacts",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (state.peerName != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        "Heylo Profile: ${state.peerName}",
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: () => ref
                              .read(chatProvider(_roomId).notifier)
                              .blockStranger(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text("Block"),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () async {
                            final contact = Contact()
                              ..phones = [Phone(widget.phone)];
                            await FlutterContacts.openExternalInsert(contact);
                            ref
                                .read(chatProvider(_roomId).notifier)
                                .refreshStrangerStatus();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text("Add"),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => ref
                              .read(chatProvider(_roomId).notifier)
                              .ignoreStranger(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: const Text("Continue"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                child: state.messages.isEmpty
                    ? (state.isPaginating
                          ? const _ChatShimmer()
                          : const EmptyChatState())
                    : NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          if (notification is ScrollUpdateNotification) {
                            final metrics = notification.metrics;
                            if (metrics.pixels >=
                                metrics.maxScrollExtent - 500) {
                              ref
                                  .read(chatProvider(_roomId).notifier)
                                  .loadMore();
                            }
                          }
                          return false;
                        },
                        child: ListView.builder(
                          controller: _scroll,
                          cacheExtent: 4000,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          physics: const BouncingScrollPhysics(),
                          reverse: true,
                          itemCount:
                              items.length +
                              (state.isPaginating || !state.hasMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == items.length) {
                              if (state.isPaginating) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.blueAccent,
                                    ),
                                  ),
                                );
                              }
                              if (!state.hasMore &&
                                  visibleMessages.length >= 10) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 20,
                                    ),
                                    child: Text(
                                      "All messages loaded",
                                      style: TextStyle(
                                        color: Theme.of(context).disabledColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            }
                            final item = items[i];

                            if (item is Widget) return item; // For TypingBubble

                            if (item is DateTime) {
                              return _DateSeparator(date: item);
                            }

                            final m = item as ChatMessage;

                            // Check Previous (Older, Above)
                            bool isFirst = true;
                            if (i + 1 < items.length) {
                              final prev = items[i + 1];
                              if (prev is ChatMessage &&
                                  prev.senderId == m.senderId &&
                                  DateUtils.isSameDay(
                                    prev.timestamp,
                                    m.timestamp,
                                  )) {
                                isFirst = false;
                              }
                            }

                            // Check Next (Newer, Below)
                            bool isLast = true;
                            if (i > 0) {
                              final next = items[i - 1];
                              if (next is ChatMessage &&
                                  next.senderId == m.senderId &&
                                  DateUtils.isSameDay(
                                    next.timestamp,
                                    m.timestamp,
                                  )) {
                                isLast = false;
                              }
                            }

                            final isHighlighted = m.id == _highlightedMessageId;
                            return SwipeToReply(
                              onReply: () => ref
                                  .read(chatProvider(_roomId).notifier)
                                  .setReplyingTo(m),
                              child: _MessageBubble(
                                key: _messageKeys.putIfAbsent(
                                  m.id,
                                  () => GlobalKey(),
                                ),
                                message: m,
                                timeLabel: _timeLabel(m.timestamp),
                                onInfo: () => _showMessageInfo(m),
                                onReplyTap: _scrollToMessage,
                                isHighlighted: isHighlighted,
                                showSeenStatus: m.id == lastReadId,
                                highlightText:
                                    _isSearching && _searchQuery.isNotEmpty
                                    ? _searchQuery
                                    : null,
                                isGroup: widget.isGroup,
                                isFirstInSequence: isFirst,
                                isLastInSequence: isLast,
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(
                left: 8,
                right: 8,
                bottom: bottom == 0 ? 10 : bottom,
              ),
              child: state.isLeftGroup
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'You left this group',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.5),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : _ChatInputBar(
                      peerId: _roomId,
                      controller: _input,
                      hasText: _hasText,
                      recording: _recording,
                      onChanged: (v) {
                        setState(() => _hasText = v.trim().isNotEmpty);
                        ref
                            .read(chatProvider(_roomId).notifier)
                            .setTyping(v.trim().isNotEmpty);
                      },
                      onSend: _sendText,
                      onMic: _toggleVoice,
                      onCancelMic: () => _toggleVoice(cancel: true),
                      onShowAttachments: _showAttachmentMenu,
                      onCamera: _pickCamera,
                      recordingDuration: state.recordingDuration,
                      waveform: state.recordingWaveform,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFab() {
    if (!_showScrollToBottom) return null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 80),
      child: Badge(
        backgroundColor: Theme.of(context).colorScheme.primary,
        isLabelVisible: _newMessagesCount > 0,
        label: Text(
          '$_newMessagesCount',
          style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
        ),
        child: SizedBox(
          width: 40,
          height: 40,
          child: FloatingActionButton(
            onPressed: _scrollToBottom,
            backgroundColor: Theme.of(context).cardColor,
            elevation: 4,
            mini: true,
            child: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────── AppBar ─────────────────

class _ChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String name;
  final String? profileName;
  final String peerId;
  final String phone;
  final String? avatarUrl;
  final bool isGroup;
  final bool isStranger;
  final bool isSearching;
  final DateTime? lastSeen;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onToggleSearch;
  final VoidCallback? onNextMatch;
  final VoidCallback? onPrevMatch;
  final int totalMatches;
  final int currentMatchIndex;

  final Function(dynamic)? onInfoResult;
  final bool canShowPresence;
  final String? heroTag;

  const _ChatAppBar({
    required this.name,
    this.profileName,
    required this.peerId,
    required this.phone,
    this.avatarUrl,
    required this.isGroup,
    required this.isStranger,
    required this.isSearching,
    this.lastSeen,
    required this.searchController,
    required this.onSearchChanged,
    required this.onToggleSearch,
    this.onNextMatch,
    this.onPrevMatch,
    this.totalMatches = 0,
    this.currentMatchIndex = 0,
    this.onInfoResult,
    required this.canShowPresence,
    this.heroTag,
  });

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final diff = now.difference(lastSeen);
    if (diff.inMinutes < 1) {
      return 'Active just now';
    } else if (diff.inMinutes < 60) {
      return 'Active ${diff.inMinutes}m ago';
    } else if (diff.inHours < 24 && DateUtils.isSameDay(now, lastSeen)) {
      final h = lastSeen.hour % 12 == 0 ? 12 : lastSeen.hour % 12;
      final m = lastSeen.minute.toString().padLeft(2, '0');
      final ap = lastSeen.hour >= 12 ? 'PM' : 'AM';
      return 'Active today at $h:$m $ap';
    } else {
      final d = lastSeen.day.toString().padLeft(2, '0');
      final mo = lastSeen.month.toString().padLeft(2, '0');
      final h = lastSeen.hour % 12 == 0 ? 12 : lastSeen.hour % 12;
      final m = lastSeen.minute.toString().padLeft(2, '0');
      final ap = lastSeen.hour >= 12 ? 'PM' : 'AM';
      return 'Last seen $d/$mo at $h:$m $ap';
    }
  }

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overlayStyle = SystemUIHandler.overlayStyle(
      scaffoldBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
      statusBarColor: Theme.of(context).cardColor,
    );

    if (isSearching) {
      return AppBar(
        systemOverlayStyle: overlayStyle,
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: onToggleSearch,
        ),
        title: TextField(
          controller: searchController,
          autofocus: true,
          onChanged: onSearchChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) {
            // Optional: Jump to next on submit
            if (onNextMatch != null) onNextMatch!();
          },
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: 'Search messages...',
            hintStyle: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
            ),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (totalMatches > 0) ...[
            Center(
              child: Text(
                '${currentMatchIndex + 1}/$totalMatches',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
              onPressed: onNextMatch,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              onPressed: onPrevMatch,
            ),
          ],
        ],
      );
    }

    // Presence Logic
    final presenceState = ref.watch(userPresenceProvider);
    // Only show online if not group AND presence is true AND privacy allows it
    final isOnline =
        !isGroup && (presenceState[peerId] ?? false) && canShowPresence;

    return AppBar(
      systemOverlayStyle: overlayStyle,
      backgroundColor: Theme.of(context).cardColor,
      elevation: 0,
      leadingWidth: 42,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: InkWell(
        onTap: () async {
          final result = await Navigator.pushNamed(
            context,
            RouteGenerator.profileDetails,
            arguments: ProfileDetailsArgs(
              name: name,
              peerId: peerId,
              phone: phone,
              avatarUrl: avatarUrl ?? '',
              isGroup: isGroup,
            ),
          );
          if (onInfoResult != null) onInfoResult!(result);
        },
        child: Row(
          children: [
            AvatarImage(
              url: avatarUrl,
              radius: 18,
              fallbackName: name,
              heroTag: heroTag ?? 'avatar_$peerId',
              fontSize: 14,
            ),

            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isStranger ? phone : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (isStranger && profileName != null)
                    Text(
                      'Heylo: $profileName',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  else if (canShowPresence)
                    if (isOnline)
                      Text(
                        'Online',
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else if (lastSeen != null)
                      Text(
                        _formatLastSeen(lastSeen!),
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),

      actions: [
        if (!isGroup) ...[
          if (ref.watch(isOnlineProvider)) ...[
            ZegoSendCallInvitationButton(
              isVideoCall: true,
              invitees: [ZegoUIKitUser(id: peerId, name: name)],
              resourceID: "heylo_call",
              iconSize: const Size(40, 40),
              buttonSize: const Size(50, 50),
              icon: ButtonIcon(
                icon: Icon(
                  Icons.videocam_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onPressed: (code, message, invitees) {
                // Logging is now handled inside ZegoCallService events
              },
            ),
            ZegoSendCallInvitationButton(
              isVideoCall: false,
              invitees: [ZegoUIKitUser(id: peerId, name: name)],
              resourceID: "heylo_call",
              iconSize: const Size(40, 40),
              buttonSize: const Size(50, 50),
              icon: ButtonIcon(
                icon: Icon(
                  Icons.call_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              onPressed: (code, message, invitees) {
                // Logging is now handled inside ZegoCallService events
              },
            ),
          ] else ...[
            IconButton(
              icon: Icon(
                Icons.videocam_off_rounded,
                color: Theme.of(context).disabledColor,
              ),
              onPressed: null,
            ),
            IconButton(
              icon: Icon(
                Icons.phone_disabled_rounded,
                color: Theme.of(context).disabledColor,
              ),
              onPressed: null,
            ),
          ],
        ],
        IconButton(
          color: Theme.of(context).primaryColor,
          icon: Icon(Icons.search_rounded),
          onPressed: onToggleSearch,
        ),
      ],
    );
  }
}

// ───────────────── Message Bubble ─────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.timeLabel,
    required this.onInfo,
    required this.onReplyTap,
    this.isHighlighted = false,
    this.highlightText,
    this.showSeenStatus = false,
    this.isGroup = false,
    this.isFirstInSequence = true,
    this.isLastInSequence = true,
  });

  final ChatMessage message;
  final String timeLabel;
  final VoidCallback onInfo;
  final Function(String) onReplyTap;
  final bool isHighlighted;
  final String? highlightText;
  final bool showSeenStatus;
  final bool isGroup;
  final bool isFirstInSequence;
  final bool isLastInSequence;

  void showMenu(BuildContext context, WidgetRef ref) {
    const emojis = ['❤️', '😂', '😮', '😢', '😡', '👍'];
    final notifier = ref.read(chatProvider(message.chatId).notifier);
    final myId = ref.read(authProvider).userId;

    // Find current reaction
    String? currentReaction;
    if (myId != null) {
      for (final entry in message.reactions.entries) {
        if (entry.value.contains(myId)) {
          currentReaction = entry.key;
          break;
        }
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      isScrollControlled: true,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.9),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                // Reactions Bar
                Container(
                  height: 60,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: emojis.map((emoji) {
                      final isSelected = emoji == currentReaction;
                      return GestureDetector(
                        onTap: () {
                          notifier.toggleReaction(message.id, emoji);
                          Navigator.pop(context);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.2)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary.withOpacity(0.5),
                                    width: 1.5,
                                  )
                                : null,
                          ),
                          child: Transform.scale(
                            scale: isSelected ? 1.2 : 1.0,
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),
                // Actions List
                _ActionItem(
                  icon: Icons.reply_rounded,
                  label: 'Reply',
                  onTap: () {
                    Navigator.pop(context);
                    notifier.setReplyingTo(message);
                  },
                ),
                if (message.type == ChatMessageType.text)
                  _ActionItem(
                    icon: Icons.copy_rounded,
                    label: 'Copy',
                    onTap: () {
                      Navigator.pop(context);
                      Clipboard.setData(ClipboardData(text: message.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                  ),
                _ActionItem(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete for Me',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    notifier.deleteForMe(message.id);
                  },
                ),
                if (message.isMe && message.type != ChatMessageType.call)
                  _ActionItem(
                    icon: Icons.delete_sweep_rounded,
                    label: 'Unsend (Delete for Everyone)',
                    isDestructive: true,
                    onTap: () {
                      Navigator.pop(context);
                      notifier.deleteForEveryone(message);
                    },
                  ),
                if (message.isMe)
                  _ActionItem(
                    icon: Icons.info_outline_rounded,
                    label: 'Message Info',
                    onTap: () {
                      Navigator.pop(context);
                      onInfo();
                    },
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final theme = Theme.of(context);
        final isMe = message.isMe;
        final maxWidth = MediaQuery.sizeOf(context).width * 0.8;

        Widget body;
        bool builtInTime = false;

        // Common Time Widget
        final timeWidget = Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Text(
              timeLabel,
              style: TextStyle(
                color: isMe
                    ? Colors.white.withOpacity(0.7)
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                fontSize: 10,
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 4),
              if (message.status == ChatDeliveryStatus.sending)
                const Icon(
                  Icons.access_time_rounded,
                  size: 11,
                  color: Colors.white38,
                )
              else
                Icon(
                  message.status == ChatDeliveryStatus.sent
                      ? Icons.done_rounded
                      : Icons.done_all_rounded,
                  size: 13,
                  color: message.status == ChatDeliveryStatus.seen
                      ? Colors.lightBlueAccent
                      : Colors.white38,
                ),
            ],
          ],
        );

        // Reply Preview inside bubble
        Widget? replyPreview;
        if (message.repliedTo != null || message.replyToId != null) {
          replyPreview = _ReplyPreviewBubble(
            message: message.repliedTo,
            replyId: message.replyToId,
            onTap: message.replyToId != null
                ? () => onReplyTap.call(message.replyToId!)
                : null,
          );
        }

        // Content
        switch (message.type) {
          case ChatMessageType.text:
            builtInTime = true;
            body = Wrap(
              alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 8,
              runSpacing: 4,
              children: [
                highlightText != null && highlightText!.isNotEmpty
                    ? _buildHighlightedText(context, isMe)
                    : Text(
                        message.content,
                        style: TextStyle(
                          color: isMe
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                          fontSize: 15,
                        ),
                      ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: timeWidget,
                ),
              ],
            );
            break;
          case ChatMessageType.voice:
            body = _VoiceBubble(message: message);
            break;
          case ChatMessageType.image:
            body = InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MediaViewerScreen(url: message.content, isImage: true),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.network(
                  message.content,
                  width: 180,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
            );
            break;
          case ChatMessageType.file:
            final parts = message.content.split('|');
            final name = parts.length == 2
                ? parts[0]
                : parts[0].split('/').last;
            final url = parts.last;
            body = InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MediaViewerScreen(url: url, isImage: false),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.insert_drive_file_rounded,
                    color: isMe
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      name,
                      style: TextStyle(
                        color: isMe
                            ? Theme.of(context).colorScheme.onPrimary
                            : Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
            break;
          case ChatMessageType.call:
            final parts = message.content.split('|');
            final baseTitle = parts[0];
            final status = parts.length > 1
                ? parts[1]
                : ((message.voiceDuration?.inSeconds ?? 0) > 0
                      ? 'completed'
                      : 'missed');

            final isVideo = baseTitle.toLowerCase().contains('video');
            final duration = message.voiceDuration;

            String label = baseTitle;
            Color iconColor = isMe
                ? theme.colorScheme.onPrimary
                : theme.primaryColor;
            IconData iconData = isVideo
                ? Icons.videocam_rounded
                : Icons.call_rounded;

            if (status == 'missed') {
              label = message.isMe
                  ? "Outgoing Video Call"
                  : "Missed Video Call";
              if (!isVideo) {
                label = message.isMe
                    ? "Outgoing Voice Call"
                    : "Missed Voice Call";
              }
              iconColor = isMe
                  ? theme.colorScheme.onPrimary.withOpacity(0.8)
                  : Colors.redAccent;
              iconData = isVideo
                  ? Icons.videocam_off_rounded
                  : Icons.phone_missed_rounded;
            } else if (status == 'rejected') {
              label = message.isMe
                  ? "$baseTitle Declined"
                  : "Declined $baseTitle";
              iconColor = isMe
                  ? theme.colorScheme.onPrimary.withOpacity(0.8)
                  : Colors.redAccent;
              iconData = isVideo
                  ? Icons.videocam_off_rounded
                  : Icons.phone_disabled_rounded;
            } else if (status == 'cancelled') {
              label = message.isMe
                  ? "Canceled $baseTitle"
                  : "Missed $baseTitle";
              iconColor = isMe
                  ? theme.colorScheme.onPrimary.withOpacity(0.8)
                  : Colors.redAccent;
              iconData = isVideo
                  ? Icons.videocam_off_rounded
                  : Icons.phone_missed_rounded;
            } else if (status == 'completed' && duration != null) {
              final mins = duration.inMinutes;
              final secs = duration.inSeconds
                  .remainder(60)
                  .toString()
                  .padLeft(2, '0');
              label = "$baseTitle ($mins:$secs)";
              iconColor = isMe
                  ? theme.colorScheme.onPrimary
                  : theme.primaryColor;
            }

            body = Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (isMe ? Colors.white : iconColor).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    iconData,
                    color: isMe ? theme.colorScheme.onPrimary : iconColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color:
                          (status == 'missed' || status == 'rejected') && !isMe
                          ? Colors.redAccent
                          : (isMe
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurface),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            );
            break;
          case ChatMessageType.contact:
            body = _ContactBubble(content: message.content, isMe: isMe);
            break;
          default:
            body = const SizedBox.shrink();
            break;
        }

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onLongPress: () => showMenu(context, ref),
                    child: Hero(
                      tag: message.id,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(maxWidth: maxWidth),
                        decoration: BoxDecoration(
                          color: isMe
                              ? Theme.of(context).primaryColor
                              : (Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF2A2A2A)
                                    : const Color(0xFFF0F0F0)),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(
                              !isMe && !isFirstInSequence ? 4 : 18,
                            ),
                            topRight: Radius.circular(
                              isMe && !isFirstInSequence ? 4 : 18,
                            ),
                            bottomLeft: Radius.circular(
                              !isMe && !isLastInSequence ? 4 : 18,
                            ),
                            bottomRight: Radius.circular(
                              isMe && !isLastInSequence ? 4 : 18,
                            ),
                          ),
                          boxShadow: [
                            if (isHighlighted)
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(0.6),
                                blurRadius: 25,
                                spreadRadius: 8,
                              ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: isMe
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            if (!isMe &&
                                isGroup &&
                                isFirstInSequence &&
                                message.senderName.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  message.senderName,
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            if (replyPreview != null) ...[
                              replyPreview,
                              const SizedBox(height: 6),
                            ],
                            body,
                            if (!builtInTime) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: isMe
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                                children: [timeWidget],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (message.reactions.isNotEmpty)
                    Positioned(
                      bottom: -14,
                      right: isMe ? null : -8,
                      left: isMe ? -8 : null,
                      child: _ReactionPill(
                        reactions: message.reactions,
                        onTap: () => showMenu(context, ref),
                      ),
                    ),
                ],
              ),
              if (message.reactions.isNotEmpty) const SizedBox(height: 14),
              if (showSeenStatus && message.seenAt != null) ...[
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    'Seen ${formatSeenAt(message.seenAt!)}',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
              SizedBox(height: isLastInSequence ? 8 : 2),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHighlightedText(BuildContext context, bool isMe) {
    if (highlightText == null || highlightText!.isEmpty) {
      return Text(
        message.content,
        style: TextStyle(
          color: isMe
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.onSurface,
          fontSize: 15,
        ),
      );
    }

    final theme = Theme.of(context);
    final text = message.content;
    final query = highlightText!.toLowerCase();
    final textLower = text.toLowerCase();
    final matches = <TextSpan>[];

    int lastMatchEnd = 0;
    int index = textLower.indexOf(query);

    final baseStyle = TextStyle(
      color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
      fontSize: 15,
    );

    while (index != -1) {
      if (index > lastMatchEnd) {
        matches.add(
          TextSpan(text: text.substring(lastMatchEnd, index), style: baseStyle),
        );
      }

      matches.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: baseStyle.copyWith(
            backgroundColor: theme.colorScheme.primaryContainer,
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w900,
          ),
        ),
      );

      lastMatchEnd = index + query.length;
      index = textLower.indexOf(query, lastMatchEnd);
    }

    if (lastMatchEnd < text.length) {
      matches.add(
        TextSpan(text: text.substring(lastMatchEnd), style: baseStyle),
      );
    }

    return RichText(text: TextSpan(children: matches));
  }

  String formatSeenAt(DateTime seenAt) {
    final now = DateTime.now();
    final diff = now.difference(seenAt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${seenAt.day}/${seenAt.month}';
  }
}

class _ReplyPreviewBubble extends StatelessWidget {
  final ChatMessage? message;
  final String? replyId;
  final VoidCallback? onTap;
  const _ReplyPreviewBubble({this.message, this.replyId, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 3,
              height: 32,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message?.isMe == true
                        ? 'You'
                        : (message?.senderName.isNotEmpty == true
                              ? message!.senderName
                              : 'Message'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message?.type == ChatMessageType.text
                        ? message!.content
                        : (message?.type == ChatMessageType.voice &&
                              message?.voiceDuration != null)
                        ? '🎤 Voice Message (${message!.voiceDuration!.inSeconds}s)'
                        : message?.type == ChatMessageType.image
                        ? '📷 Image'
                        : message?.type == ChatMessageType.file
                        ? '📁 Document'
                        : message?.type == ChatMessageType.contact
                        ? '👤 Contact: ${message!.content.split('|').first}'
                        : ('Original message'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (message?.type == ChatMessageType.image) ...[
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  message!.content,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReplyInputPreview extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onCancel;
  const _ReplyInputPreview({required this.message, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.8),
            border: const Border(bottom: BorderSide(color: Colors.white10)),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.isMe
                          ? 'Replying to You'
                          : 'Replying to ${message.senderName}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message.type == ChatMessageType.text
                          ? message.content
                          : (message.type == ChatMessageType.voice &&
                                message.voiceDuration != null)
                          ? '🎤 Voice Message (${message.voiceDuration!.inSeconds}s)'
                          : message.type == ChatMessageType.image
                          ? '📷 Image'
                          : message.type == ChatMessageType.file
                          ? '📁 Document'
                          : message.type == ChatMessageType.contact
                          ? '👤 Contact: ${message.content.split('|').first}'
                          : '[${message.type.name}]',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.5),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              if (message.type == ChatMessageType.image) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    message.content,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                onPressed: onCancel,
                icon: Icon(
                  Icons.close_rounded,
                  size: 22,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                splashRadius: 24,
                tooltip: 'Cancel Reply',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceBubble extends ConsumerWidget {
  const _VoiceBubble({required this.message});

  final ChatMessage message;

  String fmt(Duration d) =>
      '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(
      builder: (context, ref, child) {
        final playerState = ref.watch(voicePlayerServiceProvider);
        final isActive = playerState.playingUrl == message.content;

        final duration = isActive
            ? (playerState.position)
            : (playerState.positions[message.content] ?? Duration.zero);

        final isSending = message.status == ChatDeliveryStatus.sending;
        final isBuffering = playerState.isBuffering == true && isActive;
        final isLoading = isSending || isBuffering;
        final isPlaying = playerState.isPlaying == true && isActive;

        final maxMs = (message.voiceDuration?.inMilliseconds ?? 0).toDouble();
        final currentMs = duration.inMilliseconds.toDouble().clamp(
          0.0,
          maxMs > 0 ? maxMs : 1.0,
        );
        final safeMax = maxMs > 0 ? maxMs : 1.0;

        return Container(
          constraints: const BoxConstraints(maxWidth: 210),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => ref
                    .read(voicePlayerServiceProvider.notifier)
                    .toggle(message.content),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isLoading
                        ? Icons.hourglass_empty_rounded
                        : (isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded),
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 2,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 5,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 10,
                        ),
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white.withOpacity(0.1),
                        thumbColor: Colors.white,
                      ),
                      child: Slider(
                        value: currentMs,
                        max: safeMax,
                        onChanged: (v) {
                          if (isActive) {
                            ref
                                .read(voicePlayerServiceProvider.notifier)
                                .seek(Duration(milliseconds: v.toInt()));
                          }
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            isActive
                                ? fmt(duration)
                                : fmt(message.voiceDuration ?? Duration.zero),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ContactBubble extends StatelessWidget {
  final String content; // Name|Phone
  final bool isMe;
  const _ContactBubble({required this.content, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final parts = content.split('|');
    final name = parts[0];
    final phone = parts.length > 1 ? parts[1] : '';

    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withOpacity(0.1),
                child: Icon(
                  Icons.person_rounded,
                  color: isMe
                      ? Colors.white.withOpacity(0.9)
                      : Theme.of(context).colorScheme.onSurface,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: isMe
                            ? Colors.white.withOpacity(0.9)
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (phone.isNotEmpty)
                      Text(
                        phone,
                        style: TextStyle(
                          color: isMe
                              ? Colors.white.withOpacity(0.9)
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            color: isMe
                ? Colors.white.withOpacity(0.5)
                : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
            height: 1,
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => saveToContacts(context, name, phone),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                child: Text(
                  'Add to Contacts',
                  style: TextStyle(
                    color: isMe
                        ? Colors.white.withOpacity(0.9)
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> saveToContacts(
    BuildContext context,
    String name,
    String phone,
  ) async {
    try {
      if (await Permission.contacts.request().isGranted) {
        final contact = Contact()
          ..name.first = name
          ..phones = [Phone(phone)];
        await contact.insert();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$name saved to contacts'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contacts permission denied')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving contact: $e')));
      }
    }
  }
}

class _ChatInputBar extends ConsumerStatefulWidget {
  final String peerId;
  final TextEditingController controller;
  final bool hasText;
  final bool recording;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final VoidCallback onMic;
  final VoidCallback onCancelMic;
  final VoidCallback onShowAttachments;
  final VoidCallback onCamera;
  final Duration recordingDuration;
  final List<double> waveform;

  const _ChatInputBar({
    required this.peerId,
    required this.controller,
    required this.hasText,
    required this.recording,
    required this.onChanged,
    required this.onSend,
    required this.onMic,
    required this.onCancelMic,
    required this.onShowAttachments,
    required this.onCamera,
    required this.recordingDuration,
    required this.waveform,
  });

  @override
  ConsumerState<_ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends ConsumerState<_ChatInputBar>
    with SingleTickerProviderStateMixin {
  bool isLocked = false;
  bool _wasCancelled = false;
  Offset dragOffset = Offset.zero;
  static const double lockThreshold = -60.0; // Slide Up
  static const double cancelThreshold =
      -120.0; // Slide Left, increased for safety

  @override
  void didUpdateWidget(_ChatInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.recording && oldWidget.recording) {
      if (mounted) {
        setState(() {
          isLocked = false;
          _wasCancelled = false;
          dragOffset = Offset.zero;
        });
      }
    }
  }

  void onLongPressStart(LongPressStartDetails details) {
    if (widget.hasText) return;
    widget.onMic(); // Start Recording
    HapticFeedback.mediumImpact();
    setState(() {
      isLocked = false;
      _wasCancelled = false;
      dragOffset = Offset.zero;
    });
  }

  void onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (widget.hasText || isLocked || _wasCancelled || !widget.recording) {
      return;
    }

    setState(() {
      // Update drag offset directly from origin
      dragOffset = details.localOffsetFromOrigin;

      // Lock Logic (Vertical) - Only if horizontal movement is minimal
      if (dragOffset.dy < lockThreshold && dragOffset.dx.abs() < 50) {
        isLocked = true;
        dragOffset = Offset.zero; // Reset offset logic once locked
        HapticFeedback.heavyImpact();
      }

      // Cancel Logic (Horizontal)
      if (dragOffset.dx < cancelThreshold) {
        _wasCancelled = true;
        widget.onCancelMic(); // Use onCancelMic for proper cleanup
        HapticFeedback.heavyImpact();
        dragOffset = Offset.zero;
      }
    });
  }

  void onLongPressEnd(LongPressEndDetails details) {
    if (widget.hasText) return;

    // If recording was cancelled or stopped externally, do not trigger send/start
    if (!widget.recording) {
      setState(() {
        dragOffset = Offset.zero;
        _wasCancelled = false;
      });
      return;
    }

    if (_wasCancelled) {
      // Already cancelled, do nothing.
    } else if (isLocked) {
      // Stay locked
    } else {
      // Valid release -> Send
      widget.onMic();
    }

    setState(() {
      dragOffset = Offset.zero;
      _wasCancelled = false; // Reset for safety
    });
  }

  // Helper for Slide Left Animation
  double get slidePercent {
    if (isLocked || !widget.recording || _wasCancelled) return 0.0;
    // Map 0 to cancelThreshold (e.g. -120) -> 0.0 to 1.0
    return (dragOffset.dx / cancelThreshold).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(chatProvider(widget.peerId)).isBlocked) {
      return buildBlockedUI(context);
    }

    final isRecording = widget.recording;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isRecording &&
                  ref.watch(chatProvider(widget.peerId)).replyingTo !=
                      null) ...[
                const SizedBox(height: 8),
                _ReplyInputPreview(
                  message: ref.watch(chatProvider(widget.peerId)).replyingTo!,
                  onCancel: () => ref
                      .read(chatProvider(widget.peerId).notifier)
                      .setReplyingTo(null),
                ),
                const SizedBox(height: 4),
              ],
              Row(
                children: [
                  // Left Actions
                  if (isRecording) ...[
                    // If user slides left, we can dim/fade the delete button or keep it
                    Opacity(
                      opacity: (1 - slidePercent).clamp(0.0, 1.0),
                      child: _CircleIconButton(
                        icon: Icons.delete_outline_rounded,
                        onTap: widget.onCancelMic,
                        iconColor: Colors.redAccent,
                      ),
                    ),
                  ] else ...[
                    _CircleIconButton(
                      icon: Icons.add_rounded,
                      onTap: widget.onShowAttachments,
                    ),
                    const SizedBox(width: 4),
                    _CircleIconButton(
                      icon: Icons.camera_alt_rounded,
                      onTap: widget.onCamera,
                    ),
                  ],

                  const SizedBox(width: 8),

                  // Middle Content
                  Expanded(
                    child: isRecording
                        ? _RecordingBar(
                            duration: widget.recordingDuration,
                            waveform: widget.waveform,
                            isLocked: isLocked,
                            slidePercent:
                                slidePercent, // Pass slide percent for opacity/anim
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surface.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.black.withOpacity(0.05),
                              ),
                            ),
                            child: TextField(
                              controller: widget.controller,
                              onChanged: widget.onChanged,
                              minLines: 1,
                              maxLines: 5,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Message...',
                                hintStyle: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).hintColor.withOpacity(0.5),
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                            ),
                          ),
                  ),

                  const SizedBox(width: 8),

                  // Right Action (Mic/Send)
                  // We animate this button moving left if sliding
                  Transform.translate(
                    offset: Offset(
                      isLocked ? 0 : dragOffset.dx.clamp(cancelThreshold, 0),
                      isLocked ? 0 : dragOffset.dy.clamp(lockThreshold, 0),
                    ),
                    child: _PrimaryActionButton(
                      isSend: widget.hasText || (isRecording && isLocked),
                      isRecording: isRecording,
                      isLocked: isLocked,

                      // If nearing cancel, show trash icon or shake?
                      // For now standard mic, maybe turn to trash if very close?
                      // Let's scale it down slightly if moving far away
                      onTap: widget.hasText || (isRecording && isLocked)
                          ? (widget.hasText ? widget.onSend : widget.onMic)
                          : null,
                      onLongPressStart: (widget.hasText || isLocked)
                          ? null
                          : onLongPressStart,
                      onLongPressMoveUpdate: (widget.hasText || isLocked)
                          ? null
                          : onLongPressMoveUpdate,
                      onLongPressEnd: (widget.hasText || isLocked)
                          ? null
                          : onLongPressEnd,
                    ),
                  ),
                ],
              ),

              // "Slide to lock" hint
              if (isRecording &&
                  !isLocked &&
                  dragOffset.dy < -10 &&
                  dragOffset.dx > -50)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.lock_open_rounded,
                        size: 12,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Slide up to lock",
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildBlockedUI(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'You blocked this contact',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () {
              ref.read(chatProvider(widget.peerId).notifier).unblockUser();
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: const Text(
                'Unblock',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 18,
          color: iconColor ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final bool isSend;
  final bool isRecording;
  final bool isLocked;
  final VoidCallback? onTap;
  final Function(LongPressStartDetails)? onLongPressStart;
  final Function(LongPressMoveUpdateDetails)? onLongPressMoveUpdate;
  final Function(LongPressEndDetails)? onLongPressEnd;

  const _PrimaryActionButton({
    required this.isSend,
    this.isRecording = false,
    this.isLocked = false,
    this.onTap,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    var primary = Theme.of(context).primaryColor;

    IconData icon;
    if (isSend) {
      icon = Icons.send_rounded;
    } else if (isLocked) {
      icon = Icons.send_rounded;
    } else if (isRecording) {
      icon = Icons.mic_rounded;
    } else {
      icon = Icons.mic_rounded;
    }

    return GestureDetector(
      onTap: onTap,
      onLongPressStart: onLongPressStart,
      onLongPressMoveUpdate: onLongPressMoveUpdate,
      onLongPressEnd: onLongPressEnd,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: primary,
          boxShadow: isRecording
              ? [
                  BoxShadow(
                    color: primary.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : null,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _RecordingBar extends StatelessWidget {
  final Duration duration;
  final List<double> waveform;
  final bool isLocked;
  final double slidePercent; // 0.0 to 1.0 (1.0 = canceled)

  const _RecordingBar({
    required this.duration,
    required this.waveform,
    required this.isLocked,
    this.slidePercent = 0.0,
  });

  String fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // As we slide delete (slidePercent goes 0 -> 1), fade out the timer/waveform
    final contentOpacity = (1 - slidePercent * 2).clamp(0.0, 1.0);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 0),
      child: Row(
        children: [
          // Content Area (Timer + Waveform)
          Expanded(
            child: Opacity(
              opacity: contentOpacity,
              child: Row(
                children: [
                  // Timer
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          fmt(duration),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Waveform
                  Expanded(
                    child: _NextLevelWaveform(
                      waveform: waveform,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Slide to Cancel Hint
          if (!isLocked)
            Transform.translate(
              offset: Offset(
                -slidePercent * 50,
                0,
              ), // Move text left as we slide
              child: Padding(
                padding: const EdgeInsets.only(left: 8.0, right: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.chevron_left_rounded,
                      size: 18,
                      color: slidePercent > 0.3
                          ? Colors.redAccent
                          : Colors.grey,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      "Slide to cancel",
                      style: TextStyle(
                        color: slidePercent > 0.3
                            ? Colors.redAccent
                            : Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NextLevelWaveform extends StatelessWidget {
  final List<double> waveform;
  final Color color;

  const _NextLevelWaveform({required this.waveform, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _NextLevelWavePainter(waveform: waveform, color: color),
      size: Size.infinite,
    );
  }
}

class _NextLevelWavePainter extends CustomPainter {
  final List<double> waveform;
  final Color color;

  _NextLevelWavePainter({required this.waveform, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;

    final count = waveform.length;
    if (count == 0) return;

    final gap = 2.0;
    final barWidth = 3.0;
    final centerY = size.height / 2;

    // Iterate backwards from right side
    double x = size.width;

    for (int i = count - 1; i >= 0; i--) {
      // Normalize value 0..1
      double val = waveform[i];

      // Calculate height symmetric around center
      double height = 4.0 + (val * (size.height - 4.0));

      // Opacity based on recency
      double opacity = 0.5 + 0.5 * (i / count);
      paint.color = color.withOpacity(opacity);

      // Draw rounded rect centered vertically
      final rect = RRect.fromLTRBR(
        x - barWidth,
        centerY - height / 2,
        x,
        centerY + height / 2,
        const Radius.circular(1.5),
      );

      canvas.drawRRect(rect, paint);

      x -= (barWidth + gap);
      if (x < 0) break;
    }
  }

  @override
  bool shouldRepaint(_NextLevelWavePainter oldDelegate) => true;
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 24),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(.1),
          ),
        ),
        child: Text(
          formatDate(date),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  String formatDate(DateTime d) {
    if (DateUtils.isSameDay(d, DateTime.now())) return "TODAY";
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (DateUtils.isSameDay(d, yesterday)) return "YESTERDAY";

    final months = [
      "JAN",
      "FEB",
      "MAR",
      "APR",
      "MAY",
      "JUN",
      "JUL",
      "AUG",
      "SEP",
      "OCT",
      "NOV",
      "DEC",
    ];
    return "${d.day} ${months[d.month - 1]} ${d.year}";
  }
}

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.2),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _ChatShimmer extends StatelessWidget {
  const _ChatShimmer();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark
          ? Colors.white.withOpacity(0.04)
          : Colors.grey.withOpacity(0.3),
      highlightColor: isDark
          ? Colors.white.withOpacity(0.08)
          : Colors.grey.withOpacity(0.1),
      period: const Duration(milliseconds: 1500),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        itemCount: 15,
        itemBuilder: (_, i) {
          final isMe = i % 3 == 0;
          return Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              width: 120 + (i % 7) * 30.0,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isMe ? const Radius.circular(0) : null,
                  bottomLeft: !isMe ? const Radius.circular(0) : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;

  const SwipeToReply({super.key, required this.child, required this.onReply});

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  double dragOffset = 0;
  double lastDragOffset = 0;
  bool triggered = false;

  @override
  void initState() {
    super.initState();
    controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
        )..addListener(() {
          setState(() {
            dragOffset = lastDragOffset * (1.0 - controller.value);
          });
        });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void onHorizontalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dx < 0) {
      // Swiping left
      setState(() {
        dragOffset += details.delta.dx;
        if (dragOffset < -60 && !triggered) {
          triggered = true;
          HapticFeedback.lightImpact();
        }
      });
    }
  }

  void onHorizontalDragEnd(DragEndDetails details) {
    if (triggered) {
      widget.onReply();
    }

    // Smoothly animate back to 0
    lastDragOffset = dragOffset;
    controller.forward(from: 0);

    setState(() {
      triggered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: onHorizontalDragUpdate,
      onHorizontalDragEnd: onHorizontalDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 24),
            child: AnimatedOpacity(
              opacity: dragOffset < -40 ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 100),
              child: Icon(
                Icons.reply_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Transform.translate(
            offset: Offset(dragOffset.clamp(-80, 0), 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _ReactionPill extends StatefulWidget {
  final Map<String, List<String>> reactions;
  final VoidCallback onTap;

  const _ReactionPill({
    super.key,
    required this.reactions,
    required this.onTap,
  });

  @override
  State<_ReactionPill> createState() => _ReactionPillState();
}

class _ReactionPillState extends State<_ReactionPill>
    with SingleTickerProviderStateMixin {
  late AnimationController controller;
  late Animation<double> scaleAnimation;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    scaleAnimation = CurvedAnimation(
      parent: controller,
      curve: Curves.elasticOut,
    );
    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: scaleAnimation,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Wrap(
            spacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...widget.reactions.entries.map((entry) {
                return Text(entry.key, style: const TextStyle(fontSize: 12));
              }),
              if (widget.reactions.values.any((u) => u.length > 1) ||
                  widget.reactions.length > 3)
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    '${widget.reactions.values.expand((e) => e).length}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDestructive
              ? Colors.redAccent.withOpacity(0.1)
              : Theme.of(context).colorScheme.surface,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isDestructive
              ? Colors.redAccent
              : Theme.of(context).colorScheme.onSurface,
          size: 20,
        ),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive
              ? Colors.redAccent
              : Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}

class _TypingBubble extends StatefulWidget {
  final bool isGroup;
  final String name;

  const _TypingBubble({super.key, required this.isGroup, required this.name});

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with TickerProviderStateMixin {
  late AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        // margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 14),
        constraints: const BoxConstraints(maxWidth: 100),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isGroup && widget.name.isNotEmpty) ...[
              Text(
                widget.name,
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                return FadeTransition(
                  opacity: DelayTween(begin: 0.2, end: 1.0, delay: index * 0.2)
                      .animate(
                        CurvedAnimation(
                          parent: controller,
                          curve: Curves.easeInOut,
                        ),
                      ),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class DelayTween extends Tween<double> {
  final double delay;
  DelayTween({super.begin, super.end, required this.delay});

  @override
  double lerp(double t) {
    return super.lerp((math.sin((t - delay) * 2 * math.pi) + 1) / 2);
  }
}
