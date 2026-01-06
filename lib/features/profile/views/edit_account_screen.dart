// Ultra-Premium Edit Profile Screen (WhatsApp-tier quality)
// File: lib/features/profile/views/edit_account_screen.dart

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heylo/features/onboarding/widgets/primary_galaxy_button.dart';
import 'package:heylo/features/profile/view_models/notifiers/profile_notifier.dart';
import 'package:image_picker/image_picker.dart';

class EditAccountScreen extends ConsumerStatefulWidget {
  const EditAccountScreen({
    super.key,
    this.initialName = "Your Name",
    this.initialPhone = "+91 98765 43210",
    this.initialEmail,
    this.initialBio = "Hey there! I am using Heylo.",
    this.avatarUrl = "",
  });

  final String initialName;
  final String initialPhone;
  final String? initialEmail;
  final String initialBio;
  final String avatarUrl;

  @override
  ConsumerState<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends ConsumerState<EditAccountScreen> {
  late final TextEditingController nameCtrl;
  late final TextEditingController phoneCtrl;
  late final TextEditingController bioCtrl;
  late final TextEditingController emailCtrl;
  String? _newAvatarPath;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.initialName);
    phoneCtrl = TextEditingController(text: widget.initialPhone);
    emailCtrl = TextEditingController(text: widget.initialEmail ?? "");
    bioCtrl = TextEditingController(text: widget.initialBio);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    bioCtrl.dispose();
    emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatar = widget.avatarUrl;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        leadingWidth: 46,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            size: 18,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Edit Profile",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),

      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
        children: [
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Hero(
                  tag: "edit_profile_avatar",
                  child: Container(
                    width: 108,
                    height: 108,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).cardColor,
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withAlpha(66),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _newAvatarPath != null
                          ? Image.file(File(_newAvatarPath!), fit: BoxFit.cover)
                          : avatar.isEmpty
                          ? _placeholderAvatar(widget.initialName)
                          : Image.network(
                              avatar,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _placeholderAvatar(widget.initialName),
                            ),
                    ),
                  ),
                ),

                InkWell(
                  onTap: _changePhoto,
                  borderRadius: BorderRadius.circular(40),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).dividerColor,
                        width: 2,
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).primaryColor.withOpacity(0.8),
                          Theme.of(context).primaryColor,
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 34),
          _section("Name"),
          _inputField(controller: nameCtrl),

          const SizedBox(height: 22),
          _section("Phone Number"),
          _inputField(
            controller: phoneCtrl,
            keyboard: TextInputType.phone,
            enabled: false, // non-editable
          ),

          const SizedBox(height: 22),
          _section("Email (Optional)"),
          _inputField(
            controller: emailCtrl,
            keyboard: TextInputType.emailAddress,
          ),

          const SizedBox(height: 22),
          _section("Bio"),
          _inputField(
            controller: bioCtrl,
            maxLines: 3,
            hint: "Add a short bio",
          ),

          const SizedBox(height: 40),
          PrimaryGalaxyButton(
            title: 'Save changes',
            onSubmit: _saveProfile,
            width: .maxFinite,
          ),
        ],
      ),
    );
  }

  Widget _placeholderAvatar(String name) {
    final initials = name.isEmpty
        ? "?"
        : name.trim().split(" ").map((e) => e[0]).take(2).join().toUpperCase();

    return Container(
      color: Theme.of(context).primaryColor,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 32,
          color: Theme.of(context).colorScheme.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(.65),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    TextInputType keyboard = TextInputType.text,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboard,
      style: TextStyle(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(.45),
          fontSize: 14,
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(.2),
            width: 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(.2),
            width: 1,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Theme.of(context).dividerColor.withOpacity(.3),
            width: 1,
          ),
        ),
      ),
    );
  }

  Future<void> _changePhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        _newAvatarPath = image.path;
      });
    }
  }

  Future<void> _saveProfile() async {
    // Validate email if provided
    final email = emailCtrl.text.trim();
    if (email.isNotEmpty && !_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid email address'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Validate name
    final name = nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name cannot be empty'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    try {
      String? newAvatarUrl;

      // Upload avatar if changed
      if (_newAvatarPath != null) {
        newAvatarUrl = await ref
            .read(profileProvider.notifier)
            .uploadAvatar(_newAvatarPath!);
      }

      // Update profile
      await ref
          .read(profileProvider.notifier)
          .updateProfile(
            name: name,
            email: email.isEmpty ? null : email,
            avatarUrl: newAvatarUrl,
          );

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving profile: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  bool _isValidEmail(String email) {
    // Simple email validation regex
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }
}
