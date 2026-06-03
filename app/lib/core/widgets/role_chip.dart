import 'package:flutter/material.dart';

import '../../app/theme.dart';

class RoleChip extends StatelessWidget {
  const RoleChip({
    required this.label,
    this.selected = false,
    this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isContributor = label.toLowerCase() == 'contributor';
    final isViewer = label.toLowerCase() == 'viewer';
    final background = selected
        ? (isContributor ? AppColors.goldFaint : AppColors.maroonFaint)
        : AppColors.warmCream;
    final foreground = isViewer
        ? AppColors.mutedInk
        : isContributor
            ? AppColors.softGold
            : AppColors.maroon;

    return ActionChip(
      onPressed: onTap,
      label: Text(label.toUpperCase()),
      labelStyle: TextStyle(
        color: foreground,
        fontSize: 10,
        letterSpacing: 0.5,
        fontWeight: FontWeight.w500,
      ),
      backgroundColor: background,
      side: BorderSide(
          color: selected
              ? foreground.withValues(alpha: 0.28)
              : AppColors.creamLine),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    );
  }
}
