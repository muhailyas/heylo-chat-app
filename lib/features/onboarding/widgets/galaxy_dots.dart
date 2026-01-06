// Gravity-Line Page Indicator — premium, clean, zero-confusion
// One active comet glides smoothly across a minimal star runway
// File: lib/features/onboarding/widgets/gravity_line_indicator.dart

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

class GravityLineIndicator extends StatelessWidget {
  final int count;
  final double offset;
  const GravityLineIndicator({
    super.key,
    required this.count,
    required this.offset,
  });

  @override
  Widget build(BuildContext context) {
    final width = 10.0 * count + 24.0;

    return SizedBox(
      width: width,
      height: 16,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Static runway (stars)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              count,
              (i) => Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .25),
                ),
              ),
            ),
          ),

          // Comet — smooth slide
          AnimatedBuilder(
            animation: AlwaysStoppedAnimation(offset),
            builder: (_, _) {
              final clamped = offset.clamp(0.0, (count - 1).toDouble());
              final dx = lerpDouble(0, width - 10, clamped / (count - 1))!;
              return Transform.translate(
                offset: Offset(dx, 0),
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
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
                        ).primaryColor.withValues(alpha: .45),
                        blurRadius: 22,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Tail fade behind comet
          AnimatedBuilder(
            animation: AlwaysStoppedAnimation(offset),
            builder: (_, __) {
              final tailStart = offset.clamp(0.0, (count - 1).toDouble());
              final tailWidth =
                  (tailStart / (count - 1)).clamp(0.0, 1.0) * width;

              return Positioned(
                left: 0,
                child: Container(
                  width: tailWidth,
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).primaryColor.withValues(alpha: .20),
                        Theme.of(context).primaryColor.withValues(alpha: .35),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
