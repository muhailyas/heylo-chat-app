import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/view_model/notifiers/auth_notifier.dart';
import 'blocked_users_screen.dart';

class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        title: Text(
          "Privacy",
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        physics: const BouncingScrollPhysics(),
        children: [
          _tile(
            context,
            icon: Icons.lock_rounded,
            title: "End-to-end Encryption",
            subtitle: "Your chats are protected",
            onTap: () => _showEncryptionInfo(context),
          ),
          _tile(
            context,
            icon: Icons.block_rounded,
            title: "Blocked Contacts",
            subtitle: "Manage blocked users",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
            ),
          ),
          _tile(
            context,
            icon: Icons.visibility_off_rounded,
            title: "Last Seen & Online",
            subtitle: _formatSubtitle(authState.privacyLastSeen),
            onTap: () => _showPrivacyOption(
              context,
              ref,
              "Last Seen & Online",
              "privacy_last_seen",
              authState.privacyLastSeen,
            ),
          ),
          _tile(
            context,
            icon: Icons.image_not_supported_rounded,
            title: "Profile Photo",
            subtitle: _formatSubtitle(authState.privacyProfilePhoto),
            onTap: () => _showPrivacyOption(
              context,
              ref,
              "Profile Photo",
              "privacy_profile_photo",
              authState.privacyProfilePhoto,
            ),
          ),
          _tile(
            context,
            icon: Icons.info_outline_rounded,
            title: "About",
            subtitle: _formatSubtitle(authState.privacyAbout),
            onTap: () => _showPrivacyOption(
              context,
              ref,
              "About",
              "privacy_about",
              authState.privacyAbout,
            ),
          ),
          _tile(
            context,
            icon: Icons.done_all_rounded,
            title: "Seen Status",
            subtitle: _formatSubtitle(authState.privacyReadReceipts),
            onTap: () => _showPrivacyOption(
              context,
              ref,
              "Seen Status",
              "privacy_read_receipts",
              authState.privacyReadReceipts,
            ),
          ),
          _tile(
            context,
            icon: Icons.lock_clock_rounded,
            title: "App Lock",
            subtitle: "Disabled",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("App Lock coming soon")),
              );
            },
          ),
        ],
      ),
    );
  }

  String _formatSubtitle(String key) {
    if (key == 'everyone') return 'Everyone';
    if (key == 'my_contacts') return 'My Contacts';
    if (key == 'nobody') return 'Nobody';
    return 'Everyone';
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(.85),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(.55),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(.45),
            ),
          ],
        ),
      ),
    );
  }

  void _showEncryptionInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          "End-to-end Encryption",
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          "All your calls and messages are secured with end-to-end encryption. This means only you and the person you're communicating with can read or listen to them, and nobody in between, not even Heylo.",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "OK",
              style: TextStyle(color: Theme.of(context).primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showPrivacyOption(
    BuildContext context,
    WidgetRef ref,
    String title,
    String key,
    String currentValue,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _optionTile(
                context,
                ref,
                "Everyone",
                "everyone",
                key,
                currentValue,
              ),
              _optionTile(
                context,
                ref,
                "My Contacts",
                "my_contacts",
                key,
                currentValue,
              ),
              _optionTile(context, ref, "Nobody", "nobody", key, currentValue),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  Widget _optionTile(
    BuildContext context,
    WidgetRef ref,
    String label,
    String value,
    String key,
    String currentValue,
  ) {
    final selected = value == currentValue;
    return ListTile(
      onTap: () {
        ref.read(authProvider.notifier).updatePrivacy(key, value);
        Navigator.pop(context);
      },
      leading: Radio<String>(
        value: value,
        groupValue: currentValue,
        onChanged: (v) {
          if (v != null) {
            ref.read(authProvider.notifier).updatePrivacy(key, v);
            Navigator.pop(context);
          }
        },
        activeColor: Theme.of(context).primaryColor,
      ),
      title: Text(
        label,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      ),
    );
  }
}
