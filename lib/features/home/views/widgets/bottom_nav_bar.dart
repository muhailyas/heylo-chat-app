// File: lib/features/home/widgets/bottom_nav_bar.dart

import 'package:flutter/material.dart';

import 'nav_item.dart';

class HomeBottomNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChange;

  const HomeBottomNavBar({
    super.key,
    required this.index,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(.1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          NavItem(
            icon: Icons.chat_bubble,
            label: "Chats",
            selected: index == 0,
            onTap: () => onChange(0),
          ),
          NavItem(
            icon: Icons.call,
            label: "Calls",
            selected: index == 1,
            onTap: () => onChange(1),
          ),
          NavItem(
            icon: Icons.grid_view,
            label: "Explore",
            selected: index == 2,
            onTap: () => onChange(2),
          ),
          NavItem(
            icon: Icons.settings,
            label: "Profile",
            selected: index == 3,
            onTap: () => onChange(3),
          ),
        ],
      ),
    );
  }
}
