import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../core/widgets/app_screen.dart';
import '../../../core/widgets/save_all_ring.dart';
import '../../albums/models/album.dart';
import '../../albums/models/media_file.dart';
import '../../albums/providers/album_provider.dart';
import '../data/download_repository.dart';

class SaveAllArgs {
  const SaveAllArgs({
    required this.album,
    required this.files,
  });

  final Album album;
  final List<MediaFile> files;
}

class SaveAllScreen extends ConsumerStatefulWidget {
  const SaveAllScreen({super.key});

  @override
  ConsumerState<SaveAllScreen> createState() => _SaveAllScreenState();
}

class _SaveAllScreenState extends ConsumerState<SaveAllScreen> {
  bool isSaving = false;
  bool isComplete = false;
  int activeIndex = -1;
  int savedCount = 0;
  double progress = 0;
  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final saveArgs = args is SaveAllArgs ? args : null;
    final album = saveArgs?.album;
    final files = saveArgs?.files ?? const <MediaFile>[];

    if (album == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Save All')),
        body: const AppScreen(
          children: [
            AppEmptyState(
              title: 'Album unavailable',
              message: 'Open Save All from an album first.',
            ),
          ],
        ),
      );
    }

    final filesAsync = ref.watch(albumMediaFilesProvider(album.id));
    final resolvedFiles = filesAsync.asData?.value ?? files;
    final isLoadingFiles = filesAsync.isLoading && resolvedFiles.isEmpty;
    final totalFiles = resolvedFiles.length;
    final headline = isComplete
        ? 'All originals saved'
        : isSaving
            ? 'Saving your memories'
            : 'Ready to save originals';
    final subhead =
        totalFiles == 1 ? '1 original file' : '$totalFiles original files';

    return Scaffold(
      body: AppScreen(
        padding: EdgeInsets.zero,
        children: [
          _SaveHeader(
            album: album,
            fileCount: totalFiles,
            canCancel: !isSaving,
            onCancel: () => Navigator.pop(context),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  SaveAllRing(progress: progress),
                  const SizedBox(height: 12),
                  Text(
                    headline,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$savedCount of $totalFiles files saved',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.mutedInk, fontSize: 12),
                  ),
                  const SizedBox(height: 18),
                  AppProgressBar(value: progress),
                  const SizedBox(height: 16),
                  if (isLoadingFiles)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child:
                          CircularProgressIndicator(color: AppColors.softGold),
                    )
                  else if (filesAsync.hasError && resolvedFiles.isEmpty)
                    AppEmptyState(
                      title: 'Files unavailable',
                      message: filesAsync.error.toString(),
                      actionLabel: 'Try Again',
                      onAction: () =>
                          ref.invalidate(albumMediaFilesProvider(album.id)),
                    )
                  else if (resolvedFiles.isEmpty)
                    const AppEmptyState(
                      title: 'No completed files',
                      message:
                          'Upload completed originals before using Save All.',
                    )
                  else
                    for (var index = 0;
                        index < resolvedFiles.length;
                        index++) ...[
                      _SaveFileRow(
                        file: resolvedFiles[index],
                        status: _statusFor(index),
                        state: _rowStateFor(index),
                      ),
                      if (index < resolvedFiles.length - 1)
                        const SizedBox(height: 10),
                    ],
                  if (filesAsync.hasError && resolvedFiles.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Showing files already loaded from the album screen.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.mutedInk, fontSize: 12),
                    ),
                  ],
                  if (errorMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.maroon,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  AppButton(
                    label: isSaving
                        ? 'Saving...'
                        : isComplete
                            ? 'Save Again'
                            : 'Save All Originals',
                    icon: isComplete ? Icons.refresh : Icons.download,
                    onPressed: isSaving || resolvedFiles.isEmpty
                        ? null
                        : () => _saveAll(resolvedFiles),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              '$subhead will download through LitratoLink original storage.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedInk, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAll(List<MediaFile> files) async {
    setState(() {
      isSaving = true;
      isComplete = false;
      activeIndex = 0;
      savedCount = 0;
      progress = 0;
      errorMessage = null;
    });

    try {
      final repository = ref.read(downloadRepositoryProvider);
      for (var index = 0; index < files.length; index++) {
        if (!mounted) return;

        setState(() => activeIndex = index);
        await repository.downloadOriginal(
          file: files[index],
          onProgress: (fileProgress) {
            if (!mounted) return;
            final totalProgress =
                (index + fileProgress.clamp(0, 1)) / files.length;
            setState(() => progress = totalProgress);
          },
        );

        if (!mounted) return;
        setState(() {
          savedCount = index + 1;
          progress = savedCount / files.length;
        });
      }

      if (!mounted) return;
      setState(() {
        isSaving = false;
        isComplete = true;
        activeIndex = files.length;
        progress = 1;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        isSaving = false;
        isComplete = false;
        errorMessage = error.toString();
      });
    }
  }

  String _statusFor(int index) {
    if (index < savedCount) return 'Saved';
    if (index == activeIndex && isSaving) return 'Saving...';
    return 'Queued';
  }

  _SaveFileState _rowStateFor(int index) {
    if (index < savedCount) return _SaveFileState.done;
    if (index == activeIndex && isSaving) return _SaveFileState.active;
    return _SaveFileState.waiting;
  }
}

class _SaveHeader extends StatelessWidget {
  const _SaveHeader({
    required this.album,
    required this.fileCount,
    required this.canCancel,
    required this.onCancel,
  });

  final Album album;
  final int fileCount;
  final bool canCancel;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.deepMaroon,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: canCancel ? onCancel : null,
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
                  child:
                      const Icon(Icons.close, color: AppColors.white, size: 14),
                ),
                const SizedBox(width: 8),
                Text(
                  'Cancel',
                  style: TextStyle(
                      color: AppColors.white.withValues(alpha: 0.70),
                      fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Save All',
            style: Theme.of(context)
                .textTheme
                .headlineLarge
                ?.copyWith(color: AppColors.warmCream),
          ),
          const SizedBox(height: 5),
          Text(
            '${album.name} - $fileCount files',
            style: TextStyle(
                color: AppColors.warmCream.withValues(alpha: 0.60),
                fontSize: 11),
          ),
        ],
      ),
    );
  }
}

enum _SaveFileState { waiting, active, done }

class _SaveFileRow extends StatelessWidget {
  const _SaveFileRow({
    required this.file,
    required this.status,
    required this.state,
  });

  final MediaFile file;
  final String status;
  final _SaveFileState state;

  @override
  Widget build(BuildContext context) {
    final icon = switch (state) {
      _SaveFileState.done => Icons.check_circle,
      _SaveFileState.active => Icons.download,
      _SaveFileState.waiting => Icons.schedule,
    };
    final color = switch (state) {
      _SaveFileState.done => const Color(0xFF3B6D11),
      _SaveFileState.active => AppColors.maroon,
      _SaveFileState.waiting => AppColors.mutedInk,
    };

    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                file.originalFilename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                '${file.fileSizeLabel} - ${file.mimeType}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.mutedInk, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          status,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
