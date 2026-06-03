import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/services/file_service.dart';
import '../../../core/widgets/poto_mascot.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../albums/models/album.dart';
import '../models/upload_file.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  List<UploadFile> _files = [];
  bool _picking = false;

  @override
  Widget build(BuildContext context) {
    final routeAlbum = ModalRoute.of(context)?.settings.arguments;
    final album = routeAlbum is Album ? routeAlbum : null;
    final canUpload = album?.canUpload ?? false;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.warmCream,
        body: Column(
          children: [
            _Header(
              albumName: album?.name,
              onClose: () => Navigator.pop(context),
            ),
            Expanded(
              child: album == null
                  ? _NoAlbumBody(
                      onBack: () =>
                          Navigator.pushReplacementNamed(context, AppRoutes.home),
                    )
                  : !canUpload
                      ? const _ViewerBody()
                      : _UploadBody(
                          files: _files,
                          isPicking: _picking,
                          onPick: _pickFiles,
                          onRemove: (i) =>
                              setState(() => _files.removeAt(i)),
                          onClear: () => setState(() => _files = []),
                        ),
            ),
            if (album != null && canUpload)
              _UploadCTA(
                count: _files.length,
                isPicking: _picking,
                bottomPad: bottomPad,
                onUpload: _files.isEmpty || _picking
                    ? null
                    : () => Navigator.pushNamed(
                          context,
                          AppRoutes.uploadProgress,
                          arguments: UploadProgressArgs(
                              album: album, files: _files),
                        ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    setState(() => _picking = true);
    try {
      final picked = await ref
          .read(fileServiceProvider)
          .pickOriginalMediaFiles(includeVideos: true);
      if (picked.isNotEmpty && mounted) {
        setState(() => _files = [..._files, ...picked]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppError.messageFor(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.albumName, required this.onClose});

  final String? albumName;
  final VoidCallback onClose;

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
            onTap: onClose,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close,
                  color: AppColors.white, size: 17),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Originals',
                  style: TextStyle(
                    fontFamily: AppTheme.headingFont,
                    color: AppColors.pearlCream,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                if (albumName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    albumName!,
                    style: TextStyle(
                      color: AppColors.warmCream.withValues(alpha: 0.55),
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Body variants ─────────────────────────────────────────────────────────────

class _NoAlbumBody extends StatelessWidget {
  const _NoAlbumBody({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PotoMascot(expression: PotoExpression.error, size: 88),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Open from an album first.',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Tap Upload from inside an album so your files go to the right space.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.featherTaupe, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: AppSpacing.lg),
            PressableScale(
              onTap: onBack,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              child: Container(
                height: 48,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.velvetMaroon,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  boxShadow: AppShadows.primaryButton,
                ),
                child: const Text(
                  'Back to Albums',
                  style: TextStyle(
                    color: AppColors.pearlCream,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerBody extends StatelessWidget {
  const _ViewerBody();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PotoMascot(expression: PotoExpression.waiting, size: 88),
            SizedBox(height: AppSpacing.md),
            Text(
              'Viewers can\'t upload.',
              style: TextStyle(
                fontFamily: AppTheme.headingFont,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.deepMaroon,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppSpacing.sm),
            Text(
              'Only Admins and Contributors can add files. Ask the album owner to upgrade your role.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.featherTaupe, fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadBody extends StatelessWidget {
  const _UploadBody({
    required this.files,
    required this.isPicking,
    required this.onPick,
    required this.onRemove,
    required this.onClear,
  });

  final List<UploadFile> files;
  final bool isPicking;
  final VoidCallback onPick;
  final ValueChanged<int> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: files.isEmpty
          ? _DropZone(onPick: onPick, isPicking: isPicking)
          : _FilesSection(
              files: files,
              isPicking: isPicking,
              onPick: onPick,
              onRemove: onRemove,
              onClear: onClear,
            ),
    );
  }
}

// ── Drop zone (empty state) ───────────────────────────────────────────────────

class _DropZone extends StatelessWidget {
  const _DropZone({required this.onPick, required this.isPicking});

  final VoidCallback onPick;
  final bool isPicking;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          vertical: 48, horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.warmCream,
        border: Border.all(color: AppColors.creamLine, width: 1.5),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
      ),
      child: Column(
        children: [
          const PotoMascot(expression: PotoExpression.idle, size: 84),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Add your originals',
            style: TextStyle(
              fontFamily: AppTheme.headingFont,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.deepMaroon,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Photos and videos, exactly as captured.\nNothing gets compressed.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.featherTaupe,
              fontSize: 13,
              height: 1.55,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PressableScale(
            onTap: isPicking ? null : onPick,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                border:
                    Border.all(color: AppColors.creamLine, width: 1.5),
                boxShadow: AppShadows.card,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isPicking
                        ? Icons.hourglass_top_rounded
                        : Icons.add_photo_alternate_outlined,
                    color: isPicking
                        ? AppColors.featherTaupe
                        : AppColors.velvetMaroon,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    isPicking ? 'Opening...' : 'Choose Photos & Videos',
                    style: TextStyle(
                      color: isPicking
                          ? AppColors.featherTaupe
                          : AppColors.charcoalInk,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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

// ── Files section (files selected) ───────────────────────────────────────────

class _FilesSection extends StatelessWidget {
  const _FilesSection({
    required this.files,
    required this.isPicking,
    required this.onPick,
    required this.onRemove,
    required this.onClear,
  });

  final List<UploadFile> files;
  final bool isPicking;
  final VoidCallback onPick;
  final ValueChanged<int> onRemove;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final totalMb =
        files.fold<double>(0, (s, f) => s + f.sizeBytes) / (1024 * 1024);
    final sizeLabel = totalMb < 1
        ? '${(totalMb * 1024).toStringAsFixed(0)} KB total'
        : '${totalMb.toStringAsFixed(1)} MB total';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${files.length} original${files.length == 1 ? '' : 's'} ready',
                    style: const TextStyle(
                      fontFamily: AppTheme.headingFont,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepMaroon,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sizeLabel,
                    style: const TextStyle(
                      color: AppColors.featherTaupe,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            _SmallButton(
              label: 'Add more',
              icon: Icons.add,
              onTap: isPicking ? null : onPick,
            ),
            const SizedBox(width: AppSpacing.sm),
            _SmallButton(
              label: 'Clear',
              onTap: onClear,
              muted: true,
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        // Horizontal thumbnail row
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: files.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, i) => _FileThumbnail(
              file: files[i],
              onRemove: () => onRemove(i),
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Quality promise card
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.brightGold.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
                color: AppColors.brightGold.withValues(alpha: 0.22),
                width: 0.8),
          ),
          child: Row(
            children: const [
              Icon(Icons.verified_outlined,
                  color: AppColors.brightGold, size: 16),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Nothing gets compressed. Every file uploads in full original quality.',
                  style: TextStyle(
                    color: AppColors.charcoalInk,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── File thumbnail ────────────────────────────────────────────────────────────

class _FileThumbnail extends StatelessWidget {
  const _FileThumbnail({required this.file, required this.onRemove});

  final UploadFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isVideo = file.fileType == 'video';
    final ext = _extLabel(file.name);
    final colors = isVideo
        ? const [Color(0xFF2A2A3A), Color(0xFF3E3E52)]
        : [AppColors.velvetMaroon.withValues(alpha: 0.85), AppColors.deepMaroon];

    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Stack(
        children: [
          Center(
            child: Icon(
              isVideo ? Icons.movie_outlined : Icons.image_outlined,
              color: AppColors.white.withValues(alpha: 0.35),
              size: 22,
            ),
          ),
          // Format badge
          Positioned(
            top: 5,
            left: 5,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                ext,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          // Remove button
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    color: AppColors.white, size: 11),
              ),
            ),
          ),
          // Filename
          Positioned(
            bottom: 5,
            left: 5,
            right: 5,
            child: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 8.5,
                fontWeight: FontWeight.w500,
                shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _extLabel(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot >= name.length - 1) return 'FILE';
    final ext = name.substring(dot + 1).toUpperCase();
    return ext.length > 4 ? ext.substring(0, 4) : ext;
  }
}

// ── Small utility button ──────────────────────────────────────────────────────

class _SmallButton extends StatelessWidget {
  const _SmallButton({
    required this.label,
    this.icon,
    this.onTap,
    this.muted = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: muted ? AppColors.warmCream : AppColors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.creamLine, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 13,
                  color: onTap == null
                      ? AppColors.featherTaupe
                      : AppColors.charcoalInk),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: muted
                    ? AppColors.featherTaupe
                    : onTap == null
                        ? AppColors.featherTaupe
                        : AppColors.charcoalInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sticky upload CTA ─────────────────────────────────────────────────────────

class _UploadCTA extends StatelessWidget {
  const _UploadCTA({
    required this.count,
    required this.isPicking,
    required this.bottomPad,
    required this.onUpload,
  });

  final int count;
  final bool isPicking;
  final double bottomPad;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    final isReady = onUpload != null;
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
      padding: EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm + bottomPad),
      child: PressableScale(
        onTap: onUpload,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Container(
          height: 54,
          width: double.infinity,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isReady ? AppColors.velvetMaroon : AppColors.creamLine,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            boxShadow: isReady ? AppShadows.primaryButton : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_upload_outlined,
                color: isReady
                    ? AppColors.pearlCream
                    : AppColors.featherTaupe,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                count > 0
                    ? 'Upload $count Original${count == 1 ? '' : 's'}'
                    : 'Choose files to upload',
                style: TextStyle(
                  color: isReady
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
