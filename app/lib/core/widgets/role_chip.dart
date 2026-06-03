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
    final lower = label.toLowerCase();
    final isContributor = lower == 'contributor';
    final isViewer = lower == 'viewer';

    final Color fg = isViewer
        ? AppColors.mutedInk
        : isContributor
            ? AppColors.softGold
            : AppColors.velvetMaroon;

    final Color bg = selected
        ? (isContributor
            ? AppColors.brightGold.withValues(alpha: 0.10)
            : isViewer
                ? AppColors.featherTaupe.withValues(alpha: 0.10)
                : AppColors.maroonFaint)
        : AppColors.warmCream;

    return ActionChip(
      onPressed: onTap,
      label: Text(label.toUpperCase()),
      labelStyle: TextStyle(
        color: fg,
        fontSize: 10,
        letterSpacing: 0.5,
        fontWeight: FontWeight.w600,
      ),
      backgroundColor: bg,
      side: BorderSide(
        color: selected
            ? fg.withValues(alpha: 0.28)
            : AppColors.creamLine,
        width: 0.8,
      ),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill)),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      visualDensity: VisualDensity.compact,
    );
  }
}
