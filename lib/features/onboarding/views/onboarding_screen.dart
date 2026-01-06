import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/router/route_generator.dart';
import '../../../core/widgets/system_ui_handler.dart';
import '../data/onboarding_data.dart';
import '../widgets/galaxy_dots.dart';
import '../widgets/holo_grid_motion.dart';
import '../widgets/primary_galaxy_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pc = PageController();
  final ValueNotifier<double> _offset = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _pc.addListener(() => _offset.value = _pc.page ?? 0);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return SystemUIHandler(
      scaffoldBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          const Positioned.fill(child: HoloGridMotion(stroke: .18)),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView.builder(
                    controller: _pc,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _pages.length,
                    itemBuilder: (_, i) => ValueListenableBuilder<double>(
                      valueListenable: _offset,
                      builder: (_, v, _) => _Slide(
                        data: _pages[i],
                        offset: v - i,
                        screenSize: size,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ValueListenableBuilder<double>(
                  valueListenable: _offset,
                  builder: (_, v, _) =>
                      GravityLineIndicator(count: _pages.length, offset: v),
                ),
                const SizedBox(height: 28),
                ValueListenableBuilder<double>(
                  valueListenable: _offset,
                  builder: (_, v, _) {
                    final current = v.round();
                    return PrimaryGalaxyButton(
                      loader: GalaxyLoaderType.warpRings,
                      title: current == _pages.length - 1
                          ? "Get Started"
                          : "Next",
                      onSubmit: () async {
                        if (current < _pages.length - 1) {
                          _pc.nextPage(
                            duration: const Duration(milliseconds: 450),
                            curve: Curves.easeOutCubic,
                          );
                        } else {
                          onFinishOnboarding(context);
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 42),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> onFinishOnboarding(BuildContext context) async {
    await OnboardingStore.markSeen();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      RouteGenerator.authMobile,
      (_) => false,
    );
  }
}

// CHANGE HERE #1 – Your 3 pages (title, description, and 3 icons)
final List<_PageData> _pages = [
  _PageData(
    title: "Privacy Locked",
    description: "Encrypted chats.\nYou control everything.",
    icons: [
      Icons.lock_outline_rounded,
      Icons.shield_rounded,
      Icons.fingerprint_rounded,
    ],
  ),
  _PageData(
    title: "Instant Sync",
    description: "Messages reach faster\nthan you can blink.",
    icons: [Icons.flash_on_rounded, Icons.speed_rounded, Icons.bolt_rounded],
  ),
  _PageData(
    title: "Crystal Calls",
    description: "HD voice & video.\nFeels like you’re in the same room.",
    icons: [
      Icons.videocam_rounded,
      Icons.hd_rounded,
      Icons.headset_mic_rounded,
    ],
  ),
];

class _PageData {
  final String title;
  final String description;
  final List<IconData> icons;
  const _PageData({
    required this.title,
    required this.description,
    required this.icons,
  });
}

// ──────────────────────────────────────────────────────────────

class _Slide extends StatelessWidget {
  final _PageData data;
  final double offset;
  final Size screenSize;

  const _Slide({
    required this.data,
    required this.offset,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    final scale = 1 - offset.abs() * 0.18;
    final shiftX = offset * -50;
    final shiftY = offset * -18;

    return Transform.translate(
      offset: Offset(shiftX, shiftY),
      child: Transform.scale(
        scale: scale,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 3 connected icons – same beautiful animation as before
              TriangleOrbitIcons(
                icons: data.icons,
                size: screenSize.width * 0.76,
              ),

              const SizedBox(height: 64),

              Text(
                data.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: 1.2,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                data.description,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.55,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.78),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────── BEAUTIFUL TRIANGLE ORBIT (no changes needed here) ────────

class TriangleOrbitIcons extends StatefulWidget {
  final List<IconData> icons;
  final double size;
  const TriangleOrbitIcons({
    super.key,
    required this.icons,
    required this.size,
  });

  @override
  State<TriangleOrbitIcons> createState() => _TriangleOrbitIconsState();
}

class _TriangleOrbitIconsState extends State<TriangleOrbitIcons>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat(reverse: true);
    _float = CurvedAnimation(parent: _anim, curve: Curves.easeInOutSine);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    final iconSize = s * 0.32;

    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _float,
        builder: (_, __) {
          final float = (_float.value - 0.5) * 16;

          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(s, s),
                painter: _DottedTrianglePainter(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withOpacity(0.5),
                ),
              ),

              // Top
              Positioned(
                top: s * 0.08 + float,
                child: _glowIcon(icon: widget.icons[0], size: iconSize),
              ),

              // Bottom-left
              Positioned(
                left: s * 0.12,
                bottom: s * 0.10 - float * 0.6,
                child: _glowIcon(icon: widget.icons[1], size: iconSize),
              ),

              // Bottom-right
              Positioned(
                right: s * 0.12,
                bottom: s * 0.10 + float * 0.8,
                child: _glowIcon(icon: widget.icons[2], size: iconSize),
              ),
            ],
          );
        },
      ),
    );
  }
}

Widget _glowIcon({required IconData icon, required double size}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: AppColors.primaryGradient,
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withOpacity(0.56),
          blurRadius: 48,
          spreadRadius: 8,
        ),
      ],
    ),
    child: Icon(icon, color: Colors.white, size: size * 0.52),
  );
}

class _DottedTrianglePainter extends CustomPainter {
  final Color color;

  _DottedTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.8
      ..style = PaintingStyle.stroke;

    const dashWidth = 9.0;
    const dashSpace = 12.0;

    final center = Offset(size.width / 2, size.height / 2);
    final p1 = Offset(center.dx, center.dy - size.height * 0.28); // Top
    final p2 = Offset(
      center.dx - size.width * 0.34,
      center.dy + size.height * 0.22,
    ); // Bottom-left
    final p3 = Offset(
      center.dx + size.width * 0.34,
      center.dy + size.height * 0.22,
    ); // Bottom-right

    final points = [p1, p2, p3, p1];

    for (int i = 0; i < 3; i++) {
      final path = Path()
        ..moveTo(points[i].dx, points[i].dy)
        ..lineTo(points[i + 1].dx, points[i + 1].dy);
      final metric = path.computeMetrics().first;
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
