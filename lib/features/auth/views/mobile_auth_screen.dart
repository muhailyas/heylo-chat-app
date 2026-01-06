// import 'package:flutter/material.dart';
// import 'package:heylo/features/onboarding/widgets/primary_galaxy_button.dart';

// import '../../../core/constants/app_colors.dart';
// import '../../../core/router/route_generator.dart';
// import '../../../core/utils/auth_validators.dart';
// import '../../onboarding/widgets/holo_grid_motion.dart';

// class MobileAuthScreen extends StatefulWidget {
//   const MobileAuthScreen({super.key});

//   @override
//   State<MobileAuthScreen> createState() => _MobileAuthScreenState();
// }

// class _MobileAuthScreenState extends State<MobileAuthScreen> {
//   final TextEditingController _phone = TextEditingController(
//     text: '9876543210',
//   );
//   bool loading = false;
//   String? err;

//   Future<void> _submit() async {
//     final v = _phone.text.trim();
//     final e = Validators.validatePhone("+91$v");
//     if (e != null) {
//       setState(() => err = e);
//       return;
//     }

//     setState(() {
//       err = null;
//     });

//     await Future.delayed(const Duration(milliseconds: 850));
//     if (!mounted) return;

//     Navigator.pushNamed(context, RouteGenerator.otp, arguments: v);
//   }

//   @override
//   void dispose() {
//     _phone.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final s = MediaQuery.sizeOf(context);

//     return Scaffold(
//       backgroundColor: AppColors.darkBackground,
//       body: Stack(
//         children: [
//           const Positioned.fill(child: HoloGridMotion(stroke: 0.18)),

//           Positioned(
//             top: s.height * .12,
//             right: -40,
//             child: Container(
//               width: 150,
//               height: 150,
//               decoration: BoxDecoration(
//                 shape: BoxShape.circle,
//                 gradient: AppColors.primaryGradient,
//                 boxShadow: [
//                   BoxShadow(
//                     color: AppColors.primary.withOpacity(.45),
//                     blurRadius: 40,
//                     spreadRadius: 6,
//                   ),
//                 ],
//               ),
//             ),
//           ),

//           SafeArea(
//             child: Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 26),
//               child: Column(
//                 children: [
//                   SizedBox(height: s.height * .08),

//                   Align(
//                     alignment: Alignment.centerLeft,
//                     child: Text(
//                       "Enter your phone",
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 30,
//                         fontWeight: FontWeight.w900,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 6),
//                   Align(
//                     alignment: Alignment.centerLeft,
//                     child: Text(
//                       "We’ll text you a one-time code.",
//                       style: TextStyle(
//                         color: Colors.white.withOpacity(.65),
//                         fontSize: 14,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 32),

//                   Row(
//                     crossAxisAlignment: .start,
//                     children: [
//                       const _CountryCodeChip(),
//                       const SizedBox(width: 14),
//                       Expanded(
//                         child: _PrimaryInput(
//                           controller: _phone,
//                           hint: "9876543210",
//                           keyboardType: TextInputType.number,
//                           error: err,
//                         ),
//                       ),
//                     ],
//                   ),

//                   const Spacer(),
//                   PrimaryGalaxyButton(
//                     title: 'Continue',
//                     onSubmit: _submit,
//                     width: .maxFinite,
//                   ),

//                   const SizedBox(height: 22),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// /// Country Code Chip
// class _CountryCodeChip extends StatelessWidget {
//   const _CountryCodeChip();

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
//       decoration: BoxDecoration(
//         color: AppColors.darkCard,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: AppColors.border.withOpacity(.55)),
//       ),
//       child: Row(
//         children: [
//           const Text("🇮🇳", style: TextStyle(fontSize: 17)),
//           const SizedBox(width: 6),
//           const Text(
//             "+91",
//             style: TextStyle(
//               color: Colors.white,
//               fontWeight: FontWeight.w700,
//               fontSize: 15,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// /// Custom Input (local widget)
// class _PrimaryInput extends StatelessWidget {
//   final TextEditingController controller;
//   final String hint;
//   final String? error;
//   final TextInputType keyboardType;

//   const _PrimaryInput({
//     required this.controller,
//     required this.hint,
//     required this.error,
//     required this.keyboardType,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final errorColor = error == null
//         ? AppColors.border.withOpacity(.45)
//         : AppColors.error.withOpacity(.75);

//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Container(
//           decoration: BoxDecoration(
//             color: AppColors.darkCard,
//             borderRadius: BorderRadius.circular(14),
//             border: Border.all(color: errorColor, width: 1.4),
//           ),
//           child: TextField(
//             controller: controller,
//             keyboardType: keyboardType,
//             maxLength: 10,
//             style: const TextStyle(color: Colors.white),
//             decoration: InputDecoration(
//               counterText: "",
//               hintText: hint,
//               hintStyle: TextStyle(color: Colors.white.withOpacity(.45)),
//               border: InputBorder.none,
//               contentPadding: const EdgeInsets.symmetric(
//                 horizontal: 14,
//                 vertical: 14,
//               ),
//             ),
//           ),
//         ),
//         if (error != null)
//           Padding(
//             padding: const EdgeInsets.only(top: 6),
//             child: Text(
//               error!,
//               style: const TextStyle(color: Colors.redAccent, fontSize: 12),
//             ),
//           ),
//       ],
//     );
//   }
// }
// MobileAuthScreen (uses AuthNotifier - Firestore OTP flow)
// File: lib/features/auth/views/mobile_auth_screen.dart

// One-line purpose: Phone number entry screen integrated with Firestore OTP AuthNotifier

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heylo/core/constants/app_colors.dart';
import 'package:heylo/features/auth/view_model/notifiers/auth_notifier.dart';

import '../../../core/router/route_generator.dart';
import '../../../core/widgets/system_ui_handler.dart';
import '../../onboarding/widgets/holo_grid_motion.dart';
import '../../onboarding/widgets/primary_galaxy_button.dart';

class MobileAuthScreen extends ConsumerStatefulWidget {
  const MobileAuthScreen({super.key});

  @override
  ConsumerState<MobileAuthScreen> createState() => _MobileAuthScreenState();
}

class _MobileAuthScreenState extends ConsumerState<MobileAuthScreen> {
  final TextEditingController _phone = TextEditingController();
  String? err;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // 1. Check for logout reason on initial load (from Route)
    _checkLogoutReason();
  }

  void _checkLogoutReason() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reason = ref.read(authProvider).logoutReason;
      if (reason != null) {
        _showRevokedDialog(reason);
        ref.read(authProvider.notifier).clearLogoutReason();
      }
    });
  }

  void _showRevokedDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        return Dialog(
          backgroundColor: theme.cardColor,
          elevation: 8,
          shadowColor: Colors.black54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Icon / Visual
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.phonelink_erase_rounded,
                    color: Colors.redAccent,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 24),

                // Friendly Title
                Text(
                  "Session Ended",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Clear Message
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),

                // Premium Action Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: theme.colorScheme.onPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    child: const Text("Understood"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    final v = _phone.text.trim();
    if (v.length != 10 || int.tryParse(v) == null) {
      setState(() => err = "Enter a valid 10-digit phone number");
      return;
    }
    setState(() => err = null);
    final phoneWithCode = "+91$v";
    final notifier = ref.read(authProvider.notifier);
    final otp = await notifier.sendOtp(phoneWithCode);

    final st = ref.read(authProvider);
    if (st.otpError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(st.otpError!)));
      return;
    }

    if (st.codeSent) {
      // for dev: you may show the otp in a debug snackbar (remove in prod)
      if (otp != null && otp.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('DEBUG OTP: $otp'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        RouteGenerator.otp,
        arguments: phoneWithCode,
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
          const Positioned.fill(child: HoloGridMotion(stroke: 0.18)),
          Positioned(
            top: s.height * .12,
            right: -40,
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
                    blurRadius: 40,
                    spreadRadius: 6,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                children: [
                  SizedBox(height: s.height * .08),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Enter your phone",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "We’ll text you a one-time code.",
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(.65),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _CountryCodeChip(),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _PrimaryInput(
                          controller: _phone,
                          hint: "9876543210",
                          keyboardType: TextInputType.number,
                          error: err,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  PrimaryGalaxyButton(
                    title: authState.isLoading ? 'Sending...' : 'Continue',
                    onSubmit: _submit,
                    width: .maxFinite,
                  ),
                  const SizedBox(height: 22),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryCodeChip extends StatelessWidget {
  const _CountryCodeChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(.55),
        ),
      ),
      child: Row(
        children: [
          const Text("🇮🇳", style: TextStyle(fontSize: 17)),
          const SizedBox(width: 6),
          Text(
            "+91",
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              fontSize: 15,
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
  final TextInputType keyboardType;

  const _PrimaryInput({
    required this.controller,
    required this.hint,
    required this.error,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final errorColor = error == null
        ? Theme.of(context).dividerColor.withOpacity(.45)
        : AppColors.error.withOpacity(.75);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: errorColor, width: 1.4),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            maxLength: 10,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              counterText: "",
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
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
