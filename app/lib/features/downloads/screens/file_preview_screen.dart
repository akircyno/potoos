import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../core/widgets/app_screen.dart';
import '../../albums/models/media_file.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('File Preview')),
      body: AppScreen(
        children: [
          Container(
            height: 320,
            decoration: BoxDecoration(
              color: AppColors.creamLine,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child:
                  Icon(Icons.image_outlined, color: AppColors.maroon, size: 70),
            ),
          ),
          const SizedBox(height: 18),
          Text(file.originalFilename,
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            '${file.fileType} - ${file.fileSizeLabel} - ${file.mimeType}',
            style: const TextStyle(color: AppColors.mutedInk),
          ),
          const SizedBox(height: 4),
          Text(
            'Uploaded by ${file.uploaderName} - ${file.uploadedLabel}',
            style: const TextStyle(color: AppColors.mutedInk),
          ),
          const SizedBox(height: 20),
          AppCard(
            child: AppProgressBar(
              value: downloadState.progress,
              label: downloadState.isDownloading
                  ? 'Downloading original'
                  : downloadState.downloadedFile != null
                      ? 'Download complete'
                      : 'Download progress',
            ),
          ),
          if (downloadState.errorMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              downloadState.errorMessage!,
              style: const TextStyle(
                  color: AppColors.maroon, fontWeight: FontWeight.w700),
            ),
          ],
          if (downloadState.downloadedFile != null) ...[
            const SizedBox(height: 10),
            _QualityCheck(file: downloadState.downloadedFile!),
          ],
          const SizedBox(height: 18),
          DownloadButton(
            isDownloading: downloadState.isDownloading,
            onPressed: () =>
                ref.read(downloadControllerProvider.notifier).download(file),
          ),
          const SizedBox(height: 10),
          const Text(
            'Download must use the original file, never a thumbnail.',
            style:
                TextStyle(color: AppColors.maroon, fontWeight: FontWeight.w700),
          ),
        ],
      ),
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
    final title = matches ? 'Original size verified' : 'Size mismatch';
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
          Text(
            sizeLine,
            style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
          ),
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
