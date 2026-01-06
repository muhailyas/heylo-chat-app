import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/route_generator.dart';
import '../../../../core/session/session_store.dart';
import '../../../appearance/views/appearance_screen.dart';
import '../../../profile/view_models/notifiers/profile_notifier.dart';
import '../../../profile/views/edit_account_screen.dart';
import '../../../profile/views/help_center_screen.dart';
import '../../../profile/views/linked_devices_screen.dart';
import '../../../profile/views/notifications_screen.dart';
import '../../../profile/views/privacy_screens.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: Text(
            'Log out?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            'You will be signed out from this device.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(.7),
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(.7),
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Log out'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    await SessionStore.clear();
    if (!context.mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      RouteGenerator.authMobile,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: profileAsync.when(
        data: (profile) => ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            _ProfileHeaderCard(
              name: profile?.name ?? "User",
              phone: profile?.phone ?? "",
              avatarUrl: profile?.avatarUrl,
              onEdit: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditAccountScreen(
                      initialName: profile?.name ?? "",
                      initialPhone: profile?.phone ?? "",
                      initialEmail: profile?.email,
                      avatarUrl: profile?.avatarUrl ?? "",
                    ),
                  ),
                );
                // Refresh profile after editing
                ref.invalidate(profileProvider);
              },
            ),
            const SizedBox(height: 18),

            _SettingsItem(
              icon: Icons.palette_outlined,
              title: "Appearance",
              subtitle: "Theme, colors",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AppearanceScreen()),
              ),
            ),
            const SizedBox(height: 10),

            _SettingsItem(
              icon: Icons.lock_outline_rounded,
              title: "Privacy",
              subtitle: "Security, blocked contacts",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyScreen()),
              ),
            ),
            const SizedBox(height: 10),

            _SettingsItem(
              icon: Icons.notifications_outlined,
              title: "Notifications",
              subtitle: "Sounds, vibration",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              ),
            ),
            const SizedBox(height: 10),

            _SettingsItem(
              icon: Icons.security_rounded,
              title: "Active Sessions",
              subtitle: "Manage connected devices",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LinkedDevicesScreen()),
              ),
            ),
            const SizedBox(height: 10),

            _SettingsItem(
              icon: Icons.help_outline_rounded,
              title: "Help Center",
              subtitle: "FAQ, support",
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
              ),
            ),

            const SizedBox(height: 10),

            _SettingsItem(
              icon: Icons.logout_rounded,
              title: "Log out",
              subtitle: "Sign out from this device",
              onTap: () => _confirmLogout(context),
              danger: true,
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text(
            'Error: $err',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final String name;
  final String phone;
  final String? avatarUrl;
  final VoidCallback onEdit;

  const _ProfileHeaderCard({
    required this.name,
    required this.phone,
    this.avatarUrl,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    final gradient = LinearGradient(
      colors: [primary.withOpacity(0.8), primary],
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor.withOpacity(.1)),
      ),
      child: Row(
        children: [
          if (avatarUrl != null && avatarUrl!.isNotEmpty)
            CircleAvatar(
              radius: 27,
              backgroundColor: primary.withOpacity(0.2),
              backgroundImage: NetworkImage(avatarUrl!),
              onBackgroundImageError: (_, __) {},
              child: null,
            )
          else
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: gradient,
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : "?",
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phone,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: Icon(
              Icons.edit_rounded,
              size: 20,
              color: theme.colorScheme.onSurface.withOpacity(.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool danger;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = danger ? Colors.redAccent : theme.colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(.1)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 20, color: color.withOpacity(.85)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color.withOpacity(.60),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: color.withOpacity(.40),
            ),
          ],
        ),
      ),
    );
  }
}
