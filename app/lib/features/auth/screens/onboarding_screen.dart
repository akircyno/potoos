import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/poto_mascot.dart';
import '../../../core/widgets/pressable_scale.dart';

const _kOnboardingKey = 'onboarding_seen';

Future<void> markOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingKey, true);
}

Future<bool> hasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingKey) ?? false;
}

// ── Page model ────────────────────────────────────────────────────────────────

class _Page {
  const _Page({
    required this.expression,
    required this.heading,
    required this.body,
    this.accentIcon,
  });

  final PotoExpression expression;
  final String heading;
  final String body;
  final IconData? accentIcon;
}

const _pages = [
  _Page(
    expression: PotoExpression.happy,
    heading: 'Meet Poto.',
    body: 'Your memory guardian. Here to keep every original exactly as you took it — no compression, no quality loss.',
  ),
  _Page(
    expression: PotoExpression.idle,
    heading: 'Just the people you choose.',
    body: 'No public feeds. No strangers. Only the people you invite can see your space.',
    accentIcon: Icons.lock_outline,
  ),
  _Page(
    expression: PotoExpression.working,
    heading: 'Nothing gets compressed.',
    body: 'Every photo and video stores at full resolution. Download it back exactly as it was taken.',
    accentIcon: Icons.verified_outlined,
  ),
];

// ── Screen ────────────────────────────────────────────────────────────────────

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  int _currentPage = 0;

  // Per-page entrance controller — reused on page change
  late AnimationController _pageEntrance;
  late Animation<double> _potoFade;
  late Animation<double> _potoScale;
  late Animation<Offset> _contentSlide;
  late Animation<double> _contentFade;

  @override
  void initState() {
    super.initState();
    _initPageAnimation();
    _pageEntrance.forward();
  }

  void _initPageAnimation() {
    _pageEntrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );

    _potoFade = CurvedAnimation(
      parent: _pageEntrance,
      curve: const Interval(0.0, 0.50, curve: Curves.easeOut),
    );

    _potoScale = Tween(begin: 0.84, end: 1.0).animate(
      CurvedAnimation(
        parent: _pageEntrance,
        curve: const Interval(0.0, 0.48, curve: Curves.easeOutBack),
      ),
    );

    _contentSlide = Tween(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _pageEntrance,
      curve: const Interval(0.22, 0.80, curve: Curves.easeOutCubic),
    ));

    _contentFade = CurvedAnimation(
      parent: _pageEntrance,
      curve: const Interval(0.22, 0.75, curve: Curves.easeOut),
    );
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    _pageEntrance.reset();
    _pageEntrance.forward();
  }

  Future<void> _finish() async {
    await markOnboardingSeen();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pageEntrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.midnightBurgundy,
        body: Container(
          decoration: const BoxDecoration(gradient: AppGradients.splash),
          child: SafeArea(
            child: Column(
              children: [
                // ── Skip button ───────────────────────────────────────
                Align(
                  alignment: Alignment.topRight,
                  child: AnimatedOpacity(
                    opacity: isLast ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: GestureDetector(
                      onTap: isLast ? null : _finish,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 16, 20, 8),
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: AppColors.featherTaupe
                                .withValues(alpha: 0.75),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Pages ─────────────────────────────────────────────
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      return _PageContent(
                        page: page,
                        potoFade: _potoFade,
                        potoScale: _potoScale,
                        contentSlide: _contentSlide,
                        contentFade: _contentFade,
                      );
                    },
                  ),
                ),

                // ── Bottom bar: dots + CTA ────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(
                      AppSpacing.xl, AppSpacing.md, AppSpacing.xl,
                      AppSpacing.md + bottomPad),
                  child: Row(
                    children: [
                      // Dot indicators
                      Row(
                        children: List.generate(
                          _pages.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            margin: const EdgeInsets.only(right: 6),
                            width: i == _currentPage ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: i == _currentPage
                                  ? AppColors.brightGold
                                  : AppColors.featherTaupe
                                      .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                      ),

                      const Spacer(),

                      // Next / Get Started
                      PressableScale(
                        onTap: isLast
                            ? _finish
                            : () => _goToPage(_currentPage + 1),
                        borderRadius: BorderRadius.circular(999),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          height: 48,
                          padding: EdgeInsets.symmetric(
                              horizontal: isLast ? 24 : 0),
                          width: isLast ? null : 48,
                          decoration: BoxDecoration(
                            color: AppColors.brightGold,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: AppShadows.goldButton,
                          ),
                          child: Center(
                            child: isLast
                                ? const Text(
                                    'Get started',
                                    style: TextStyle(
                                      color: AppColors.deepMaroon,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : const Icon(
                                    Icons.arrow_forward_rounded,
                                    color: AppColors.deepMaroon,
                                    size: 20,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Page content ──────────────────────────────────────────────────────────────

class _PageContent extends StatelessWidget {
  const _PageContent({
    required this.page,
    required this.potoFade,
    required this.potoScale,
    required this.contentSlide,
    required this.contentFade,
  });

  final _Page page;
  final Animation<double> potoFade;
  final Animation<double> potoScale;
  final Animation<Offset> contentSlide;
  final Animation<double> contentFade;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Poto with optional accent icon badge
          FadeTransition(
            opacity: potoFade,
            child: ScaleTransition(
              scale: potoScale,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  PotoMascot(expression: page.expression, size: 140),
                  if (page.accentIcon != null)
                    Positioned(
                      right: -4,
                      bottom: 8,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.brightGold,
                          shape: BoxShape.circle,
                          boxShadow: AppShadows.goldButton,
                        ),
                        child: Icon(page.accentIcon,
                            color: AppColors.deepMaroon, size: 18),
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // Heading + body
          FadeTransition(
            opacity: contentFade,
            child: SlideTransition(
              position: contentSlide,
              child: Column(
                children: [
                  Text(
                    page.heading,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppTheme.headingFont,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.pearlCream,
                      letterSpacing: -0.4,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    page.body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.featherTaupe.withValues(alpha: 0.85),
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
