import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../config/constants.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/widgets/poto_mascot.dart';
import '../providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    Timer(const Duration(milliseconds: 1800), () async {
      if (mounted) {
        final session = ref.read(supabaseServiceProvider).currentSession;
        if (session != null) {
          await ref.read(authControllerProvider.notifier).loadCurrentUserProfile();
        }

        if (!mounted) return;

        Navigator.pushReplacementNamed(
          context,
          session == null ? AppRoutes.login : AppRoutes.home,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.midnightBurgundy,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.midnightBurgundy, AppColors.deepMaroon],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PotoWave(size: 140),
                  const SizedBox(height: 28),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: AppTheme.headingFont,
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                      children: const [
                        TextSpan(
                          text: 'Poto',
                          style: TextStyle(color: AppColors.pearlCream),
                        ),
                        TextSpan(
                          text: 'os',
                          style: TextStyle(color: AppColors.brightGold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppText.tagline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.featherTaupe,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: AppColors.brightGold.withValues(alpha: 0.70),
                      strokeWidth: 2,
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
