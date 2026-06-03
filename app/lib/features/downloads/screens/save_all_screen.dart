import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/utils/quality_test_log.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../core/widgets/app_screen.dart';
import '../../../core/widgets/poto_mascot.dart';
import '../../../core/widgets/save_all_ring.dart';
import '../../albums/models/album.dart';
import '../../albums/models/media_file.dart';
import '../../albums/providers/album_provider.dart';
import '../data/download_repository.dart';
import '../models/downloaded_file.dart';

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
              expression: PotoExpression.error,
            ),
          ],
        ),
      );
    }

    final filesAsync = ref.watch(albumMediaFilesProvider(album.id));
    final membersAsync = ref.watch(albumMembersProvider(album.id));
    final loadedMembers = membersAsync.asData?.value;
    final accessUnavailable = membersAsync.hasError ||
        (loadedMembers != null && loadedMembers.isEmpty);
    if (accessUnavailable) {
      return Scaffold(
        appBar: AppBar(title: const Text('Save All')),
        body: AppScreen(
          children: [
            AppEmptyState(
              title: 'Album access unavailable',
              message:
                  'You may have been removed from this album, or your access changed. Open Albums to refresh your private spaces.',
              expression: PotoExpression.error,
              actionLabel: 'Back to Albums',
              onAction: () =>
                  Navigator.pushReplacementNamed(context, AppRoutes.home),
            ),
          ],
        ),
      );
    }

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
                      message: AppError.messageFor(filesAsync.error),
                      expression: PotoExpression.error,
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
                        : () => _saveAll(album, resolvedFiles),
                  ),
                ],
              ),
            ),
          ),
          if (isSaving || isComplete)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Center(
                child: PotoMascot(
                  expression:
                      isComplete ? PotoExpression.happy : PotoExpression.working,
                  size: 80,
                  caption: isComplete
                      ? 'Poto packed your originals.'
                      : 'Poto is packing your originals.',
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              '$subhead will download through Potoos original storage.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedInk, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAll(Album album, List<MediaFile> files) async {
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
      final archive = Archive();
      final usedNames = <String>{};
      final savedOriginals = <OriginalDownload>[];

      for (var index = 0; index < files.length; index++) {
        if (!mounted) return;

        setState(() => activeIndex = index);
        final original = await repository.downloadOriginalBytes(
          file: files[index],
          onProgress: (fileProgress) {
            if (!mounted) return;
            final totalProgress =
                (index + (fileProgress.clamp(0, 1) * 0.9)) / files.length;
            setState(() => progress = totalProgress);
          },
        );
        savedOriginals.add(original);
        final zipFilename = uniqueZipFilename(original.filename, usedNames);
        archive.addFile(ArchiveFile.bytes(zipFilename, original.bytes));

        if (!mounted) return;
        setState(() {
          savedCount = index + 1;
          progress = (savedCount / files.length) * 0.9;
        });
      }

      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
      final zipName = '${safeZipName(album.name)}-originals.zip';
      final savedPath = await FilePicker.saveFile(
        dialogTitle: 'Save all original files',
        fileName: zipName,
        bytes: zipBytes,
      );

      if (savedPath == null && !kIsWeb) {
        throw const AppError('Save All was cancelled.');
      }

      for (final original in savedOriginals) {
        QualityTestLog.downloadedFile(
          filename: original.filename,
          downloadedSizeBytes: original.sizeBytes,
          expectedSizeBytes: original.expectedSizeBytes,
          mimeType: original.mimeType,
          savedPath: savedPath ?? 'Browser downloads: $zipName',
          checksumHex: QualityTestLog.sha256Hex(original.bytes),
        );
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
        errorMessage = AppError.messageFor(error);
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

/// Produces a safe, readable ZIP filename stem from an album name.
///
/// - Replaces OS-unsafe chars with `_`, whitespace with `-`, lowercases.
/// - Collapses runs of `-` and `_` to a single `-` and strips leading/trailing
///   dashes so the result is always tidy (e.g. `"My!!!Album"` → `my-album`).
/// - Caps at 50 characters to stay well within browser/OS filename limits
///   before the `-originals.zip` suffix is appended.
@visibleForTesting
String safeZipName(String albumName) {
  final rawName = albumName.trim();
  if (rawName.isEmpty) return 'potoos-album';

  var safe = rawName
      .replaceAll(RegExp(r'[^\w\s-]'), '_') // replace any non-alphanumeric/space/dash
      .replaceAll(RegExp(r'\s+'), '-')
      .toLowerCase()
      .replaceAll(RegExp(r'[-_]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  if (safe.isEmpty) return 'potoos-album';
  if (safe.length > 50) {
    safe = safe.substring(0, 50).replaceAll(RegExp(r'-+$'), '');
  }
  return safe.isEmpty ? 'potoos-album' : safe;
}

/// Returns a deduplicated, OS-safe filename for an entry inside the ZIP.
///
/// Strips leading hyphens, underscores, spaces, and dots (e.g. `"-cover.jpg"`
/// → `cover.jpg`). When the same base name appears more than once it appends
/// a counter: `photo.jpg`, `photo (2).jpg`, `photo (3).jpg`, …
@visibleForTesting
String uniqueZipFilename(String filename, Set<String> usedNames) {
  final safeName = filename
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .replaceAll(RegExp(r'^[-_\s.]+'), '');
  final baseName = safeName.isEmpty ? 'original-file' : safeName;
  if (usedNames.add(baseName)) return baseName;

  final dotIndex = baseName.lastIndexOf('.');
  final name = dotIndex <= 0 ? baseName : baseName.substring(0, dotIndex);
  final extension = dotIndex <= 0 ? '' : baseName.substring(dotIndex);

  var counter = 2;
  while (true) {
    final candidate = '$name ($counter)$extension';
    if (usedNames.add(candidate)) return candidate;
    counter++;
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
