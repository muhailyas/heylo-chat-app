import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heylo/core/widgets/system_ui_handler.dart';
import 'package:heylo/features/chat/repositories/group_repo.dart';
import 'package:heylo/features/profile/views/edit_group_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

import '../../../../core/providers/contact_provider.dart';
import '../../../../core/session/session_store.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_generator.dart';
import '../../chat/view_models/notifiers/chat_notifier.dart';
import '../../home/views/tabs/chats_tab.dart';
import 'media_links_docs_screen.dart';

class ProfileDetailsScreen extends StatefulWidget {
  final String name;
  final String peerId;
  final String phone;
  final String avatarUrl;
  final bool isGroup;

  const ProfileDetailsScreen({
    super.key,
    required this.name,
    required this.peerId,
    required this.phone,
    required this.avatarUrl,
    this.isGroup = false,
  });

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();

  static Future<dynamic> open(
    BuildContext context, {
    required String name,
    required String peerId,
    required String phone,
    required String avatarUrl,
    bool isGroup = false,
  }) {
    return Navigator.pushNamed(
      context,
      RouteGenerator.profileDetails,
      arguments: ProfileDetailsArgs(
        name: name,
        peerId: peerId,
        phone: phone,
        avatarUrl: avatarUrl,
        isGroup: isGroup,
      ),
    );
  }
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  final ScrollController _scroll = ScrollController();
  double collapseProgress = 0.0;
  String _groupName = '';
  String _groupAvatar = '';
  String? _about;
  String? _heyloName;

  @override
  void initState() {
    super.initState();
    _groupName = widget.name;
    _groupAvatar = widget.avatarUrl;
    if (!widget.isGroup) {
      _fetchUserDetails();
    }
    _scroll.addListener(() {
      final offset = _scroll.offset;
      const maxOffset = 140;
      if (mounted) {
        setState(() {
          collapseProgress = (offset / maxOffset).clamp(0.0, 1.0);
        });
      }
    });
  }

  Future<void> _fetchUserDetails() async {
    try {
      final client = Supabase.instance.client;
      final res = await client
          .from('users')
          .select(
            'name, avatar_url, privacy_profile_photo, about, privacy_about',
          )
          .eq('uid', widget.peerId)
          .maybeSingle();

      if (res != null && mounted) {
        setState(() {
          _heyloName = res['name'] as String?;
          // Profile Photo Privacy
          final ppPrivacy =
              res['privacy_profile_photo'] as String? ?? 'everyone';
          if (ppPrivacy == 'everyone') {
            _groupAvatar = res['avatar_url'] as String? ?? '';
          } else {
            _groupAvatar = ''; // Hide
          }

          // About Privacy
          final aboutPrivacy = res['privacy_about'] as String? ?? 'everyone';
          if (aboutPrivacy == 'everyone') {
            _about = res['about'] as String?;
          } else {
            _about = ''; // Hide or restricted
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch user details: $e');
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SystemUIHandler(
      scaffoldBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        child: NestedScrollView(
          controller: _scroll,
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              pinned: true,
              backgroundColor: Theme.of(context).cardColor,
              elevation: 0,
              expandedHeight: 240,
              toolbarHeight: 58,
              leadingWidth: 46,
              leading: Padding(
                padding: const EdgeInsets.only(left: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(40),
                  onTap: () => Navigator.pop(context),
                  child: Icon(
                    Icons.arrow_back_ios_rounded,
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 18,
                  ),
                ),
              ),
              title: collapseProgress > 0.25
                  ? Opacity(
                      opacity: collapseProgress,
                      child: Row(
                        children: [
                          Transform.scale(
                            scale: lerpDouble(0.6, 1.0, collapseProgress)!,
                            child: ClipOval(
                              child: Container(
                                color: Theme.of(context).primaryColor,
                                width: 28,
                                height: 28,
                                child: _groupAvatar.isNotEmpty
                                    ? Image.network(
                                        _groupAvatar,
                                        fit: BoxFit.cover,
                                      )
                                    : _initialsWidget(
                                        _groupName,
                                        isLeading: true,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _groupName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : null,
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Full background image or gradient
                    if (_groupAvatar.isNotEmpty)
                      Image.network(_groupAvatar, fit: BoxFit.cover)
                    else
                      Container(
                        decoration: BoxDecoration(
                          // gradient: AppColors.primaryGradient,
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.primary,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _groupName.characters.first.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 80,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    // Sophisticated overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(context).primaryColor.withOpacity(0.0),
                            Theme.of(context).primaryColor.withOpacity(0.2),
                            Theme.of(context).primaryColor.withOpacity(0.6),
                            Theme.of(context).scaffoldBackgroundColor,
                          ],
                          stops: const [0.0, 0.3, 0.6, 1.0],
                        ),
                      ),
                    ),
                    // Bottom content
                    Positioned(
                      bottom: 24,
                      left: 20,
                      right: 20,
                      child: Opacity(
                        opacity: (1 - collapseProgress).clamp(0.0, 1.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _groupName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (widget.isGroup)
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(
                                      Icons.edit_rounded,
                                      color: Colors.white70,
                                      size: 20,
                                    ),
                                    onPressed: _navigateToEditGroup,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.isGroup ? "GROUP CHAT" : widget.phone,
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Photo action button
                    if (widget.isGroup)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: SafeArea(
                          child: Material(
                            color: Colors.black38,
                            shape: const CircleBorder(),
                            child: IconButton(
                              icon: Icon(
                                Icons.add_a_photo_rounded,
                                color: Theme.of(context).primaryColor,
                                size: 18,
                              ),
                              onPressed: _navigateToEditGroup,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          body: _ProfileBody(widget: widget, parent: this),
        ),
      ),
    );
  }

  Widget _initialsWidget(String name, {bool isLeading = false}) {
    final initials = name.isEmpty
        ? '?'
        : name.trim().split(' ').map((e) => e[0]).take(2).join();
    return Container(
      color: Theme.of(context).primaryColor.withOpacity(.15),
      alignment: Alignment.center,
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w700,
          fontSize: isLeading ? 16 : 48,
        ),
      ),
    );
  }

  Future<void> _navigateToEditGroup() async {
    final result =
        await Navigator.pushNamed(
              context,
              RouteGenerator.editGroup,
              arguments: EditGroupArgs(
                groupId: widget.peerId,
                currentName: _groupName,
                currentAvatar: _groupAvatar,
              ),
            )
            as Map<String, dynamic>?;

    if (result != null && mounted) {
      setState(() {
        _groupName = result['name'] ?? _groupName;
        _groupAvatar = result['avatar'] ?? _groupAvatar;
      });
    }
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  const _ProfileBody({required this.widget, required this.parent});
  final ProfileDetailsScreen widget;
  final _ProfileDetailsScreenState parent;

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(
      chatProvider(
        widget.widget.isGroup
            ? 'group:${widget.widget.peerId}'
            : widget.widget.peerId,
      ),
    );

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const SizedBox(height: 20),
        if (widget.widget.isGroup) ...[
          _GroupActionsCard(
            widget: widget.widget,
            onSearchMessages: () {
              // Return to chat room and trigger message search
              Navigator.pop(context, 'search_messages');
            },
          ),
          const SizedBox(height: 18),
        ],
        _AboutCard(
          about: widget.widget.isGroup
              ? "This is a group chat on Heylo."
              : (widget.parent._about != null &&
                    widget.parent._about!.isNotEmpty)
              ? widget.parent._about!
              : (widget.parent._about ==
                    '') // explicit empty means restricted/hidden
              ? "About info is hidden"
              : "Heylo is a platform that connects you with your friends and family.",
        ),
        if (!widget.widget.isGroup &&
            widget.parent._heyloName != null &&
            widget.parent._heyloName != widget.widget.name) ...[
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.alternate_email_rounded,
            title: widget.parent._heyloName!,
            subtitle: 'Heylo Name',
          ),
        ],
        if (!widget.widget.isGroup &&
            ref.watch(contactNameProvider(widget.widget.phone)) == null) ...[
          const SizedBox(height: 12),
          _ActionTile(
            icon: Icons.person_add_rounded,
            title: 'Add to Contact',
            subtitle: 'Save this number to your device',
            onTap: () async {
              final contact = Contact()..phones = [Phone(widget.widget.phone)];
              await FlutterContacts.openExternalInsert(contact);
              // Invalidate to refresh the 'is Stranger' status globally
              ref.invalidate(localContactsProvider);
            },
          ),
        ],
        const SizedBox(height: 18),
        if (widget.widget.isGroup) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MEMBERS',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.5),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isSearching ? Icons.close : Icons.search,
                    size: 20,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.5),
                  ),
                  onPressed: () {
                    setState(() {
                      _isSearching = !_isSearching;
                      if (!_isSearching) _searchController.clear();
                    });
                  },
                ),
              ],
            ),
          ),
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (v) => setState(() {}),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Search members...',
                  hintStyle: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.38),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.38),
                  ),
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          _GroupMembersList(
            groupId: widget.widget.peerId,
            searchQuery: _searchController.text.trim(),
          ),
          _ActionTile(
            icon: Icons.person_add_alt_1_rounded,
            title: 'Add Members',
            onTap: () async {
              final result = await Navigator.pushNamed(
                context,
                RouteGenerator.createGroupMembers,
                arguments: widget.widget.peerId,
              );
              if (result == true && mounted) {
                setState(() {});
              }
            },
          ),
          const SizedBox(height: 12),
        ],
        const _SectionDivider(label: 'Content'),
        _ActionTile(
          icon: Icons.perm_media_rounded,
          title: 'Media, Links & Docs',
          subtitle: 'Past documents and links shared',
          onTap: () {
            Navigator.push(
              context,
              _SlidePageRoute(
                page: MediaLinksDocsScreen(peerId: widget.widget.peerId),
              ),
            );
          },
        ),
        const _SectionDivider(label: 'Security'),
        const _ActionTile(
          icon: Icons.lock_outline_rounded,
          title: 'Encryption',
          subtitle: 'Messages are end-to-end encrypted',
        ),
        _ActionTile(
          icon: Icons.wallpaper_rounded,
          title: 'Chat Wallpaper',
          subtitle: 'Change the background for this chat',
          onTap: _pickWallpaper,
        ),
        const _SectionDivider(label: 'Dangerous Zone'),
        _ActionTile(
          icon: Icons.delete_outline,
          leadingColor: AppColors.error,
          title: 'Clear Chat',
          subtitle: 'Wipe all history from this device',
          titleColor: AppColors.error,
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: AppColors.darkCard,
                title: const Text(
                  'Clear Chat',
                  style: TextStyle(color: Colors.white),
                ),
                content: const Text(
                  'Are you sure you want to delete all messages in this chat?',
                  style: TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('CANCEL'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text(
                      'CLEAR',
                      style: TextStyle(color: AppColors.error),
                    ),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await ref
                  .read(
                    chatProvider(
                      widget.widget.isGroup
                          ? 'group:${widget.widget.peerId}'
                          : widget.widget.peerId,
                    ).notifier,
                  )
                  .clearChat();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Chat cleared')));
              }
            }
          },
        ),
        if (widget.widget.isGroup)
          _ActionTile(
            icon: Icons.logout_rounded,
            leadingColor: AppColors.error,
            title: 'Leave Group',
            subtitle: 'You will no longer receive messages',
            titleColor: AppColors.error,
            onTap: () => _leaveGroup(context),
          )
        else
          _ActionTile(
            icon: chatState.isBlocked
                ? Icons.check_circle_outline
                : Icons.block,
            leadingColor: chatState.isBlocked
                ? Theme.of(context).colorScheme.onSurface
                : AppColors.error,
            title: chatState.isBlocked ? 'Unblock User' : 'Block User',
            subtitle: chatState.isBlocked
                ? 'Unblock to allow messaging'
                : 'Blocked users cannot message you',
            titleColor: chatState.isBlocked
                ? Theme.of(context).colorScheme.onSurface
                : AppColors.error,
            onTap: () async {
              final isBlocked = chatState.isBlocked;
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: Theme.of(context).cardColor,
                  title: Text(
                    isBlocked ? 'Unblock User' : 'Block User',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  content: Text(
                    isBlocked
                        ? 'Are you sure you want to unblock this user?'
                        : 'Are you sure you want to block this user?',
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(.7),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: Text(
                        isBlocked ? 'UNBLOCK' : 'BLOCK',
                        style: TextStyle(
                          color: isBlocked
                              ? Theme.of(context).primaryColor
                              : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                final notifier = ref.read(
                  chatProvider(widget.widget.peerId).notifier,
                );
                if (isBlocked) {
                  await notifier.unblockUser();
                } else {
                  await notifier.blockUser();
                }
              }
            },
          ),
        const SizedBox(height: 80),
      ],
    );
  }

  Future<void> _pickWallpaper() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                Icons.image_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                'Choose from Gallery',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _chooseFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Reset Wallpaper',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _resetWallpaper();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final prefs = await SharedPreferences.getInstance();
        final roomId = widget.widget.isGroup
            ? 'group:${widget.widget.peerId}'
            : widget.widget.peerId;
        await prefs.setString('wallpaper_$roomId', picked.path);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Wallpaper updated')));
        }
      }
    } catch (e) {
      debugPrint('Error picking wallpaper: $e');
    }
  }

  Future<void> _resetWallpaper() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roomId = widget.widget.isGroup
          ? 'group:${widget.widget.peerId}'
          : widget.widget.peerId;
      await prefs.remove('wallpaper_$roomId');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Wallpaper reset')));
      }
    } catch (e) {
      debugPrint('Error resetting wallpaper: $e');
    }
  }

  Future<void> _leaveGroup(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          'Leave Group',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Are you sure you want to leave this group?',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'LEAVE',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final myId = await SessionStore.readUid();
      if (myId == null) return;
      final repo = GroupRepo(Supabase.instance.client);
      await repo.leaveGroup(widget.widget.peerId, myId);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }
}

class _GroupActionsCard extends ConsumerWidget {
  final ProfileDetailsScreen widget;
  final VoidCallback onSearchMessages;
  const _GroupActionsCard({
    required this.widget,
    required this.onSearchMessages,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = GroupRepo(Supabase.instance.client);

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        repo.getGroupMembers(widget.peerId),
        SessionStore.readUid(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final members = snapshot.data![0] as List<Map<String, dynamic>>;
        final myId = snapshot.data![1] as String?;

        final otherMembers = members
            .where((m) => m['user_id'] != myId)
            .toList();
        final invitees = otherMembers.map((m) {
          final profile = m['users'] as Map<String, dynamic>?;
          return ZegoUIKitUser(
            id: m['user_id'] as String,
            name: profile?['name'] ?? 'User',
          );
        }).toList();

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Theme.of(context).dividerColor.withOpacity(0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                invitees.isEmpty
                    ? Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _ActionItem(
                              icon: Icons.call_rounded,
                              label: 'Audio',
                              onTap: () {},
                            ),
                            _ActionItem(
                              icon: Icons.videocam_rounded,
                              label: 'Video',
                              onTap: () {},
                            ),
                            _ActionItem(
                              icon: Icons.search_rounded,
                              label: 'Search',
                              onTap: onSearchMessages,
                            ),
                          ],
                        ),
                      )
                    : Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _ZegoActionWrapper(
                              isVideo: false,
                              invitees: invitees,
                              id: widget.peerId,
                            ),
                            _ZegoActionWrapper(
                              isVideo: true,
                              invitees: invitees,
                              id: widget.peerId,
                            ),
                            _ActionItem(
                              icon: Icons.search_rounded,
                              label: 'Search',
                              onTap: onSearchMessages,
                            ),
                          ],
                        ),
                      ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZegoActionWrapper extends StatelessWidget {
  final bool isVideo;
  final List<ZegoUIKitUser> invitees;
  final String id;

  const _ZegoActionWrapper({
    required this.isVideo,
    required this.invitees,
    required this.id,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ZegoSendCallInvitationButton(
          isVideoCall: isVideo,
          invitees: invitees,
          resourceID: "zego_data",
          iconSize: const Size(24, 24),
          buttonSize: const Size(44, 44),
          padding: EdgeInsets.zero,
          icon: ButtonIcon(
            icon: Icon(
              isVideo ? Icons.videocam_rounded : Icons.call_rounded,
              color: Theme.of(context).primaryColor,
            ),
          ),
          onPressed: (code, message, invitees) {
            // Logging is now handled inside ZegoCallService events
          },
        ),
        const SizedBox(height: 2),
        Text(
          isVideo ? 'Video' : 'Audio',
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _GroupMembersList extends ConsumerStatefulWidget {
  final String groupId;
  final String searchQuery;
  const _GroupMembersList({required this.groupId, this.searchQuery = ''});

  @override
  ConsumerState<_GroupMembersList> createState() => _GroupMembersListState();
}

class _GroupMembersListState extends ConsumerState<_GroupMembersList> {
  List<Map<String, dynamic>> _allMembers = [];
  bool _isLoading = true;
  String? _myId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = GroupRepo(Supabase.instance.client);
      final members = await repo.getGroupMembers(widget.groupId);
      final myId = await SessionStore.readUid();
      if (mounted) {
        setState(() {
          _allMembers = members;
          _myId = myId;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Column(
        children: List.generate(
          5,
          (index) => Shimmer.fromColors(
            baseColor: Colors.white.withOpacity(0.05),
            highlightColor: Colors.white.withOpacity(0.1),
            child: ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.white),
              title: Container(
                width: 100,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              subtitle: Container(
                width: 150,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'Error loading members: $_error',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.54),
            fontSize: 12,
          ),
        ),
      );
    }

    final filtered = widget.searchQuery.isEmpty
        ? _allMembers
        : _allMembers.where((m) {
            final profile = m['users'] as Map<String, dynamic>?;
            final name = (profile?['name'] ?? '').toString().toLowerCase();
            return name.contains(widget.searchQuery.toLowerCase());
          }).toList();

    return Column(
      children: filtered.map((m) {
        final profile = m['users'] as Map<String, dynamic>?;
        final name = profile?['name'] ?? 'User';
        final avatar = profile?['avatar_url'] ?? '';
        final phone = profile?['phone'] ?? '';
        final uid = profile?['uid'] ?? '';
        final isMe = uid == _myId;

        return ListTile(
          onTap: isMe
              ? null
              : () => _showMemberOptions(context, name, phone, avatar, uid),
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).primaryColor,
            backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
            child: avatar.isEmpty
                ? Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  )
                : null,
          ),
          title: Text(
            isMe ? '$name (You)' : name,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            phone,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.38),
              fontSize: 13,
            ),
          ),
          trailing: isMe
              ? null
              : Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.24),
                  size: 20,
                ),
        );
      }).toList(),
    );
  }

  void _showMemberOptions(
    BuildContext context,
    String name,
    String phone,
    String avatar,
    String uid,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 32),
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).primaryColor,
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              child: avatar.isEmpty
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 24, color: Colors.white),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              name,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              phone,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.38),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _OptionItem(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Chat',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      RouteGenerator.chatRoom,
                      arguments: ChatRoomArgs(
                        name: name,
                        peerId: uid,
                        avatarUrl: avatar,
                        phone: phone,
                        isGroup: false,
                      ),
                    );
                  },
                ),
                _OptionItem(
                  icon: Icons.call_rounded,
                  label: 'Audio',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                _OptionItem(
                  icon: Icons.videocam_rounded,
                  label: 'Video',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _OptionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _OptionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Theme.of(context).primaryColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.about});
  final String about;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              about,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    this.subtitle = '',
    this.onTap,
    this.titleColor,
    this.leadingColor,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Color? titleColor;
  final Color? leadingColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        (leadingColor ??
                                Theme.of(context).colorScheme.onSurface)
                            .withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color:
                        leadingColor ??
                        Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color:
                              titleColor ??
                              Theme.of(context).colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.38),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SlidePageRoute<T> extends PageRouteBuilder<T> {
  _SlidePageRoute({required this.page})
    : super(
        pageBuilder: (_, __, ___) => page,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (_, animation, __, child) {
          final slide = Tween(begin: const Offset(1, 0), end: Offset.zero)
              .animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );
          return SlideTransition(position: slide, child: child);
        },
      );
  final Widget page;
}
