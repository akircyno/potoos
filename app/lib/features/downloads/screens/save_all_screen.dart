import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/utils/quality_test_log.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_screen.dart';
import '../../../core/widgets/poto_mascot.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../albums/models/album.dart';
import '../../albums/models/media_file.dart';
import '../../albums/providers/album_provider.dart';
import '../data/download_repository.dart';
import '../models/downloaded_file.dart';

class SaveAllArgs {
  const SaveAllArgs({required this.album, required this.files});

  final Album album;
  final List<MediaFile> files;
}

class SaveAllScreen extends ConsumerStatefulWidget {
  const SaveAllScreen({super.key});

  @override
  ConsumerState<SaveAllScreen> createState() => _SaveAllScreenState();
}

class _SaveAllScreenState extends ConsumerState<SaveAllScreen> {
  bool _isSaving = false;
  bool _isComplete = false;
  int _activeIndex = -1;
  int _savedCount = 0;
  double _progress = 0;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    final saveArgs = args is SaveAllArgs ? args : null;
    final album = saveArgs?.album;
    final files = saveArgs?.files ?? const <MediaFile>[];

    if (album == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Save Originals')),
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
        appBar: AppBar(title: const Text('Save Originals')),
        body: AppScreen(
          children: [
            AppEmptyState(
              title: 'Album access unavailable',
              message:
                  'You may have been removed from this album. Go back to refresh your spaces.',
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
    final hasError = _errorMessage != null;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    final expression = _isComplete
        ? PotoExpression.happy
        : hasError
            ? PotoExpression.error
            : _isSaving
                ? PotoExpression.working
                : PotoExpression.saveAll;

    final statusTitle = _isComplete
        ? 'All $totalFiles original${totalFiles == 1 ? '' : 's'} are yours.'
        : hasError
            ? 'Download stopped.'
            : _isSaving
                ? '$_savedCount of $totalFiles packed so far.'
                : 'Ready to save $totalFiles original${totalFiles == 1 ? '' : 's'}.';

    final statusSub = _isComplete
        ? 'Poto packed everything into one ZIP for you.'
        : hasError
            ? _errorMessage!
            : _isSaving
                ? 'Keep this screen open while downloading.'
                : 'Your originals will be saved at full quality — no compression.';

    return PopScope(
      canPop: !_isSaving,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.warmCream,
          body: Column(
            children: [
              // ── Header ───────────────────────────────────────────────
              _Header(
                albumName: album.name,
                fileCount: totalFiles,
                canClose: !_isSaving,
                onClose: _isSaving
                    ? null
                    : () => Navigator.pop(context),
              ),

              // ── Scrollable body ──────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.xl, AppSpacing.md, AppSpacing.lg),
                  child: Column(
                    children: [
                      // Poto — the hero
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        switchInCurve: Curves.easeOutCubic,
                        transitionBuilder: (child, animation) =>
                            FadeTransition(
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

                      // Progress bar (saving or complete)
                      if (_isSaving || _isComplete) ...[
                        const SizedBox(height: AppSpacing.xl),
                        _OverallProgress(
                          value: _progress,
                          saved: _savedCount,
                          total: totalFiles,
                          isComplete: _isComplete,
                        ),
                      ],

                      const SizedBox(height: AppSpacing.lg),

                      // File list
                      if (isLoadingFiles)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(
                            color: AppColors.brightGold,
                            strokeWidth: 2,
                          ),
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
                          title: 'Nothing to save yet.',
                          message:
                              'Upload some originals first, then come back here.',
                        )
                      else
                        Column(
                          children: [
                            for (var i = 0; i < resolvedFiles.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(
                                    bottom: AppSpacing.sm),
                                child: _FileRow(
                                  file: resolvedFiles[i],
                                  status: _statusFor(i),
                                  rowState: _rowStateFor(i),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              // ── Sticky CTA ───────────────────────────────────────────
              _BottomCTA(
                isSaving: _isSaving,
                isComplete: _isComplete,
                hasError: hasError,
                isEmpty: resolvedFiles.isEmpty,
                bottomPad: bottomPad,
                onSave: (_isSaving || resolvedFiles.isEmpty)
                    ? null
                    : () => _saveAll(album, resolvedFiles),
                onBack: () => Navigator.pushNamedAndRemoveUntil(
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

  // ── Business logic (unchanged) ─────────────────────────────────────────────

  Future<void> _saveAll(Album album, List<MediaFile> files) async {
    setState(() {
      _isSaving = true;
      _isComplete = false;
      _activeIndex = 0;
      _savedCount = 0;
      _progress = 0;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(downloadRepositoryProvider);
      final archive = Archive();
      final usedNames = <String>{};
      final savedOriginals = <OriginalDownload>[];

      for (var index = 0; index < files.length; index++) {
        if (!mounted) return;

        setState(() => _activeIndex = index);
        final original = await repository.downloadOriginalBytes(
          file: files[index],
          onProgress: (fileProgress) {
            if (!mounted) return;
            final totalProgress =
                (index + (fileProgress.clamp(0, 1) * 0.9)) / files.length;
            setState(() => _progress = totalProgress);
          },
        );
        savedOriginals.add(original);
        final zipFilename = uniqueZipFilename(original.filename, usedNames);
        archive.addFile(ArchiveFile.bytes(zipFilename, original.bytes));

        if (!mounted) return;
        setState(() {
          _savedCount = index + 1;
          _progress = (_savedCount / files.length) * 0.9;
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
        _isSaving = false;
        _isComplete = true;
        _activeIndex = files.length;
        _progress = 1;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isComplete = false;
        _errorMessage = AppError.messageFor(error);
      });
    }
  }

  String _statusFor(int index) {
    if (index < _savedCount) return 'Saved';
    if (index == _activeIndex && _isSaving) return 'Saving...';
    return 'Queued';
  }

  _RowState _rowStateFor(int index) {
    if (index < _savedCount) return _RowState.done;
    if (index == _activeIndex && _isSaving) return _RowState.active;
    return _RowState.waiting;
  }
}

// ── Utility functions (unchanged — tested) ────────────────────────────────────

@visibleForTesting
String safeZipName(String albumName) {
  final rawName = albumName.trim();
  if (rawName.isEmpty) return 'potoos-album';

  var safe = rawName
      .replaceAll(RegExp(r'[^\w\s-]'), '_')
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

// ── Private widgets ───────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.albumName,
    required this.fileCount,
    required this.canClose,
    required this.onClose,
  });

  final String albumName;
  final int fileCount;
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
                color: AppColors.white
                    .withValues(alpha: canClose ? 0.14 : 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.close,
                color: AppColors.white
                    .withValues(alpha: canClose ? 1.0 : 0.3),
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
                  'Save Originals',
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

class _OverallProgress extends StatelessWidget {
  const _OverallProgress({
    required this.value,
    required this.saved,
    required this.total,
    required this.isComplete,
  });

  final double value;
  final int saved;
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
                color: isComplete
                    ? AppColors.brightGold
                    : AppColors.velvetMaroon,
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
                          ? [AppColors.velvetMaroon, AppColors.brightGold]
                          : [AppColors.velvetMaroon, AppColors.garnetHighlight],
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

enum _RowState { waiting, active, done }

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.status,
    required this.rowState,
  });

  final MediaFile file;
  final String status;
  final _RowState rowState;

  @override
  Widget build(BuildContext context) {
    final isDone = rowState == _RowState.done;
    final isActive = rowState == _RowState.active;
    final isWaiting = rowState == _RowState.waiting;

    final Color iconBg;
    final Color iconColor;
    final Color statusColor;

    if (isDone) {
      iconBg = AppColors.brightGold.withValues(alpha: 0.12);
      iconColor = AppColors.brightGold;
      statusColor = const Color(0xFF4A8C2A);
    } else if (isActive) {
      iconBg = AppColors.maroonFaint;
      iconColor = AppColors.velvetMaroon;
      statusColor = AppColors.velvetMaroon;
    } else {
      iconBg = AppColors.creamLine;
      iconColor = AppColors.featherTaupe;
      statusColor = AppColors.featherTaupe;
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
                  : isActive
                      ? Icons.download_outlined
                      : Icons.schedule_outlined,
              color: iconColor,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.originalFilename,
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
                  '${file.fileSizeLabel} · ${file.mimeType}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: isWaiting
                        ? AppColors.featherTaupe.withValues(alpha: 0.6)
                        : AppColors.featherTaupe,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: isDone
                  ? AppColors.brightGold.withValues(alpha: 0.10)
                  : isActive
                      ? AppColors.maroonFaint
                      : AppColors.warmCream,
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

class _BottomCTA extends StatelessWidget {
  const _BottomCTA({
    required this.isSaving,
    required this.isComplete,
    required this.hasError,
    required this.isEmpty,
    required this.bottomPad,
    required this.onSave,
    required this.onBack,
  });

  final bool isSaving;
  final bool isComplete;
  final bool hasError;
  final bool isEmpty;
  final double bottomPad;
  final VoidCallback? onSave;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border:
            const Border(top: BorderSide(color: AppColors.creamLine, width: 0.8)),
        boxShadow: [
          BoxShadow(
            color: AppColors.midnightBurgundy.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm + bottomPad),
      child: isComplete
          ? Row(
              children: [
                Expanded(
                  child: PressableScale(
                    onTap: onSave,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusLg),
                        border: Border.all(
                            color: AppColors.creamLine, width: 1.5),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh,
                              color: AppColors.charcoalInk, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Save Again',
                            style: TextStyle(
                              color: AppColors.charcoalInk,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: PressableScale(
                    onTap: onBack,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.velvetMaroon,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusLg),
                        boxShadow: AppShadows.primaryButton,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: AppColors.pearlCream, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Back to Album',
                            style: TextStyle(
                              color: AppColors.pearlCream,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : PressableScale(
              onTap: onSave,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: Container(
                height: 54,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: onSave != null
                      ? AppColors.velvetMaroon
                      : AppColors.creamLine,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  boxShadow:
                      onSave != null ? AppShadows.primaryButton : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSaving
                          ? Icons.hourglass_top_rounded
                          : hasError
                              ? Icons.refresh
                              : Icons.download_outlined,
                      color: onSave != null
                          ? AppColors.pearlCream
                          : AppColors.featherTaupe,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      isSaving
                          ? 'Packing originals...'
                          : hasError
                              ? 'Try Again'
                              : isEmpty
                                  ? 'Nothing to save'
                                  : 'Save All Originals',
                      style: TextStyle(
                        color: onSave != null
                            ? AppColors.pearlCream
                            : AppColors.featherTaupe,
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
