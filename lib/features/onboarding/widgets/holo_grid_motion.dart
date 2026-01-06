import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:sensors_plus/sensors_plus.dart';

class HoloGridMotion extends StatefulWidget {
  final double stroke;
  const HoloGridMotion({super.key, this.stroke = 1.0});

  @override
  State<HoloGridMotion> createState() => _HoloGridMotionState();
}

class _HoloGridMotionState extends State<HoloGridMotion>
    with SingleTickerProviderStateMixin {
  late final Ticker ticker;
  late final StreamSubscription<AccelerometerEvent> accelSub;

  double targetX = 0, targetY = 0;
  double tiltX = 0, tiltY = 0;

  @override
  void initState() {
    super.initState();
    ticker = Ticker((_) {
      const smooth = 0.18;
      tiltX += (targetX - tiltX) * smooth;
      tiltY += (targetY - tiltY) * smooth;
      if (mounted) setState(() {});
    })..start();

    const sens = 0.8;
    // ignore: deprecated_member_use
    accelSub = accelerometerEvents.listen((e) {
      targetX = (e.x * sens).clamp(-12, 12);
      targetY = (-e.y * sens).clamp(-12, 12);
    });
  }

  @override
  void dispose() {
    ticker.dispose();
    accelSub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurface;
    return SizedBox.expand(
      child: CustomPaint(
        painter: _SoftCurvedGridPainter(
          tiltX: tiltX,
          tiltY: tiltY,
          stroke: widget.stroke,
          color: color,
        ),
      ),
    );
  }
}

class _SoftCurvedGridPainter extends CustomPainter {
  final double tiltX, tiltY, stroke;
  final Color color;
  const _SoftCurvedGridPainter({
    required this.tiltX,
    required this.tiltY,
    required this.stroke,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final shortest = size.shortestSide;

    // Slightly reduced grid scale
    final scale = shortest * 0.85;

    const camZ = 3.0;

    final yaw = (tiltX * 0.05).clamp(-0.6, 0.6);
    final pitch = (tiltY * 0.05).clamp(-0.6, 0.6);

    final cosY = math.cos(yaw), sinY = math.sin(yaw);
    final cosX = math.cos(pitch), sinX = math.sin(pitch);

    // Wider projection area → fills screen edges
    const maxN = 1.45;
    const step = 0.16;

    Offset project(double u, double v) {
      final r2 = (u * u + v * v) / (maxN * maxN);

      // 🔥 Reduced curve intensity (smaller bulge)
      const bulge = 0.65; // Previous: 1.2 → NOW subtler
      final z = (1.0 - r2).clamp(0, 1.0) * bulge;

      double x = u, y = v, zz = z;

      final x1 = x * cosY + zz * sinY;
      final z1 = -x * sinY + zz * cosY;
      final y1 = y * cosX - z1 * sinX;
      final z2 = y * sinX + z1 * cosX;

      final d = camZ - z2;
      final p = camZ / d;

      return Offset(x1 * p * scale + center.dx, y1 * p * scale + center.dy);
    }

    for (double u = -maxN; u <= maxN; u += step) {
      _draw(canvas, size, project, u, true);
    }
    for (double v = -maxN; v <= maxN; v += step) {
      _draw(canvas, size, project, v, false);
    }

    _glow(canvas, center, shortest);
  }

  void _draw(
    Canvas c,
    Size s,
    Offset Function(double, double) project,
    double f,
    bool vertical,
  ) {
    const seg = 52;
    const min = -1.45, max = 1.45;
    final dt = (max - min) / seg;

    Offset? prev;

    for (int i = 0; i <= seg; i++) {
      final t = min + dt * i;
      final p = vertical ? project(f, t) : project(t, f);

      if (!_screen(p, s)) {
        prev = null;
        continue;
      }
      if (prev != null) {
        final d =
            (p - Offset(s.width / 2, s.height / 2)).distance /
            (s.shortestSide / 2);
        final a = lerpDouble(0.05, 0.28, (1 - d).clamp(0, 1)) ?? 0.15;
        c.drawLine(
          prev,
          p,
          Paint()
            ..strokeWidth = stroke
            ..color = color.withOpacity(a),
        );
      }
      prev = p;
    }
  }

  void _glow(Canvas c, Offset center, double shortest) {
    final r = shortest * 0.44;
    final rect = Rect.fromCircle(center: center, radius: r);
    c.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withOpacity(0.12), Colors.transparent],
        ).createShader(rect),
    );
  }

  bool _screen(Offset p, Size s) {
    const m = 50;
    return p.dx >= -m &&
        p.dx <= s.width + m &&
        p.dy >= -m &&
        p.dy <= s.height + m;
  }

  @override
  bool shouldRepaint(covariant _SoftCurvedGridPainter old) =>
      tiltX != old.tiltX ||
      tiltY != old.tiltY ||
      stroke != old.stroke ||
      color != old.color;
}
