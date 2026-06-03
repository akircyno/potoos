import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'pressable_scale.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.dark = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = dark ? AppColors.deepMaroon : AppColors.white;
    final borderColor = dark
        ? AppColors.pearlCream.withValues(alpha: 0.07)
        : AppColors.velvetMaroon.withValues(alpha: 0.10);

    final card = Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      clipBehavior: Clip.antiAlias,
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          border: Border.all(color: borderColor, width: 0.8),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          boxShadow: AppShadows.card,
        ),
        child: child,
      ),
    );

    if (onTap == null) return card;

    return PressableScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: card,
    );
  }
}
