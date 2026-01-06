// File: lib/features/home/tabs/explore_tab.dart
// Explore tab with premium reusable tiles

import 'package:flutter/material.dart';

import '../../../../core/router/route_generator.dart';
import '../../../profile/views/invite_friend_screen.dart';
import '../../../profile/views/security_checkup_screen.dart';
import '../widgets/explore_tile.dart';

class ExploreTab extends StatelessWidget {
  const ExploreTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          ExploreTile(
            title: "Invite Friends",
            subtitle: "Bring your contacts to Heylo",
            icon: Icons.group_add_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InviteFriendScreen()),
            ),
          ),
          const SizedBox(height: 12),
          ExploreTile(
            title: "Create Group",
            subtitle: "Start a private or public group chat",
            icon: Icons.forum_rounded,
            onTap: () {
              Navigator.pushNamed(context, RouteGenerator.createGroupMembers);
            },
          ),
          const SizedBox(height: 12),
          ExploreTile(
            title: "Security Checkup",
            subtitle: "Verify encryption & device sessions",
            icon: Icons.lock_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SecurityCheckupScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
