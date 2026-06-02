import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../config/constants.dart';
import '../../../core/widgets/brand_mark.dart';
import '../widgets/google_login_button.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.deepMaroon,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.softGold.withValues(alpha: 0.40),
                      width: 2),
                ),
                child: const BrandMark(size: 58),
              ),
              const SizedBox(height: 24),
              RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: AppColors.warmCream,
                        fontSize: 28,
                      ),
                  children: const [
                    TextSpan(text: 'Litrato'),
                    TextSpan(
                        text: 'Link',
                        style: TextStyle(color: AppColors.goldLight)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppText.tagline,
                style: TextStyle(
                    color: AppColors.warmCream.withValues(alpha: 0.60),
                    fontSize: 13),
              ),
              const SizedBox(height: 32),
              Text(
                'Memories shared the way they were meant to be seen.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      color: AppColors.warmCream,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 14),
              Text(
                'Private albums. Invited people only. Every photo and video in full original quality.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.warmCream.withValues(alpha: 0.55),
                    height: 1.65,
                    fontSize: 13),
              ),
              const SizedBox(height: 20),
              const Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  _WelcomePill(icon: Icons.lock_outline, label: 'Private'),
                  _WelcomePill(
                      icon: Icons.star_outline, label: 'Original quality'),
                  _WelcomePill(
                      icon: Icons.group_outlined, label: 'Invite-only'),
                ],
              ),
              const Spacer(),
              GoogleLoginButton(
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, AppRoutes.home),
              ),
              const SizedBox(height: 14),
              Text(
                'No likes. No comments. No public feed.\nJust you and the people you choose.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.warmCream.withValues(alpha: 0.40),
                    fontSize: 11,
                    height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomePill extends StatelessWidget {
  const _WelcomePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.warmCream.withValues(alpha: 0.08),
        border: Border.all(
            color: AppColors.warmCream.withValues(alpha: 0.15), width: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.goldLight, size: 11),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: AppColors.warmCream.withValues(alpha: 0.60),
                  fontSize: 11)),
        ],
      ),
    );
  }
}
