// 4 Next-Level Loaders for chat + audio/video app
// File: lib/features/onboarding/widgets/galaxy_loaders.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';

// -------------------------------------------------------------
// 1️⃣ Triple Dots Orbit — communication satellites orbiting
// -------------------------------------------------------------
class TripleDotsOrbit extends StatelessWidget {
  final AnimationController controller;
  const TripleDotsOrbit({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final angle = controller.value * 6.28318;
          const r = 8.5;
          return Stack(
            alignment: Alignment.center,
            children: List.generate(3, (i) {
              final a = angle + i * 2.0944;
              return Transform.translate(
                offset: Offset(r * math.cos(a), r * math.sin(a)),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor.withOpacity(0.8),
                        Theme.of(context).primaryColor,
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

// -------------------------------------------------------------
// 2️⃣ Warp Rings — signal distortion / connection warp
// -------------------------------------------------------------
class WarpRings extends StatelessWidget {
  final AnimationController controller;
  const WarpRings({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 38,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) =>
            CustomPaint(painter: _WarpPainterV2(t: controller.value)),
      ),
    );
  }
}

class _WarpPainterV2 extends CustomPainter {
  final double t;
  _WarpPainterV2({required this.t});

  @override
  void paint(Canvas canvas, Size s) {
    final c = Offset(s.width / 2, s.height / 2);

    for (int i = 0; i < 3; i++) {
      final progress = (t + i * .28) % 1.0;

      // 🚀 Apply easing curve → warp expansion acceleration
      final eased = Curves.easeOutQuart.transform(progress);

      final radius = lerpDouble(2, 16, eased)!;
      final alpha = (1.0 - eased).clamp(0.0, 1.0);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lerpDouble(2.6, 0.8, eased)!
        ..color = Colors.white.withOpacity(alpha * 0.88)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 4.5);

      canvas.drawCircle(c, radius, paint);
    }

    // ⭐ Tiny core pulse
    final coreSize = 4 + math.sin(t * math.pi * 2) * 1.4;
    canvas.drawCircle(
      c,
      coreSize,
      Paint()..color = Colors.white.withOpacity(.95),
    );
  }

  @override
  bool shouldRepaint(covariant _WarpPainterV2 old) => true;
}

// -------------------------------------------------------------
// 3️⃣ Nano Particles — tiny encrypted packets traveling
// -------------------------------------------------------------
class NanoParticles extends StatelessWidget {
  final AnimationController controller;
  const NanoParticles({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32,
      height: 32,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) =>
            CustomPaint(painter: _NanoPainter(controller.value)),
      ),
    );
  }
}

class _NanoPainter extends CustomPainter {
  final double t;
  _NanoPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..style = PaintingStyle.fill;
    const count = 8;
    const radius = 10.5;

    for (int i = 0; i < count; i++) {
      final progress = (t + i * .125) % 1.0;
      final angle = progress * 6.28318;
      final px = c.dx + radius * math.cos(angle);
      final py = c.dy + radius * math.sin(angle);

      paint.color = Colors.white.withOpacity(.25 + progress * .75);

      canvas.drawCircle(Offset(px, py), 2.7 - progress * 1.7, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NanoPainter old) => old.t != t;
}

// -------------------------------------------------------------
// 4️⃣ Wave Dots — live voice/video waveform communication
// -------------------------------------------------------------
class WaveDots extends StatelessWidget {
  final AnimationController controller;
  const WaveDots({required this.controller, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 34,
      child: AnimatedBuilder(
        animation: controller,
        builder: (_, __) =>
            CustomPaint(painter: _WaveDotsPainter(controller.value)),
      ),
    );
  }
}

class _WaveDotsPainter extends CustomPainter {
  final double t;
  _WaveDotsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final baseX = size.width / 2 - 12;

    for (int i = 0; i < 5; i++) {
      final p = (t + i * .12) % 1.0;
      final amp = 7;
      final dy = math.sin(p * 6.28318) * amp;

      final paint = Paint()..color = Colors.white.withOpacity(.55 + p * .45);

      canvas.drawCircle(
        Offset(baseX + i * 6, centerY + dy),
        3.5 - p * 1.5,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveDotsPainter old) => old.t != t;
}

// -------------------------------------------------------------
// Helper
// -------------------------------------------------------------
double? lerpDouble(num a, num b, double t) => a + (b - a) * t;
