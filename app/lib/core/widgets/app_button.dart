import 'package:flutter/material.dart';

import '../../app/theme.dart';
import 'pressable_scale.dart';

enum AppButtonVariant { primary, gold, ghost }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.fullWidth = true,
    this.isLoading = false,
    this.secondary = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool fullWidth;
  final bool isLoading;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final effectiveVariant = secondary ? AppButtonVariant.ghost : variant;
    final isDisabled = onPressed == null || isLoading;

    final Color bg;
    final Color fg;
    Border? border;
    List<BoxShadow>? shadows;

    switch (effectiveVariant) {
      case AppButtonVariant.primary:
        bg = isDisabled ? AppColors.creamLine : AppColors.velvetMaroon;
        fg = isDisabled ? AppColors.featherTaupe : AppColors.pearlCream;
        shadows = isDisabled ? null : AppShadows.primaryButton;
      case AppButtonVariant.gold:
        bg = isDisabled ? AppColors.creamLine : AppColors.brightGold;
        fg = isDisabled ? AppColors.featherTaupe : AppColors.deepMaroon;
        shadows = isDisabled ? null : AppShadows.goldButton;
      case AppButtonVariant.ghost:
        bg = AppColors.white;
        fg = isDisabled ? AppColors.featherTaupe : AppColors.charcoalInk;
        border = Border.all(color: AppColors.creamLine, width: 1.5);
    }

    final content = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 17, color: fg),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                  fontFamily: AppTheme.bodyFont,
                ),
              ),
            ],
          );

    final inner = Container(
      height: 52,
      width: fullWidth ? double.infinity : null,
      padding: fullWidth ? null : const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: border,
        boxShadow: shadows,
      ),
      child: content,
    );

    if (isDisabled) return inner;

    return PressableScale(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
      child: inner,
    );
  }
}
