import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/pressable_scale.dart';

class GoogleLoginButton extends StatelessWidget {
  const GoogleLoginButton({
    required this.onPressed,
    this.isLoading = false,
    super.key,
  });

  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: isLoading ? null : onPressed,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFDadCE0),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isLoading
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.featherTaupe,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Opening Google...',
                    style: TextStyle(
                      color: Color(0xFF3C4043),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  const SizedBox(width: 16),
                  SvgPicture.asset(
                    'assets/logo/google_g.svg',
                    width: 20,
                    height: 20,
                  ),
                  Expanded(
                    child: Text(
                      'Continue with Google',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF3C4043),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.1,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  const SizedBox(width: 36),
                ],
              ),
      ),
    );
  }
}
