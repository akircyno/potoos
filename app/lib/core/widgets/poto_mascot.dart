import 'package:flutter/material.dart';

import '../../app/theme.dart';

enum PotoExpression { idle, happy, working, waiting, error }

extension _PotoAsset on PotoExpression {
  // State-specific PNGs in assets/mascot/ take priority.
  // Falls back to the approved reference image until per-state exports land.
  static const _reference =
      'assets/branding/potoos/mascot/poto-app-icon-reference.png';

  String get assetPath {
    switch (this) {
      case PotoExpression.idle:
        return 'assets/mascot/poto_idle.png';
      case PotoExpression.happy:
        return 'assets/mascot/poto_happy.png';
      case PotoExpression.working:
        return 'assets/mascot/poto_working.png';
      case PotoExpression.waiting:
        return 'assets/mascot/poto_waiting.png';
      case PotoExpression.error:
        return 'assets/mascot/poto_error.png';
    }
  }

  String get fallbackAssetPath => _reference;

  String get fallbackEmoji {
    switch (this) {
      case PotoExpression.idle:
        return '🦉';
      case PotoExpression.happy:
        return '🎉';
      case PotoExpression.working:
        return '⏳';
      case PotoExpression.waiting:
        return '🌙';
      case PotoExpression.error:
        return '😔';
    }
  }
}

/// Poto waving animation — loops through 6 frames paulit-ulit.
///
/// Used on the splash screen as the main mascot entrance.
class PotoWave extends StatefulWidget {
  const PotoWave({this.size = 140, super.key});

  final double size;

  @override
  State<PotoWave> createState() => _PotoWaveState();
}

class _PotoWaveState extends State<PotoWave> with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _floatController;
  late final AnimationController _frameController;
  late final Animation<double> _fade;
  late final Animation<double> _float;

  static const _frameCount = 6;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _float = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    // 120ms per frame × 6 frames = 720ms per full wave cycle
    _frameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..repeat();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _floatController.dispose();
    _frameController.dispose();
    super.dispose();
  }

  String get _framePath {
    final index = (_frameController.value * _frameCount)
        .floor()
        .clamp(0, _frameCount - 1);
    final n = (index + 1).toString().padLeft(2, '0');
    return 'assets/mascot/poto_wave_$n.png';
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: AnimatedBuilder(
        animation: Listenable.merge([_frameController, _floatController]),
        builder: (context, _) => Transform.translate(
          offset: Offset(0, _float.value),
          child: Image.asset(
            _framePath,
            width: widget.size,
            height: widget.size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Image.asset(
              'assets/branding/potoos/mascot/poto-app-icon-reference.png',
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) =>
                  SizedBox(width: widget.size, height: widget.size),
            ),
          ),
        ),
      ),
    );
  }
}

/// Poto — the Potoos memory guardian mascot.
///
/// Renders the appropriate expression PNG with an entrance fade+scale and a
/// gentle continuous idle float. Falls back to an emoji placeholder until real
/// assets are dropped into assets/mascot/.
class PotoMascot extends StatefulWidget {
  const PotoMascot({
    this.expression = PotoExpression.idle,
    this.size = 140,
    this.caption,
    this.captionStyle,
    super.key,
  });

  final PotoExpression expression;
  final double size;
  final String? caption;
  final TextStyle? captionStyle;

  @override
  State<PotoMascot> createState() => _PotoMascotState();
}

class _PotoMascotState extends State<PotoMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _entranceFade;
  late final Animation<double> _entranceScale;
  late final Animation<double> _float;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _entranceFade = CurvedAnimation(
      parent: CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.25, curve: Curves.easeIn),
      ),
      curve: Curves.linear,
    );

    _entranceScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOutBack),
      ),
    );

    _float = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _entranceFade.value,
              child: Transform.translate(
                offset: Offset(0, _float.value),
                child: Transform.scale(
                  scale: _entranceScale.value,
                  child: child,
                ),
              ),
            );
          },
          child: _PotoImage(
            expression: widget.expression,
            size: widget.size,
          ),
        ),
        if (widget.caption != null) ...[
          const SizedBox(height: 14),
          Text(
            widget.caption!,
            textAlign: TextAlign.center,
            style: widget.captionStyle ??
                TextStyle(
                  color: AppColors.featherTaupe,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
          ),
        ],
      ],
    );
  }
}

class _PotoImage extends StatelessWidget {
  const _PotoImage({required this.expression, required this.size});

  final PotoExpression expression;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      expression.assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Image.asset(
        expression.fallbackAssetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _PotoPlaceholder(
          expression: expression,
          size: size,
        ),
      ),
    );
  }
}

class _PotoPlaceholder extends StatelessWidget {
  const _PotoPlaceholder({required this.expression, required this.size});

  final PotoExpression expression;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.deepMaroon.withValues(alpha: 0.08),
        border: Border.all(
          color: AppColors.softGold.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          expression.fallbackEmoji,
          style: TextStyle(fontSize: size * 0.42),
        ),
      ),
    );
  }
}
