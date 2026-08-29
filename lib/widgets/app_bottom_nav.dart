import 'package:flutter/material.dart';
import 'dart:ui';

import '../theme/app_theme.dart';

/// Glass bottom navigation with two tabs and a gap in the middle where the
/// mic cluster hovers above.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.index,
    required this.onTap,
  });

  final int index;
  final ValueChanged<int> onTap;

  static const height = 84.0;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.navFill,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          // Keeps the tabs clear of the system gesture/nav bar.
          child: SafeArea(
            top: false,
            child: Container(
              height: height,
              padding: const EdgeInsets.fromLTRB(26, 10, 26, 14),
              child: Row(
                children: [
                  Expanded(
                    child: _NavButton(
                      icon: Icons.receipt_long,
                      label: 'Home',
                      selected: index == 0,
                      onTap: () => onTap(0),
                    ),
                  ),
                  const SizedBox(width: 88),
                  Expanded(
                    child: _NavButton(
                      icon: Icons.pie_chart,
                      label: 'History',
                      selected: index == 1,
                      onTap: () => onTap(1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accentInk : AppColors.muted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 58,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: selected
                  ? AppColors.accent.withValues(alpha: 0.16)
                  : Colors.transparent,
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 3),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.6,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
