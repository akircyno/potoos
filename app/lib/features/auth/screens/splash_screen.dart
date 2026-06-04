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

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // Entrance — plays once, completes before the 1800ms navigation fires
  late final AnimationController _entrance;

  // Poto: scale from 0.82 → 1.0  (0 → 38%)
  late final Animation<double> _potoScale;

  // Wordmark: slide up + fade  (18 → 62%)
  late final Animation<Offset> _wordSlide;
  late final Animation<double> _wordFade;

  // Tagline: fade  (38 → 72%)
  late final Animation<double> _tagFade;

  // Spinner: fade  (58 → 88%)
  late final Animation<double> _spinFade;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);

    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();

    _potoScale = Tween(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrance,
        curve: const Interval(0.0, 0.38, curve: Curves.easeOutBack),
      ),
    );

    _wordSlide = Tween(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.18, 0.62, curve: Curves.easeOutCubic),
    ));

    _wordFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.18, 0.58, curve: Curves.easeOut),
    );

    _tagFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.38, 0.72, curve: Curves.easeOut),
    );

    _spinFade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.58, 0.88, curve: Curves.easeOut),
    );

    Timer(const Duration(milliseconds: 1800), () async {
      if (mounted) {
        final session = ref.read(supabaseServiceProvider).currentSession;
        if (session != null) {
          await ref
              .read(authControllerProvider.notifier)
              .loadCurrentUserProfile();
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
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.midnightBurgundy,
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppGradients.splash,
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Poto waving ───────────────────────────────────────
                  ScaleTransition(
                    scale: _potoScale,
                    child: const PotoWave(size: 140),
                  ),

                  const SizedBox(height: 28),

                  // ── Wordmark ──────────────────────────────────────────
                  FadeTransition(
                    opacity: _wordFade,
                    child: SlideTransition(
                      position: _wordSlide,
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontFamily: AppTheme.headingFont,
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                          ),
                          children: [
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
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Tagline ───────────────────────────────────────────
                  FadeTransition(
                    opacity: _tagFade,
                    child: Text(
                      AppText.tagline,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.featherTaupe,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // ── Loading indicator ─────────────────────────────────
                  FadeTransition(
                    opacity: _spinFade,
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: AppColors.brightGold.withValues(alpha: 0.70),
                        strokeWidth: 2,
                      ),
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
