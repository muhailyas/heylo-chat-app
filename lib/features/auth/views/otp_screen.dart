import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';

import '../../../core/router/route_generator.dart';
import '../../../core/widgets/system_ui_handler.dart';
import '../../onboarding/widgets/holo_grid_motion.dart';
import '../../onboarding/widgets/primary_galaxy_button.dart';
import '../view_model/notifiers/auth_notifier.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phoneNumber});
  final String phoneNumber;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final TextEditingController _pc = TextEditingController();
  bool canResend = false;
  int counter = 30;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    counter = 30;
    canResend = false;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        counter--;
      });
      if (counter == 0) {
        setState(() => canResend = true);
        return false;
      }
      return true;
    });
  }

  Future<void> _submit() async {
    if (_pc.text.length != 6) return;
    final notifier = ref.read(authProvider.notifier);
    await notifier.verifyOtp(
      _pc.text.trim(),
      onFailure: (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      },
      onSuccess: (newUser) {
        if (newUser) {
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            RouteGenerator.profileSetup,
            (_) => false,
          );
        } else {
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            RouteGenerator.home,
            (_) => false,
          );
        }
      },
    );
  }

  Future<void> _resend() async {
    final notifier = ref.read(authProvider.notifier);
    await notifier.sendOtp(widget.phoneNumber);
    _startTimer();
    final st = ref.read(authProvider);
    if (st.otpError != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(st.otpError!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    final authState = ref.watch(authProvider);

    final pinTheme = PinTheme(
      width: 52,
      height: 58,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(.6),
        ),
      ),
      textStyle: TextStyle(
        fontSize: 20,
        color: Theme.of(context).colorScheme.onSurface,
        fontWeight: FontWeight.w700,
      ),
    );

    final focusedPinTheme = pinTheme.copyWith(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.8),
            Theme.of(context).primaryColor,
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(.45),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      textStyle: const TextStyle(
        fontSize: 22,
        color: Colors.white,
        fontWeight: FontWeight.w900,
      ),
    );

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
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: s.height * .08),
                  Text(
                    "Verify Code",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Code sent to ${widget.phoneNumber}",
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(.70),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Pinput(
                      controller: _pc,
                      length: 6,
                      keyboardType: TextInputType.number,
                      defaultPinTheme: pinTheme,
                      focusedPinTheme: focusedPinTheme,
                      onCompleted: (_) => _submit(),
                      showCursor: false,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: Text(
                      canResend
                          ? "Didn’t receive code?"
                          : "You can resend code in $counter s",
                      style: TextStyle(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(.70),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (canResend)
                    Center(
                      child: TextButton(
                        onPressed: _resend,
                        child: Text(
                          "Resend Code",
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Change phone number",
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(.50),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  PrimaryGalaxyButton(
                    onSubmit: _submit,
                    width: .maxFinite,
                    title: authState.isLoading
                        ? 'Verifying...'
                        : "Verify & Continue",
                  ),
                  const SizedBox(height: 26),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
