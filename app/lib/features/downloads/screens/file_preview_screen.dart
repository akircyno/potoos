import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../core/widgets/app_screen.dart';
import '../../albums/models/media_file.dart';
import '../../albums/widgets/gallery_tile.dart';
import '../models/downloaded_file.dart';
import '../providers/download_provider.dart';
import '../widgets/download_button.dart';

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
              message: 'Open a completed file from an album first.',
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

    const palettes = [
      [Color(0xFFD4A0AC), Color(0xFF8C2840)],
      [Color(0xFFA0BCD4), Color(0xFF2C5880)],
      [Color(0xFFD4C4A0), Color(0xFF8C7A30)],
      [Color(0xFFA0D4B0), Color(0xFF2C8040)],
      [Color(0xFFC4A0D4), Color(0xFF6B2C80)],
    ];
    final gradient = palettes[file.id.hashCode.abs() % palettes.length];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: AppColors.deepMaroon,
        automaticallyImplyLeading: false,
      ),
      body: AppScreen(
        padding: EdgeInsets.zero,
        children: [
          // ── Maroon header ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: const BoxDecoration(
              color: AppColors.deepMaroon,
              borderRadius:
                  BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.chevron_left,
                            color: AppColors.white, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Album',
                        style: TextStyle(
                            color: AppColors.white.withValues(alpha: 0.70),
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  file.originalFilename,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(color: AppColors.warmCream),
                ),
                const SizedBox(height: 4),
                Text(
                  '${file.fileType} · ${file.fileSizeLabel} · ${file.uploadedLabel}',
                  style: TextStyle(
                      color: AppColors.warmCream.withValues(alpha: 0.60),
                      fontSize: 11),
                ),
              ],
            ),
          ),

          // ── Preview area ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 200,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradient,
                        ),
                      ),
                    ),
                    Center(
                      child: Icon(
                        fileTypeIcon(file),
                        color: AppColors.white.withValues(alpha: 0.45),
                        size: 64,
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: file.isVideo
                              ? Colors.black.withValues(alpha: 0.55)
                              : AppColors.maroon.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
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
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.softGold.withValues(alpha: 0.90),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Original Quality',
                          style: TextStyle(
                            color: AppColors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 10,
                      child: Text(
                        'Uploaded by ${file.uploaderName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          shadows: [
                            Shadow(color: Colors.black45, blurRadius: 6)
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Metadata card ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _MetaRow(
                      icon: Icons.insert_drive_file_outlined,
                      label: 'File',
                      value: file.mimeType),
                  const SizedBox(height: 8),
                  _MetaRow(
                      icon: Icons.storage_outlined,
                      label: 'Size',
                      value: file.fileSizeLabel),
                  const SizedBox(height: 8),
                  _MetaRow(
                      icon: Icons.person_outline,
                      label: 'Uploader',
                      value: file.uploaderName),
                  const SizedBox(height: 8),
                  _MetaRow(
                      icon: Icons.schedule_outlined,
                      label: 'Uploaded',
                      value: file.uploadedLabel),
                ],
              ),
            ),
          ),

          // ── Download section ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AppCard(
              child: AppProgressBar(
                value: downloadState.progress,
                label: downloadState.isDownloading
                    ? 'Downloading original...'
                    : downloadState.downloadedFile != null
                        ? 'Download complete'
                        : 'Download progress',
              ),
            ),
          ),
          if (downloadState.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Text(
                downloadState.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.maroon, fontWeight: FontWeight.w700),
              ),
            ),
          if (downloadState.downloadedFile != null) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _QualityCheck(file: downloadState.downloadedFile!),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DownloadButton(
              isDownloading: downloadState.isDownloading,
              onPressed: () =>
                  ref.read(downloadControllerProvider.notifier).download(file),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_outlined,
                    color: AppColors.maroon, size: 13),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Original file — no compression, no resizing.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.maroon,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow(
      {required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.mutedInk),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.mutedInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _QualityCheck extends StatelessWidget {
  const _QualityCheck({required this.file});

  final DownloadedFile file;

  @override
  Widget build(BuildContext context) {
    final matches = file.sizeMatchesExpected;
    final color = matches ? const Color(0xFF3B6D11) : AppColors.maroon;
    final title = matches ? 'Original size verified' : 'Size mismatch detected';
    final sizeLine =
        '${_formatBytes(file.sizeBytes)} downloaded / ${_formatBytes(file.expectedSizeBytes)} expected';

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                matches ? Icons.verified_outlined : Icons.warning_amber,
                color: color,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(sizeLine,
              style:
                  const TextStyle(color: AppColors.mutedInk, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            'Saved to ${file.savedPath}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
          ),
        ],
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return 'Unknown size';
    final mb = bytes / (1024 * 1024);
    if (mb < 1) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${mb.toStringAsFixed(1)} MB';
  }
}
