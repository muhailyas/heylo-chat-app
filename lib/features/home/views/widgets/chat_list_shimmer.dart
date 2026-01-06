import 'package:flutter/material.dart';

/// Shimmer loading effect for the home page chat list
class ChatListShimmer extends StatefulWidget {
  const ChatListShimmer({super.key});

  @override
  State<ChatListShimmer> createState() => _ChatListShimmerState();
}

class _ChatListShimmerState extends State<ChatListShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(
      begin: -2,
      end: 2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        8,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return _ChatTileShimmer(gradientOffset: _animation.value);
            },
          ),
        ),
      ),
    );
  }
}

class _ChatTileShimmer extends StatelessWidget {
  final double gradientOffset;

  const _ChatTileShimmer({required this.gradientOffset});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .06)),
      ),
      child: Row(
        children: [
          // Avatar shimmer
          _ShimmerBox(
            width: 40,
            height: 40,
            borderRadius: BorderRadius.circular(20),
            gradientOffset: gradientOffset,
          ),
          const SizedBox(width: 16),

          // Name and message shimmer
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ShimmerBox(
                  height: 14,
                  width: double.infinity,
                  borderRadius: BorderRadius.circular(6),
                  gradientOffset: gradientOffset,
                ),
                const SizedBox(height: 8),
                _ShimmerBox(
                  height: 12,
                  width: 180,
                  borderRadius: BorderRadius.circular(6),
                  gradientOffset: gradientOffset,
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // Time / Unread
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ShimmerBox(
                height: 11,
                width: 40,
                borderRadius: BorderRadius.circular(6),
                gradientOffset: gradientOffset,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;
  final double gradientOffset;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.borderRadius,
    required this.gradientOffset,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white : Colors.black;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.1, 0.5, 0.9],
          colors: [
            baseColor.withValues(alpha: 0.05),
            baseColor.withValues(alpha: 0.12),
            baseColor.withValues(alpha: 0.05),
          ],
          transform: _GradientTranslation(gradientOffset),
        ),
      ),
    );
  }
}

class _GradientTranslation extends GradientTransform {
  final double offset;

  const _GradientTranslation(this.offset);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * offset, 0, 0);
  }
}
