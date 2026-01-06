import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/route_generator.dart';
import '../../../core/widgets/common_switch_state.dart';
import '../models/contact_presence.dart';
import '../view_models/notifiers/new_chat_notifier.dart';
import 'tabs/chats_tab.dart';
import 'widgets/contact_shimmer.dart';

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(newChatProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newChatProvider);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    final List<ContactItem> filtered = _query.isEmpty
        ? state.contacts
        : state.contacts.where((c) {
            final q = _query.toLowerCase();
            return c.name.toLowerCase().contains(q) ||
                c.phone.contains(q.replaceAll(' ', ''));
          }).toList();

    final heyloContacts = filtered
        .where((c) => c.presence == ContactPresence.onHeylo)
        .toList();

    final inviteContacts = filtered
        .where((c) => c.presence == ContactPresence.invite)
        .toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const _TopBar(),

            if (state.status == ViewState.loaded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _SearchBar(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),

            Expanded(
              child: CommonSwitchState(
                state: state.status,
                loadingWidget: const NewChatShimmer(),
                onRetry: () => ref.read(newChatProvider.notifier).retry(),
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(0, 4, 0, 16 + bottomInset),
                  children: [
                    _ActionTile(
                      icon: Icons.group_add_rounded,
                      title: 'New Group',
                      onTap: () {
                        Navigator.pushNamed(
                          context,
                          RouteGenerator.createGroupMembers,
                        );
                      },
                    ),
                    if (heyloContacts.isNotEmpty) ...[
                      const _SectionHeader('CONTACTS ON HEYLO'),
                      ...heyloContacts.map(
                        (c) => _ContactTile(
                          contact: c,
                          onTap: () {
                            print(
                              'Opening chat with name=${c.name}, peerId=${c.uid}',
                            );
                            Navigator.pushNamed(
                              context,
                              RouteGenerator.chatRoom,
                              // arguments: {
                              //   'name': c.name,
                              //   'peerId': c.uid ?? '',
                              // },
                              arguments: ChatRoomArgs(
                                name: c.name,
                                peerId: c.uid ?? '',
                                avatarUrl: c.avatarUrl ?? '',
                                phone: c.phone,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    if (inviteContacts.isNotEmpty) ...[
                      const _SectionHeader('INVITE TO HEYLO'),
                      ...inviteContacts.map(
                        (c) =>
                            _ContactTile(contact: c, invite: true, onTap: null),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Top bar
// ─────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(.7),
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor.withOpacity(.1),
              ),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                splashRadius: 20,
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              Text(
                'Start chat',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Search bar
// ─────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            size: 20,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(.54),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search name or number',
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(.38),
                ),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          letterSpacing: .6,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(.54),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.primaryColor.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: theme.primaryColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Contact tile
// ─────────────────────────────────────────────
class _ContactTile extends StatelessWidget {
  final ContactItem contact;
  final bool invite;
  final VoidCallback? onTap;

  const _ContactTile({required this.contact, this.invite = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: invite ? null : onTap,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor,
        backgroundImage:
            contact.avatarUrl != null && contact.avatarUrl!.isNotEmpty
            ? NetworkImage(contact.avatarUrl!)
            : null,
        child: contact.avatarUrl == null || contact.avatarUrl!.isEmpty
            ? Text(
                contact.name.characters.first.toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
      title: Text(
        contact.name,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
      subtitle: Text(
        contact.phone,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(.54),
        ),
      ),
      trailing: invite
          ? TextButton(
              onPressed: () {
                // PHASE 3 → system share intent
              },
              child: const Text(
                'Invite',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }
}
