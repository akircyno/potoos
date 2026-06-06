import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_screen.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../albums/models/media_file.dart';
import '../../albums/widgets/gallery_tile.dart';
import '../../albums/widgets/media_preview_image.dart';
import '../../albums/widgets/media_video_preview.dart';
import '../models/downloaded_file.dart';
import '../providers/download_provider.dart';

class FilePreviewScreen extends ConsumerWidget {
  const FilePreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeFile = ModalRoute.of(context)?.settings.arguments;
    if (routeFile is! MediaFile) {
      return Scaffold(
        appBar: AppBar(title: const Text('File Preview')),
        body: AppScreen(
          children: [
            AppEmptyState(
              title: 'File unavailable',
              message: 'Open a file from an album first.',
              actionLabel: 'Back to Albums',
              onAction: () =>
                  Navigator.pushReplacementNamed(context, AppRoutes.home),
            ),
          ],
        ),
      );
    }

    final file = routeFile;
    final downloadState = ref.watch(downloadControllerProvider);
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final screenH = MediaQuery.of(context).size.height;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.midnightBurgundy,
        body: Stack(
          children: [
            // ── Content ─────────────────────────────────────────────────
            Column(
              children: [
                // Preview hero
                _PreviewHero(
                  file: file,
                  heroHeight: (screenH * 0.50).clamp(260, 420),
                  topPad: topPad,
                ),

                // Info panel — warmCream, rounded top corners
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.warmCream,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(28)),
                    ),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.md,
                        // clear the sticky download bar
                        80 + bottomPad + AppSpacing.md,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Filename
                          Text(
                            file.originalFilename,
                            style: const TextStyle(
                              fontFamily: AppTheme.headingFont,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.deepMaroon,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${file.fileType.toUpperCase()} · ${file.fileSizeLabel} · ${file.uploadedLabel}',
                            style: const TextStyle(
                              color: AppColors.featherTaupe,
                              fontSize: 13,
                            ),
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // Meta rows
                          _MetaSection(file: file),

                          // Quality check (after download)
                          if (downloadState.downloadedFile != null) ...[
                            const SizedBox(height: AppSpacing.md),
                            _QualityResult(file: downloadState.downloadedFile!),
                          ],

                          // Error message
                          if (downloadState.errorMessage != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.maroonFaint,
                                borderRadius:
                                    BorderRadius.circular(AppSpacing.radiusMd),
                                border: Border.all(
                                    color: AppColors.velvetMaroon
                                        .withValues(alpha: 0.20)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline,
                                      color: AppColors.velvetMaroon, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      downloadState.errorMessage!,
                                      style: const TextStyle(
                                        color: AppColors.velvetMaroon,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // ── Floating back button ─────────────────────────────────────
            Positioned(
              top: topPad + 12,
              left: 16,
              child: PressableScale(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.white.withValues(alpha: 0.15),
                        width: 0.8),
                  ),
                  child: const Icon(Icons.chevron_left,
                      color: AppColors.white, size: 20),
                ),
              ),
            ),

            // ── Sticky download bar ───────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _DownloadBar(
                state: downloadState,
                bottomPad: bottomPad,
                onDownload: () => ref
                    .read(downloadControllerProvider.notifier)
                    .download(file),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Preview hero ──────────────────────────────────────────────────────────────

class _PreviewHero extends StatelessWidget {
  const _PreviewHero({
    required this.file,
    required this.heroHeight,
    required this.topPad,
  });

  final MediaFile file;
  final double heroHeight;
  final double topPad;

  static const _palettes = [
    [Color(0xFFD4A0AC), Color(0xFF8C2840)],
    [Color(0xFFA0BCD4), Color(0xFF2C5880)],
    [Color(0xFFD4C4A0), Color(0xFF8C7A30)],
    [Color(0xFFA0D4B0), Color(0xFF2C8040)],
    [Color(0xFFC4A0D4), Color(0xFF6B2C80)],
  ];

  @override
  Widget build(BuildContext context) {
    final gradient = _palettes[file.id.hashCode.abs() % _palettes.length];

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: file.isVideo
                ? MediaVideoPreview(
                    mediaFileId: file.id,
                    fallback: _PreviewFallback(file: file, gradient: gradient),
                  )
                : MediaPreviewImage(
                    mediaFileId: file.id,
                    thumbnailUrl: file.thumbnailUrl,
                    fallback: _PreviewFallback(file: file, gradient: gradient),
                  ),
          ),
          const Positioned.fill(child: _PreviewScrim()),

          // Format badge — top-left (below back button)
          Positioned(
            top: topPad + 56,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: file.isVideo
                    ? Colors.black.withValues(alpha: 0.55)
                    : AppColors.velvetMaroon.withValues(alpha: 0.80),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (file.isVideo) ...[
                    const Icon(Icons.play_arrow,
                        size: 10, color: AppColors.white),
                    const SizedBox(width: 3),
                  ],
                  Text(
                    fileFormatLabel(file),
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Full-quality badge — top-right
          Positioned(
            top: topPad + 56,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.brightGold.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_outlined,
                      size: 10, color: AppColors.deepMaroon),
                  SizedBox(width: 4),
                  Text(
                    'Full quality',
                    style: TextStyle(
                      color: AppColors.deepMaroon,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom scrim + uploader name
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.50),
                  ],
                ),
              ),
              child: Text(
                'by ${file.uploaderName}',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Meta section ──────────────────────────────────────────────────────────────

class _PreviewFallback extends StatelessWidget {
  const _PreviewFallback({
    required this.file,
    required this.gradient,
  });

  final MediaFile file;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.06,
            child: GridPaper(
              color: AppColors.white,
              divisions: 1,
              interval: 20,
              subdivisions: 1,
            ),
          ),
          Center(
            child: Icon(
              fileTypeIcon(file),
              color: AppColors.white.withValues(alpha: 0.55),
              size: 72,
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewScrim extends StatelessWidget {
  const _PreviewScrim();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.08),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.28),
          ],
        ),
      ),
    );
  }
}

class _MetaSection extends StatelessWidget {
  const _MetaSection({required this.file});

  final MediaFile file;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
            color: AppColors.velvetMaroon.withValues(alpha: 0.08), width: 0.8),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          _MetaRow(
            icon: Icons.insert_drive_file_outlined,
            label: 'Format',
            value: file.mimeType,
            isFirst: true,
          ),
          _Divider(),
          _MetaRow(
            icon: Icons.storage_outlined,
            label: 'Size',
            value: file.fileSizeLabel,
          ),
          _Divider(),
          _MetaRow(
            icon: Icons.person_outline,
            label: 'Uploader',
            value: file.uploaderName,
          ),
          _Divider(),
          _MetaRow(
            icon: Icons.schedule_outlined,
            label: 'Uploaded',
            value: file.uploadedLabel,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        isFirst ? 14 : 10,
        AppSpacing.md,
        isLast ? 14 : 10,
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: AppColors.featherTaupe),
          const SizedBox(width: 10),
          SizedBox(
            width: 68,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.featherTaupe,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.charcoalInk,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 0.6,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      color: AppColors.creamLine,
    );
  }
}

// ── Quality result ────────────────────────────────────────────────────────────

class _QualityResult extends StatelessWidget {
  const _QualityResult({required this.file});

  final DownloadedFile file;

  static String _fmt(int bytes) {
    if (bytes <= 0) return '?';
    final mb = bytes / (1024 * 1024);
    return mb < 1
        ? '${(bytes / 1024).toStringAsFixed(1)} KB'
        : '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final ok = file.sizeMatchesExpected;
    final iconColor = ok ? const Color(0xFF4A8C2A) : AppColors.velvetMaroon;
    final bgColor = ok
        ? AppColors.brightGold.withValues(alpha: 0.08)
        : AppColors.maroonFaint;
    final borderColor = ok
        ? AppColors.brightGold.withValues(alpha: 0.22)
        : AppColors.velvetMaroon.withValues(alpha: 0.18);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.verified_outlined : Icons.warning_amber_outlined,
                color: iconColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                ok ? 'File size verified.' : 'Size mismatch detected.',
                style: TextStyle(
                  color: iconColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${_fmt(file.sizeBytes)} downloaded · ${_fmt(file.expectedSizeBytes)} expected',
            style: const TextStyle(
              color: AppColors.featherTaupe,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            file.savedPath,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.featherTaupe,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Download bar ──────────────────────────────────────────────────────────────

class _DownloadBar extends StatelessWidget {
  const _DownloadBar({
    required this.state,
    required this.bottomPad,
    required this.onDownload,
  });

  final DownloadState state;
  final double bottomPad;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final isDownloading = state.isDownloading;
    final isDone = state.downloadedFile != null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: const Border(
            top: BorderSide(color: AppColors.creamLine, width: 0.8)),
        boxShadow: [
          BoxShadow(
            color: AppColors.midnightBurgundy.withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md,
          AppSpacing.sm + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar (visible while downloading)
          if (isDownloading) ...[
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: state.progress),
              duration: const Duration(milliseconds: 300),
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
                        color: AppColors.brightGold,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Button
          PressableScale(
            onTap: (isDownloading || isDone) ? null : onDownload,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Container(
              height: 54,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDone
                    ? AppColors.warmCream
                    : isDownloading
                        ? AppColors.creamLine
                        : AppColors.brightGold,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border: isDone
                    ? Border.all(color: AppColors.creamLine, width: 1.5)
                    : null,
                boxShadow:
                    (!isDownloading && !isDone) ? AppShadows.goldButton : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isDone
                        ? Icons.check_circle_outline
                        : isDownloading
                            ? Icons.hourglass_top_rounded
                            : Icons.download_outlined,
                    color: isDone
                        ? AppColors.featherTaupe
                        : isDownloading
                            ? AppColors.featherTaupe
                            : AppColors.deepMaroon,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    isDone
                        ? 'Downloaded'
                        : isDownloading
                            ? 'Downloading file...'
                            : 'Download File',
                    style: TextStyle(
                      color: isDone
                          ? AppColors.featherTaupe
                          : isDownloading
                              ? AppColors.featherTaupe
                              : AppColors.deepMaroon,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Quality promise
          if (!isDone && !isDownloading) ...[
            const SizedBox(height: 6),
            const Text(
              'Full quality — nothing compressed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.featherTaupe,
                fontSize: 11,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
