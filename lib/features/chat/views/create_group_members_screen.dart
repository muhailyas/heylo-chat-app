import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heylo/core/router/route_generator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../home/models/contact_presence.dart';
import '../../home/view_models/notifiers/new_chat_notifier.dart';
import '../repositories/group_repo.dart';

class CreateGroupMembersScreen extends ConsumerStatefulWidget {
  final String? existingGroupId;
  const CreateGroupMembersScreen({super.key, this.existingGroupId});

  @override
  ConsumerState<CreateGroupMembersScreen> createState() =>
      _CreateGroupMembersScreenState();
}

class _CreateGroupMembersScreenState
    extends ConsumerState<CreateGroupMembersScreen> {
  final List<ContactItem> _selectedContacts = [];
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  List<String> _existingMemberUids = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(newChatProvider.notifier).load();
      if (widget.existingGroupId != null) {
        _loadExisting();
      }
    });
  }

  Future<void> _loadExisting() async {
    final repo = GroupRepo(Supabase.instance.client);
    final members = await repo.getGroupMembers(widget.existingGroupId!);
    if (mounted) {
      setState(() {
        _existingMemberUids = members
            .map((m) => m['user_id'] as String)
            .toList();
      });
    }
  }

  void _toggleContact(ContactItem contact) {
    setState(() {
      if (_selectedContacts.any((c) => c.phone == contact.phone)) {
        _selectedContacts.removeWhere((c) => c.phone == contact.phone);
      } else {
        _selectedContacts.add(contact);
      }
    });
  }

  Future<void> _addExisting() async {
    if (widget.existingGroupId == null) return;
    if (_selectedContacts.isEmpty) return;

    try {
      final repo = GroupRepo(Supabase.instance.client);
      final uids = _selectedContacts
          .map((c) => c.uid)
          .whereType<String>() // Ensure no nulls
          .toList();

      if (uids.isEmpty) {
        throw 'Selected contacts do not have valid user IDs.';
      }

      await repo.addMembers(widget.existingGroupId!, uids);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('[CreateGroupMembers] Add members error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to add members: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(newChatProvider);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    final List<ContactItem> heyloContacts = state.contacts
        .where((c) => c.presence == ContactPresence.onHeylo)
        .where((c) {
          if (_query.isEmpty) return true;
          final q = _query.toLowerCase();
          return c.name.toLowerCase().contains(q) || c.phone.contains(q);
        })
        .toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              widget.existingGroupId != null ? 'Add to Group' : 'New Group',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _selectedContacts.isEmpty
                  ? 'Add members'
                  : '${_selectedContacts.length} selected',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selectedContacts.isNotEmpty)
            TextButton(
              onPressed: () {
                if (widget.existingGroupId != null) {
                  _addExisting();
                } else {
                  Navigator.pushNamed(
                    context,
                    RouteGenerator.groupDetails,
                    arguments: _selectedContacts,
                  );
                }
              },
              child: Text(
                widget.existingGroupId != null ? 'ADD' : 'Next',
                style: TextStyle(color: primary, fontWeight: FontWeight.bold),
              ),
            ),
        ],
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: theme.scaffoldBackgroundColor.withOpacity(0.5),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                hintText: 'Search contacts',
                hintStyle: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.38),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.38),
                ),
                filled: true,
                fillColor: Theme.of(
                  context,
                ).colorScheme.onSurface.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // Selected Members Horizontal List
          if (_selectedContacts.isNotEmpty)
            Container(
              height: 90,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _selectedContacts.length,
                itemBuilder: (context, index) {
                  final contact = _selectedContacts[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 60,
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: primary,
                                backgroundImage: contact.avatarUrl != null
                                    ? NetworkImage(contact.avatarUrl!)
                                    : null,
                                child: contact.avatarUrl == null
                                    ? Text(
                                        contact.name.characters.first
                                            .toUpperCase(),
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: GestureDetector(
                                  onTap: () => _toggleContact(contact),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      color: Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            contact.name,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          if (_selectedContacts.isNotEmpty)
            Divider(
              color: Theme.of(context).dividerColor.withOpacity(0.1),
              height: 1,
            ),

          // Contacts List
          Expanded(
            child: ListView.builder(
              itemCount: heyloContacts.length,
              itemBuilder: (context, index) {
                final contact = heyloContacts[index];
                final isSelected = _selectedContacts.any(
                  (c) => c.phone == contact.phone,
                );
                final isAlreadyMember = _existingMemberUids.contains(
                  contact.uid,
                );

                return Opacity(
                  opacity: isAlreadyMember ? 0.5 : 1.0,
                  child: ListTile(
                    onTap: isAlreadyMember
                        ? null
                        : () => _toggleContact(contact),
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: primary,
                          backgroundImage: contact.avatarUrl != null
                              ? NetworkImage(contact.avatarUrl!)
                              : null,
                          child: contact.avatarUrl == null
                              ? Text(
                                  contact.name.characters.first.toUpperCase(),
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        if (isSelected)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.scaffoldBackgroundColor,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      contact.name,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: isAlreadyMember
                        ? Text(
                            'Already a member',
                            style: TextStyle(
                              color: Theme.of(context).disabledColor,
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        : Text(
                            contact.phone,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.5),
                              fontSize: 13,
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
