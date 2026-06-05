import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_screen.dart';
import '../../../core/widgets/poto_mascot.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../models/upload_file.dart';
import '../providers/upload_provider.dart';

class UploadProgressScreen extends ConsumerStatefulWidget {
  const UploadProgressScreen({super.key});

  @override
  ConsumerState<UploadProgressScreen> createState() =>
      _UploadProgressScreenState();
}

class _UploadProgressScreenState extends ConsumerState<UploadProgressScreen> {
  UploadProgressArgs? _args;
  bool _started = false;
  bool _retrying = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is UploadProgressArgs) {
      _args = routeArgs;
      if (!_started) {
        _started = true;
        Future.microtask(() {
          ref.read(uploadControllerProvider.notifier).upload(
                albumId: routeArgs.album.id,
                files: routeArgs.files,
              );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploadArgs = _args;
    final state = ref.watch(uploadControllerProvider);
    final files = uploadArgs?.files ?? const [];
    final album = uploadArgs?.album;

    if (files.isEmpty || album == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Upload')),
        body: const AppScreen(
          children: [
            AppEmptyState(
              title: 'Upload unavailable',
              message: 'Start uploads from an album with selected files.',
              expression: PotoExpression.error,
            ),
          ],
        ),
      );
    }

    final isUploading = state.isUploading;
    final isComplete = state.isComplete;
    final hasError = state.errorMessage != null;
    final totalCount = files.length;
    final completedCount = state.completedCount;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    final expression = isComplete
        ? PotoExpression.happy
        : hasError
            ? PotoExpression.error
            : PotoExpression.working;

    final statusTitle = isComplete
        ? 'All $totalCount original${totalCount == 1 ? '' : 's'} are safe.'
        : hasError
            ? 'Upload stopped.'
            : '$completedCount of $totalCount secured so far.';

    final statusSub = isComplete
        ? 'Poto kept every file exactly as you took it.'
        : hasError
            ? state.errorMessage ?? 'Something went wrong. Tap Try Again.'
            : 'Keep this screen open while uploading.';

    return PopScope(
      canPop: !isUploading,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.warmCream,
          body: Column(
            children: [
              // ── Header ───────────────────────────────────────────────
              _Header(
                albumName: album.name,
                canClose: !isUploading,
                onClose: isUploading
                    ? null
                    : () => Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.albumDetails,
                          ModalRoute.withName(AppRoutes.home),
                          arguments: album,
                        ),
              ),

              // ── Scrollable body ──────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                      AppSpacing.xl, AppSpacing.md, AppSpacing.lg),
                  child: Column(
                    children: [
                      // Poto — the hero
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        switchInCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child:
                              ScaleTransition(scale: animation, child: child),
                        ),
                        child: PotoMascot(
                          key: ValueKey(expression),
                          expression: expression,
                          size: 120,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // Status text
                      Text(
                        statusTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: AppTheme.headingFont,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepMaroon,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        statusSub,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: hasError
                              ? AppColors.velvetMaroon
                              : AppColors.featherTaupe,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // Overall progress bar
                      _OverallProgress(
                        value: state.progress,
                        completed: completedCount,
                        total: totalCount,
                        isComplete: isComplete,
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      // Per-file rows
                      Column(
                        children: [
                          for (var i = 0; i < files.length; i++)
                            Padding(
                              padding:
                                  const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: _FileRow(
                                file: files[i],
                                progress: _progressFor(i, state),
                                status: _statusFor(i, state),
                                isDone: i < completedCount,
                                isActive:
                                    i == state.currentFileIndex && isUploading,
                                isWaiting: i > state.currentFileIndex ||
                                    (state.currentFileIndex < 0 && !isComplete),
                                isFailed:
                                    i == state.currentFileIndex && hasError,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Bottom CTA ───────────────────────────────────────────
              if (!isUploading)
                _BottomCTA(
                  isError: hasError,
                  isBusy: _retrying,
                  bottomPad: bottomPad,
                  onAction: hasError
                      ? _retryFailed
                      : () => Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoutes.albumDetails,
                            ModalRoute.withName(AppRoutes.home),
                            arguments: album,
                          ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _retryFailed() async {
    if (_retrying) return;

    setState(() => _retrying = true);
    try {
      await ref.read(uploadControllerProvider.notifier).retryFailed();
    } finally {
      if (mounted) {
        setState(() => _retrying = false);
      }
    }
  }

  double _progressFor(int i, UploadState state) {
    if (i < state.completedCount) return 1.0;
    if (i == state.currentFileIndex &&
        (state.isUploading || state.errorMessage != null)) {
      final share = 1.0 / state.totalCount;
      final base = i / state.totalCount;
      final current = (state.progress - base).clamp(0.0, share);
      return (current / share).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  String _statusFor(int i, UploadState state) {
    if (i < state.completedCount) return 'Done';
    if (i == state.currentFileIndex && state.isUploading) {
      return '${(_progressFor(i, state) * 100).round()}%';
    }
    if (i == state.currentFileIndex && state.errorMessage != null) {
      return 'Failed';
    }
    return 'Queued';
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.albumName,
    required this.canClose,
    required this.onClose,
  });

  final String albumName;
  final bool canClose;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.header,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, top + 12, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PressableScale(
            onTap: canClose ? onClose : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    AppColors.white.withValues(alpha: canClose ? 0.14 : 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.close,
                color: AppColors.white.withValues(alpha: canClose ? 1.0 : 0.3),
                size: 17,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Uploading',
                  style: TextStyle(
                    fontFamily: AppTheme.headingFont,
                    color: AppColors.pearlCream,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  albumName,
                  style: TextStyle(
                    color: AppColors.warmCream.withValues(alpha: 0.55),
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Overall progress ──────────────────────────────────────────────────────────

class _OverallProgress extends StatelessWidget {
  const _OverallProgress({
    required this.value,
    required this.completed,
    required this.total,
    required this.isComplete,
  });

  final double value;
  final int completed;
  final int total;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              isComplete ? 'Complete' : 'Overall progress',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.featherTaupe,
              ),
            ),
            const Spacer(),
            Text(
              '${(value * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color:
                    isComplete ? AppColors.brightGold : AppColors.velvetMaroon,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
          builder: (context, v, _) {
            return Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.creamLine,
                borderRadius: BorderRadius.circular(999),
              ),
              child: FractionallySizedBox(
                widthFactor: v.clamp(0.0, 1.0),
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isComplete
                          ? [
                              AppColors.velvetMaroon,
                              AppColors.brightGold,
                            ]
                          : [
                              AppColors.velvetMaroon,
                              AppColors.garnetHighlight,
                            ],
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ── File row ──────────────────────────────────────────────────────────────────

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.progress,
    required this.status,
    required this.isDone,
    required this.isActive,
    required this.isWaiting,
    required this.isFailed,
  });

  final UploadFile file;
  final double progress;
  final String status;
  final bool isDone;
  final bool isActive;
  final bool isWaiting;
  final bool isFailed;

  @override
  Widget build(BuildContext context) {
    final isVideo = file.fileType == 'video';

    final Color iconBg;
    final Color iconColor;
    final Color barColor;
    final Color statusColor;

    if (isDone) {
      iconBg = AppColors.brightGold.withValues(alpha: 0.12);
      iconColor = AppColors.brightGold;
      barColor = AppColors.brightGold;
      statusColor = const Color(0xFF4A8C2A);
    } else if (isFailed) {
      iconBg = AppColors.velvetMaroon.withValues(alpha: 0.10);
      iconColor = AppColors.velvetMaroon;
      barColor = AppColors.velvetMaroon;
      statusColor = AppColors.velvetMaroon;
    } else if (isWaiting) {
      iconBg = AppColors.creamLine;
      iconColor = AppColors.featherTaupe;
      barColor = AppColors.creamLine;
      statusColor = AppColors.featherTaupe;
    } else {
      iconBg = AppColors.maroonFaint;
      iconColor = AppColors.velvetMaroon;
      barColor = AppColors.velvetMaroon;
      statusColor = AppColors.velvetMaroon;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          color: isDone
              ? AppColors.brightGold.withValues(alpha: 0.20)
              : AppColors.creamLine,
          width: 0.8,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(
              isDone
                  ? Icons.check
                  : isVideo
                      ? Icons.movie_outlined
                      : Icons.image_outlined,
              color: iconColor,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),

          // Name + progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isWaiting
                        ? AppColors.featherTaupe
                        : AppColors.charcoalInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  file.sizeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: isWaiting
                        ? AppColors.featherTaupe.withValues(alpha: 0.6)
                        : AppColors.featherTaupe,
                  ),
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOut,
                  builder: (context, v, _) {
                    return Container(
                      height: 4,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.creamLine,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: v.clamp(0.0, 1.0),
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isDone
                  ? AppColors.brightGold.withValues(alpha: 0.10)
                  : isFailed
                      ? AppColors.maroonFaint
                      : isWaiting
                          ? AppColors.warmCream
                          : AppColors.maroonFaint,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom CTA ────────────────────────────────────────────────────────────────

class _BottomCTA extends StatelessWidget {
  const _BottomCTA({
    required this.isError,
    required this.isBusy,
    required this.bottomPad,
    required this.onAction,
  });

  final bool isError;
  final bool isBusy;
  final double bottomPad;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: const Border(
            top: BorderSide(color: AppColors.creamLine, width: 0.8)),
        boxShadow: [
          BoxShadow(
            color: AppColors.midnightBurgundy.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md,
          AppSpacing.sm + bottomPad),
      child: PressableScale(
        onTap: isBusy ? null : onAction,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          height: 54,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.velvetMaroon,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            boxShadow: AppShadows.primaryButton,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isBusy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.pearlCream),
                  ),
                )
              else
                Icon(
                  isError ? Icons.refresh : Icons.check_circle_outline,
                  color: AppColors.pearlCream,
                  size: 18,
                ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                isBusy
                    ? 'Retrying'
                    : isError
                        ? 'Try Again'
                        : 'Back to Album',
                style: const TextStyle(
                  color: AppColors.pearlCream,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
