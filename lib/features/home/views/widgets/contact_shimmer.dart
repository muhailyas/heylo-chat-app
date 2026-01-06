// File: lib/features/home/views/widgets/new_chat_shimmer.dart

import 'package:flutter/material.dart';

class NewChatShimmer extends StatelessWidget {
  const NewChatShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(0, 12, 0, 16 + bottom),
      children: const [
        _SearchBarShimmer(),

        SizedBox(height: 15),
        _SectionHeaderShimmer(),
        _ContactRowShimmer(),
        _ContactRowShimmer(),
        _ContactRowShimmer(),

        SizedBox(height: 16),
        _SectionHeaderShimmer(),
        _ContactRowShimmer(),
        _ContactRowShimmer(),
      ],
    );
  }
}

class _SearchBarShimmer extends StatelessWidget {
  const _SearchBarShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _SectionHeaderShimmer extends StatelessWidget {
  const _SectionHeaderShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Container(
        width: 140,
        height: 12,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.06),
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

class _ContactRowShimmer extends StatelessWidget {
  const _ContactRowShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(.06),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 14,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: 140,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
