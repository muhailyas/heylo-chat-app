import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/router/route_generator.dart';
import '../../../core/widgets/system_ui_handler.dart';
import '../../onboarding/widgets/holo_grid_motion.dart';
import '../../onboarding/widgets/primary_galaxy_button.dart';
import '../view_model/notifiers/auth_notifier.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _email = TextEditingController();
  File? _avatarFile;
  String? errName;
  String? errEmail;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (img == null) return;
    setState(() => _avatarFile = File(img.path));
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty) {
      setState(() => errName = "Enter your name");
      return;
    }
    if (email.isNotEmpty &&
        !RegExp(r"^[\w-.]+@([\w-]+\.)+[\w-]{2,}$").hasMatch(email)) {
      setState(() => errEmail = "Invalid email");
      return;
    }

    setState(() {
      errName = null;
      errEmail = null;
    });

    final notifier = ref.read(authProvider.notifier);
    final ok = await notifier.saveProfile(
      name: name,
      email: email.isEmpty ? null : email,
      avatarFile: _avatarFile,
    );

    final st = ref.read(authProvider);
    if (!ok && st.otpError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(st.otpError!)));
      return;
    }

    if (ok) {
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteGenerator.home,
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    final authState = ref.watch(authProvider);

    return SystemUIHandler(
      scaffoldBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          const Positioned.fill(child: HoloGridMotion(stroke: .20)),

          Positioned(
            top: s.height * .10,
            right: -36,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.8),
                    Theme.of(context).primaryColor,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(.45),
                    blurRadius: 50,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: s.height * .08),

                    Text(
                      "Profile Setup",
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Provide your details to complete profile",
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(.65),
                        fontSize: 14,
                      ),
                    ),

                    const SizedBox(height: 32),

                    Center(
                      child: GestureDetector(
                        onTap: _pickAvatar,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).primaryColor.withOpacity(0.8),
                                Theme.of(context).primaryColor,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(
                                  context,
                                ).primaryColor.withOpacity(.45),
                                blurRadius: 40,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: _avatarFile == null
                              ? const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 36,
                                )
                              : ClipOval(
                                  child: Image.file(
                                    _avatarFile!,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    _PrimaryInput(
                      controller: _name,
                      hint: "Full name",
                      error: errName,
                    ),

                    const SizedBox(height: 18),

                    _PrimaryInput(
                      controller: _email,
                      hint: "Email (optional)",
                      keyboardType: TextInputType.emailAddress,
                      error: errEmail,
                    ),

                    const SizedBox(height: 32),

                    PrimaryGalaxyButton(
                      title: authState.isLoading ? 'Saving...' : "Continue",
                      width: double.infinity,
                      onSubmit: _submit,
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? error;
  final TextInputType? keyboardType;

  const _PrimaryInput({
    required this.controller,
    required this.hint,
    this.error,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = error == null
        ? Theme.of(context).dividerColor.withOpacity(.45)
        : Colors.redAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(.50),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.4),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(.45),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 6),
            child: Text(
              error!,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
