import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heylo/core/widgets/system_ui_handler.dart';
import 'package:heylo/features/splash/view_model/notifiers/splash_notifier.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_generator.dart';
import '../../onboarding/widgets/holo_grid_motion.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  static const route = RouteGenerator.splash;

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  double tilt = 0;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..forward();

    // ignore: deprecated_member_use
    accelerometerEvents.listen((a) {
      if (!mounted) return;
      tilt = (a.x * .04).clamp(-.05, .05);
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), _chechAuth);
    });
  }

  void _chechAuth() {
    ref
        .read(splashProvider.notifier)
        .check(
          onDone: ({required isLoggedIn, required showOnboarding}) async {
            if (showOnboarding) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                RouteGenerator.onboarding,
                (route) => false,
              );
              return;
            }
            if (isLoggedIn) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                RouteGenerator.home,
                (route) => false,
              );
            } else {
              Navigator.pushNamedAndRemoveUntil(
                context,
                RouteGenerator.authMobile,
                (route) => false,
              );
            }
          },
        );
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Keep provider alive
    ref.watch(splashProvider);

    final s = MediaQuery.sizeOf(context);
    final theme = Theme.of(context);

    return SystemUIHandler(
      scaffoldBackgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          HoloGridMotion(stroke: .65),
          Center(
            child: Transform.rotate(
              angle: tilt,
              child: ScaleTransition(
                scale: CurvedAnimation(parent: _ac, curve: Curves.elasticOut),
                child: Container(
                  width: s.width * .35,
                  height: s.width * .35,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: .50),
                        blurRadius: 50,
                        spreadRadius: 12,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.chat_rounded,
                    size: 66,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
          ),
          FadeTransition(
            opacity: CurvedAnimation(parent: _ac, curve: const Interval(.3, 1)),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: s.height * .12),
                child: Text(
                  "Heylo",
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
