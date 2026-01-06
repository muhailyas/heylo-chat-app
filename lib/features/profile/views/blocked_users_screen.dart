import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/session/session_store.dart';
import '../../auth/models/user_model.dart';
import '../../auth/repositories/profile_repo.dart';
import '../../chat/repositories/chat_repo.dart';
import '../../chat/views/chat_room_screen.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  late final ChatRepo _chatRepo;
  late final SupabaseProfileRepo _profileRepo;

  List<UserModel> _blockedUsers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    _chatRepo = ChatRepo(client);
    _profileRepo = SupabaseProfileRepo(client);
    _fetchBlockedUsers();
  }

  Future<void> _fetchBlockedUsers() async {
    try {
      final myId = await SessionStore.readUid();
      if (myId == null) {
        setState(() => _loading = false);
        return;
      }

      // 1. Get blocked IDs
      final blockedIds = await _chatRepo.getBlockedUsers(myId);

      if (blockedIds.isEmpty) {
        setState(() {
          _blockedUsers = [];
          _loading = false;
        });
        return;
      }

      // 2. Fetch UserModels for these IDs
      final users = await _profileRepo.fetchUsers(blockedIds);

      // If generic fetch fails or returns partial, we might still want to show something?
      // For now, assume it returns what exists.

      if (mounted) {
        setState(() {
          _blockedUsers = users;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching blocked users: $e");
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _unblock(UserModel user) async {
    try {
      final myId = await SessionStore.readUid();
      if (myId == null) return;

      await _chatRepo.unblockUser(myId, user.uid);

      if (mounted) {
        setState(() {
          _blockedUsers.removeWhere((u) => u.uid == user.uid);
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("User unblocked")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error unblocking user: $e")));
      }
    }
  }

  void _navigateToChat(UserModel user) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          name: user.name ?? user.phone,
          peerId: user.uid,
          avatarUrl: user.avatarUrl ?? '',
          phone: user.phone,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        title: Text(
          "Blocked Contacts",
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
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
            )
          : _blockedUsers.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              physics: const BouncingScrollPhysics(),
              itemCount: _blockedUsers.length,
              itemBuilder: (context, index) {
                final user = _blockedUsers[index];
                return _buildUserTile(user);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.block_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            "No blocked contacts",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(UserModel user) {
    final hasAvatar = user.avatarUrl != null && user.avatarUrl!.isNotEmpty;
    final displayName = (user.name != null && user.name!.isNotEmpty)
        ? user.name!
        : user.phone;

    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _navigateToChat(user),
        leading: CircleAvatar(
          backgroundColor: theme.primaryColor,
          backgroundImage: hasAvatar ? NetworkImage(user.avatarUrl!) : null,
          child: !hasAvatar
              ? Text(
                  displayName[0].toUpperCase(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Text(
          displayName,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          user.phone,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
            fontSize: 13,
          ),
        ),
        trailing: TextButton(
          onPressed: () => _unblock(user),
          style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
          child: const Text("Unblock"),
        ),
      ),
    );
  }
}
