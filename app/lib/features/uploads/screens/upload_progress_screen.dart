import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../core/widgets/app_screen.dart';
import '../../../core/widgets/poto_mascot.dart';
import '../models/upload_file.dart';
import '../providers/upload_provider.dart';
import '../widgets/upload_progress_card.dart';

class UploadProgressScreen extends ConsumerStatefulWidget {
  const UploadProgressScreen({super.key});

  @override
  ConsumerState<UploadProgressScreen> createState() =>
      _UploadProgressScreenState();
}

class _UploadProgressScreenState extends ConsumerState<UploadProgressScreen> {
  UploadProgressArgs? args;
  bool started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final routeArgs = ModalRoute.of(context)?.settings.arguments;
    if (routeArgs is UploadProgressArgs) {
      args = routeArgs;
      if (!started) {
        started = true;
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
    final uploadArgs = args;
    final uploadState = ref.watch(uploadControllerProvider);
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

    final totalCount = files.length;
    final completedCount = uploadState.completedCount;
    final currentIndex = uploadState.currentFileIndex;
    final isUploading = uploadState.isUploading;
    final isComplete = uploadState.isComplete;

    return Scaffold(
      body: AppScreen(
        padding: EdgeInsets.zero,
        children: [
          // ── Header ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            decoration: const BoxDecoration(
              color: AppColors.deepMaroon,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: isUploading ? null : () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close,
                            color: AppColors.white, size: 14),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Cancel',
                        style: TextStyle(
                            color: AppColors.white.withValues(alpha: 0.70),
                            fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Uploading to',
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(color: AppColors.warmCream),
                ),
                const SizedBox(height: 2),
                Text(
                  album.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: AppColors.goldLight),
                ),
              ],
            ),
          ),

          // ── File count + quality badge ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$totalCount file${totalCount == 1 ? '' : 's'} selected',
                    style: const TextStyle(
                        color: AppColors.mutedInk, fontSize: 12),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.goldFaint,
                    border: Border.all(
                        color: AppColors.softGold.withValues(alpha: 0.30),
                        width: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.star, color: AppColors.softGold, size: 10),
                      SizedBox(width: 4),
                      Text('Original quality',
                          style: TextStyle(
                              color: AppColors.softGold,
                              fontSize: 10,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Poto mascot (working / happy / error) ─────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Center(
              child: PotoMascot(
                expression: isComplete
                    ? PotoExpression.happy
                    : uploadState.errorMessage != null
                        ? PotoExpression.error
                        : PotoExpression.working,
                size: 80,
                caption: isComplete
                    ? 'Original quality confirmed.'
                    : uploadState.errorMessage != null
                        ? 'Poto could not complete the upload.'
                        : 'Poto is protecting your originals.',
              ),
            ),
          ),

          // ── Overall progress ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: AppProgressBar(value: uploadState.progress),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              isComplete
                  ? 'All $totalCount files uploaded'
                  : isUploading
                      ? '$completedCount of $totalCount uploaded'
                      : uploadState.errorMessage != null
                          ? 'Upload stopped — see error below'
                          : 'Preparing...',
              style: const TextStyle(
                  color: AppColors.mutedInk,
                  fontSize: 11,
                  fontWeight: FontWeight.w500),
            ),
          ),

          // ── Per-file progress cards ────────────────────────────────────
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (var i = 0; i < files.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: UploadProgressCard(
                      name: files[i].name,
                      size: files[i].sizeLabel,
                      progress: _progressFor(i, uploadState),
                      status: _statusFor(i, uploadState),
                      done: i < completedCount,
                      waiting: !isUploading && i > currentIndex ||
                          (currentIndex < 0 && !isComplete),
                    ),
                  ),
              ],
            ),
          ),

          // ── Error detail ───────────────────────────────────────────────
          if (uploadState.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                uploadState.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.velvetMaroon,
                    fontSize: 12,
                    fontWeight: FontWeight.w500),
              ),
            ),

          // ── Info hint ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.maroon, size: 14),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isUploading
                        ? uploadState.progress < 0.16
                            ? 'Creating upload session...'
                            : uploadState.progress >= 0.90
                                ? 'Finalizing upload...'
                                : 'Uploading original bytes. Keep this screen open.'
                        : 'Files are uploaded in original quality. No compression.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.maroon,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          // ── Action button ──────────────────────────────────────────────
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppButton(
              label: isUploading
                  ? 'Uploading...'
                  : uploadState.errorMessage == null
                      ? 'Back to Album'
                      : 'Try Again',
              icon: uploadState.errorMessage == null
                  ? Icons.check
                  : Icons.refresh,
              onPressed: isUploading
                  ? null
                  : uploadState.errorMessage == null
                      ? () => Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppRoutes.albumDetails,
                            ModalRoute.withName(AppRoutes.home),
                            arguments: album,
                          )
                      : () {
                          ref.read(uploadControllerProvider.notifier).upload(
                                albumId: album.id,
                                files: files,
                              );
                        },
            ),
          ),
        ],
      ),
    );
  }

  double _progressFor(int index, UploadState state) {
    if (index < state.completedCount) return 1.0;
    if (index == state.currentFileIndex && state.isUploading) {
      // interpolate current file's share of overall progress
      final fileShare = 1.0 / state.totalCount;
      final base = index / state.totalCount;
      final current = (state.progress - base).clamp(0.0, fileShare);
      return (current / fileShare).clamp(0.0, 1.0);
    }
    return 0.0;
  }

  String _statusFor(int index, UploadState state) {
    if (index < state.completedCount) return 'Done';
    if (index == state.currentFileIndex && state.isUploading) {
      return '${(_progressFor(index, state) * 100).round()}%';
    }
    if (index == state.currentFileIndex && state.errorMessage != null) {
      return 'Failed';
    }
    return 'Queued';
  }
}
