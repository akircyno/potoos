import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/widgets/app_screen.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/poto_mascot.dart';
import '../../auth/providers/auth_provider.dart';
import '../../downloads/screens/save_all_screen.dart';
import '../models/album.dart';
import '../models/album_member.dart';
import '../../uploads/providers/upload_provider.dart';
import '../models/media_file.dart';
import '../providers/album_provider.dart';
import '../widgets/album_empty_state.dart';
import '../widgets/gallery_tile.dart';
import '../widgets/media_preview_image.dart';
import '../widgets/media_video_preview.dart';
import 'media_viewer_screen.dart';

// Album management menu values
enum _MenuAction { rename, archive, delete }

class AlbumDetailsScreen extends ConsumerStatefulWidget {
  const AlbumDetailsScreen({super.key});

  @override
  ConsumerState<AlbumDetailsScreen> createState() => _AlbumDetailsScreenState();
}

class _AlbumDetailsScreenState extends ConsumerState<AlbumDetailsScreen>
    with WidgetsBindingObserver {
  Album? _currentAlbum;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final album = _currentAlbum;
      if (album != null) {
        _refreshAlbum(ref, album);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeAlbum = ModalRoute.of(context)?.settings.arguments;
    if (routeAlbum is! Album) {
      return Scaffold(
        appBar: AppBar(title: const Text('Album Details')),
        body: AppScreen(
          children: [
            AlbumEmptyState(
              title: 'Album unavailable',
              message: 'Open an album from your album list.',
              expression: PotoExpression.error,
              actionLabel: 'Back to Albums',
              onAction: () =>
                  Navigator.pushReplacementNamed(context, AppRoutes.home),
            ),
          ],
        ),
      );
    }

    final album = routeAlbum;
    _currentAlbum = album;
    ref.watch(albumRealtimeRefreshProvider(album.id));

    final filesAsync = ref.watch(albumMediaFilesProvider(album.id));
    final membersAsync = ref.watch(albumMembersProvider(album.id));
    final currentProfile = ref.watch(currentUserProfileProvider);
    final selectionMode = ref.watch(albumSelectionModeProvider(album.id));
    final selectedIds = ref.watch(selectedMediaIdsProvider(album.id));

    final loadedFiles = filesAsync.asData?.value;
    final loadedMembers = membersAsync.asData?.value;

    final selectedFiles = loadedFiles
            ?.where((f) => selectedIds.contains(f.id))
            .toList(growable: false) ??
        const <MediaFile>[];
    final hasSelection = selectedFiles.isNotEmpty;
    final filesForSave = hasSelection ? selectedFiles : loadedFiles ?? const [];
    final coverMediaFileId = loadedFiles != null && loadedFiles.isNotEmpty
        ? loadedFiles.first.id
        : album.coverMediaFileId;
    final coverThumbnailUrl = loadedFiles != null && loadedFiles.isNotEmpty
        ? loadedFiles.first.thumbnailUrl
        : album.coverThumbnailUrl;
    final coverIsVideo = loadedFiles != null && loadedFiles.isNotEmpty
        ? loadedFiles.first.isVideo
        : album.coverIsVideo;

    final visibleFileCount = loadedFiles?.length ?? album.fileCount;

    if (loadedMembers != null && loadedMembers.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Album Details')),
        body: AppScreen(
          children: [
            AlbumEmptyState(
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

    final uploadState = ref.watch(uploadControllerProvider);
    final hasPausedUpload =
        uploadState.isPaused && uploadState.albumId == album.id;

    final visibleMemberCount = loadedMembers?.length ?? album.memberCount;
    final currentMember = _currentMember(loadedMembers, currentProfile?.id);
    final effectiveRole = currentMember?.role ?? album.role;
    final effectiveRoleLabel = _roleLabel(effectiveRole);
    final canUpload = _canUploadRole(effectiveRole);
    final isAdmin = effectiveRole.toLowerCase() == 'admin';
    final canSave = !selectionMode || hasSelection;

    // React to management actions completing
    ref.listen<AlbumManagementState>(albumManagementProvider, (prev, next) {
      if (!context.mounted) return;

      if (next.errorMessage != null &&
          next.errorMessage != prev?.errorMessage) {
        showAppToast(context, message: next.errorMessage!, isError: true);
      }

      if (!next.done) return;

      if (next.successMessage != null) {
        showAppToast(context, message: next.successMessage!);
      }

      // Rename → pop once (back to album list)
      // Archive / Delete → clear nav stack back to home
      if (next.action == AlbumManagementAction.rename) {
        Navigator.pop(context);
      } else {
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.home, (_) => false);
      }
    });

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.warmCream,
        body: Stack(
          children: [
            RefreshIndicator(
              color: AppColors.brightGold,
              backgroundColor: AppColors.white,
              onRefresh: () => _refreshAlbum(ref, album),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  // ── Cover header ─────────────────────────────────────────────
                  SliverAppBar(
                    expandedHeight: 200,
                    pinned: true,
                    stretch: true,
                    backgroundColor: album.coverColors.isNotEmpty
                        ? album.coverColors.first
                        : AppColors.deepMaroon,
                    foregroundColor: AppColors.white,
                    automaticallyImplyLeading: false,
                    leading: const _BackButton(),
                    title: Text(
                      album.name,
                      style: const TextStyle(
                        fontFamily: AppTheme.headingFont,
                        color: AppColors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    actions: [
                      // Admin-only management menu
                      if (isAdmin)
                        PopupMenuButton<_MenuAction>(
                          icon: const Icon(Icons.more_vert,
                              color: AppColors.white, size: 20),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusMd)),
                          onSelected: (action) {
                            switch (action) {
                              case _MenuAction.rename:
                                _showRenameSheet(context, ref, album);
                              case _MenuAction.archive:
                                _showArchiveDialog(context, ref, album);
                              case _MenuAction.delete:
                                _showDeleteDialog(context, ref, album);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: _MenuAction.rename,
                              child: Row(children: [
                                Icon(Icons.edit_outlined, size: 16),
                                SizedBox(width: 10),
                                Text('Rename'),
                              ]),
                            ),
                            PopupMenuItem(
                              value: _MenuAction.archive,
                              child: Row(children: [
                                Icon(Icons.inventory_2_outlined, size: 16),
                                SizedBox(width: 10),
                                Text('Archive'),
                              ]),
                            ),
                            PopupMenuDivider(),
                            PopupMenuItem(
                              value: _MenuAction.delete,
                              child: Row(children: [
                                Icon(Icons.delete_forever_outlined,
                                    size: 16, color: AppColors.velvetMaroon),
                                SizedBox(width: 10),
                                Text('Delete permanently',
                                    style: TextStyle(
                                        color: AppColors.velvetMaroon)),
                              ]),
                            ),
                          ],
                        ),
                      // Role badge
                      Padding(
                        padding: const EdgeInsets.only(right: 14, top: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.18),
                            border: Border.all(
                                color: AppColors.white.withValues(alpha: 0.28),
                                width: 0.5),
                            borderRadius:
                                BorderRadius.circular(AppSpacing.radiusPill),
                          ),
                          child: Text(
                            effectiveRoleLabel.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      stretchModes: const [StretchMode.zoomBackground],
                      background: _CoverBackground(
                        album: album,
                        coverMediaFileId: coverMediaFileId,
                        coverThumbnailUrl: coverThumbnailUrl,
                        coverIsVideo: coverIsVideo,
                        visibleFileCount: visibleFileCount,
                        visibleMemberCount: visibleMemberCount,
                      ),
                    ),
                  ),

                  // ── Action strip ──────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                      child: _ActionStrip(
                        canUpload: canUpload,
                        selectionMode: selectionMode,
                        selectedCount: selectedFiles.length,
                        canSave: canSave,
                        onUpload: () => _pushAndRefresh(
                          context,
                          routeName: AppRoutes.upload,
                          routeArguments: album,
                          album: album,
                        ),
                        onSave: canSave
                            ? () => _pushAndRefresh(
                                  context,
                                  routeName: AppRoutes.saveAll,
                                  routeArguments: SaveAllArgs(
                                      album: album, files: filesForSave),
                                  album: album,
                                )
                            : null,
                        onMembers: () => _pushAndRefresh(
                          context,
                          routeName: AppRoutes.members,
                          routeArguments: album,
                          album: album,
                        ),
                      ),
                    ),
                  ),

                  // ── Count + select toggle ─────────────────────────────────────
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              selectionMode
                                  ? '${selectedIds.length} selected'
                                  : pluralize(visibleFileCount, 'file', 'files'),
                              style: const TextStyle(
                                color: AppColors.mutedInk,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: loadedFiles == null || loadedFiles.isEmpty
                                ? null
                                : () {
                                    final selNotifier = ref.read(
                                        albumSelectionModeProvider(album.id)
                                            .notifier);
                                    final idsNotifier = ref.read(
                                        selectedMediaIdsProvider(album.id)
                                            .notifier);
                                    final next = !selectionMode;
                                    selNotifier.setEnabled(next);
                                    if (!next) idsNotifier.clear();
                                  },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              child: Text(
                                selectionMode ? 'Done' : 'Select',
                                style: TextStyle(
                                  color: (loadedFiles == null ||
                                          loadedFiles.isEmpty)
                                      ? AppColors.featherTaupe
                                      : AppColors.brightGold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── File grid ─────────────────────────────────────────────────
                  filesAsync.when(
                    loading: () => const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(48),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.brightGold,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    ),
                    error: (error, _) => SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                        child: AlbumEmptyState(
                          title: 'Could not load files',
                          message: AppError.messageFor(error),
                          expression: PotoExpression.error,
                          actionLabel: 'Try Again',
                          onAction: () =>
                              ref.invalidate(albumMediaFilesProvider(album.id)),
                        ),
                      ),
                    ),
                    data: (files) => files.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                                  AppSpacing.sm, AppSpacing.md, 0),
                              child: AlbumEmptyState(
                                title: 'Nothing here yet.',
                                message: canUpload
                                    ? 'Be the first to add something. Poto is ready when you are.'
                                    : 'Files will show up when someone uploads.',
                                actionLabel: canUpload ? 'Upload' : null,
                                onAction: canUpload
                                    ? () => _pushAndRefresh(
                                          context,
                                          routeName: AppRoutes.upload,
                                          routeArguments: album,
                                          album: album,
                                        )
                                    : null,
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.fromLTRB(
                                AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                            sliver: SliverGrid.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                crossAxisSpacing: 2,
                                mainAxisSpacing: 2,
                                childAspectRatio: 1,
                              ),
                              itemCount: files.length,
                              itemBuilder: (context, index) {
                                final file = files[index];
                                return GalleryTile(
                                  file: file,
                                  selectionMode: selectionMode,
                                  selected: selectedIds.contains(file.id),
                                  onTap: selectionMode
                                      ? () => _toggleSelectedFile(
                                            ref,
                                            albumId: album.id,
                                            fileId: file.id,
                                          )
                                      : () => _pushAndRefresh(
                                            context,
                                            routeName: AppRoutes.mediaViewer,
                                            routeArguments: MediaViewerArgs(
                                              files: files,
                                              initialIndex: index,
                                            ),
                                            album: album,
                                          ),
                                );
                              },
                            ),
                          ),
                  ),

                  // Bottom padding — extra clearance for selection bar / resume banner
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: selectionMode && hasSelection
                          ? 84
                          : hasPausedUpload
                              ? 96
                              : 32,
                    ),
                  ),
                ],
              ),
            ),

            // ── Resume upload banner ──────────────────────────────────────────
            if (hasPausedUpload && !selectionMode)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 16,
                left: AppSpacing.md,
                right: AppSpacing.md,
                child: _UploadResumeBanner(
                  remainingCount: uploadState.remainingCount,
                  onResume: () {
                    final args = ref
                        .read(uploadControllerProvider.notifier)
                        .pausedArgs;
                    if (args == null) return;
                    Navigator.pushNamed(
                      context,
                      AppRoutes.uploadProgress,
                      arguments: args,
                    );
                  },
                ),
              ),

            // ── Sticky selection bar ──────────────────────────────────────────
            if (selectionMode)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _SelectionBar(
                  selectedCount: selectedFiles.length,
                  onSave: hasSelection
                      ? () => _pushAndRefresh(
                            context,
                            routeName: AppRoutes.saveAll,
                            routeArguments:
                                SaveAllArgs(album: album, files: selectedFiles),
                            album: album,
                          )
                      : null,
                  onClear: () => ref
                      .read(selectedMediaIdsProvider(album.id).notifier)
                      .clear(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pushAndRefresh(
    BuildContext context, {
    required String routeName,
    required Object routeArguments,
    required Album album,
  }) async {
    await Navigator.pushNamed(
      context,
      routeName,
      arguments: routeArguments,
    );
    if (!mounted) return;
    await _refreshAlbum(ref, album);
  }

  void _toggleSelectedFile(
    WidgetRef ref, {
    required String albumId,
    required String fileId,
  }) {
    ref.read(selectedMediaIdsProvider(albumId).notifier).toggle(fileId);
  }

  Future<void> _refreshAlbum(WidgetRef ref, Album album) async {
    ref.invalidate(albumMediaFilesProvider(album.id));
    ref.invalidate(albumMembersProvider(album.id));
    ref.invalidate(albumListProvider);

    try {
      await Future.wait([
        ref.read(albumMediaFilesProvider(album.id).future),
        ref.read(albumMembersProvider(album.id).future),
      ]);
    } catch (_) {
      // The refreshed provider will show the normal error state if it fails.
    }
  }

  AlbumMember? _currentMember(List<AlbumMember>? members, String? profileId) {
    if (members == null || profileId == null || profileId.isEmpty) return null;
    for (final m in members) {
      if (m.userId == profileId) return m;
    }
    return null;
  }

  String _roleLabel(String role) {
    if (role.isEmpty) return 'Viewer';
    return '${role[0].toUpperCase()}${role.substring(1).toLowerCase()}';
  }

  bool _canUploadRole(String role) {
    final r = role.toLowerCase();
    return r == 'admin' || r == 'contributor';
  }

  // ── Album management ──────────────────────────────────────────────────────

  void _showRenameSheet(BuildContext context, WidgetRef ref, Album album) {
    final controller = TextEditingController(text: album.name);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.warmCream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.md + MediaQuery.of(sheetCtx).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rename space.',
                style: TextStyle(
                  fontFamily: AppTheme.headingFont,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepMaroon,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 16),
                decoration: const InputDecoration(hintText: 'Album name'),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: PressableScale(
                      onTap: () => Navigator.pop(sheetCtx),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusLg),
                          border: Border.all(color: AppColors.creamLine),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(
                                color: AppColors.charcoalInk,
                                fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: PressableScale(
                      onTap: () {
                        final name = controller.text.trim();
                        if (name.isEmpty || name == album.name) {
                          Navigator.pop(sheetCtx);
                          return;
                        }
                        Navigator.pop(sheetCtx);
                        ref
                            .read(albumManagementProvider.notifier)
                            .rename(albumId: album.id, name: name);
                      },
                      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      child: Container(
                        height: 50,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.velvetMaroon,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusLg),
                        ),
                        child: const Text('Save',
                            style: TextStyle(
                                color: AppColors.pearlCream,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showArchiveDialog(
      BuildContext context, WidgetRef ref, Album album) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive this space?'),
        content: const Text(
            'The album will be hidden from your list. Files stay safe in storage. You can unarchive it later.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.velvetMaroon,
              foregroundColor: AppColors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ref.read(albumManagementProvider.notifier).archive(albumId: album.id);
    }
  }

  Future<void> _showDeleteDialog(
      BuildContext context, WidgetRef ref, Album album) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: Text(
            '"${album.name}" and all its files will be removed from storage forever. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.velvetMaroon,
              foregroundColor: AppColors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete forever'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      ref.read(albumManagementProvider.notifier).delete(albumId: album.id);
    }
  }
}

// ── Private widgets ───────────────────────────────────────────────────────────

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: PressableScale(
        onTap: () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
          ),
          child:
              const Icon(Icons.chevron_left, color: AppColors.white, size: 20),
        ),
      ),
    );
  }
}

class _CoverBackground extends StatelessWidget {
  const _CoverBackground({
    required this.album,
    required this.coverMediaFileId,
    required this.coverThumbnailUrl,
    required this.coverIsVideo,
    required this.visibleFileCount,
    required this.visibleMemberCount,
  });

  final Album album;
  final String? coverMediaFileId;
  final String? coverThumbnailUrl;
  final bool coverIsVideo;
  final int visibleFileCount;
  final int visibleMemberCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background: authenticated preview or gradient
        Hero(
          tag: 'album-cover-${album.id}',
          child: coverIsVideo
              ? MediaVideoPreview(
                  mediaFileId: coverMediaFileId,
                  fallback: _CoverGradient(album: album),
                )
              : MediaPreviewImage(
                  mediaFileId: coverMediaFileId,
                  thumbnailUrl: coverThumbnailUrl,
                  fallback: _CoverGradient(album: album),
                ),
        ),
        // Grid texture (gradient only, skip on preview)
        if (coverMediaFileId == null && coverThumbnailUrl == null)
          Positioned.fill(
            child: Opacity(
              opacity: 0.07,
              child: GridPaper(
                color: AppColors.white,
                divisions: 1,
                interval: 16,
                subdivisions: 1,
              ),
            ),
          ),
        // Bottom scrim for text readability
        const Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SizedBox(
            height: 60,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0x88000000)],
                ),
              ),
            ),
          ),
        ),
        // Album name + meta row
        Positioned(
          bottom: 14,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                album.name,
                style: const TextStyle(
                  fontFamily: AppTheme.headingFont,
                  color: AppColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  shadows: [
                    Shadow(
                        color: Colors.black26,
                        offset: Offset(0, 1),
                        blurRadius: 4),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${pluralize(visibleFileCount, 'file', 'files')} · ${pluralize(visibleMemberCount, 'member', 'members')}',
                style: TextStyle(
                  color: AppColors.warmCream.withValues(alpha: 0.75),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CoverGradient extends StatelessWidget {
  const _CoverGradient({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: album.coverColors.isNotEmpty
              ? album.coverColors
              : [AppColors.deepMaroon, AppColors.velvetMaroon],
        ),
      ),
    );
  }
}

class _ActionStrip extends StatelessWidget {
  const _ActionStrip({
    required this.canUpload,
    required this.selectionMode,
    required this.selectedCount,
    required this.canSave,
    required this.onUpload,
    required this.onSave,
    required this.onMembers,
  });

  final bool canUpload;
  final bool selectionMode;
  final int selectedCount;
  final bool canSave;
  final VoidCallback onUpload;
  final VoidCallback? onSave;
  final VoidCallback onMembers;

  @override
  Widget build(BuildContext context) {
    final saveLabel =
        selectionMode && selectedCount > 0 ? 'Save $selectedCount' : 'Save All';

    return Row(
      children: [
        if (canUpload) ...[
          Expanded(
            child: _ActionPill(
              label: 'Upload',
              icon: Icons.upload_outlined,
              background: AppColors.velvetMaroon,
              foreground: AppColors.pearlCream,
              onTap: onUpload,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: _ActionPill(
            label: saveLabel,
            icon: Icons.save_alt_outlined,
            background: AppColors.brightGold.withValues(alpha: 0.13),
            foreground: AppColors.softGold,
            border: Border.all(
                color: AppColors.brightGold.withValues(alpha: 0.28),
                width: 0.8),
            onTap: canSave ? onSave : null,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _ActionPill(
          label: 'Members',
          icon: Icons.group_outlined,
          background: AppColors.velvetMaroon.withValues(alpha: 0.08),
          foreground: AppColors.velvetMaroon,
          onTap: onMembers,
          compact: true,
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.border,
    this.compact = false,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;
  final Border? border;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onTap == null;
    final bg = isDisabled ? AppColors.creamLine : background;
    final fg = isDisabled ? AppColors.featherTaupe : foreground;

    return PressableScale(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: Container(
        height: 42,
        padding: compact ? const EdgeInsets.symmetric(horizontal: 14) : null,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: isDisabled ? null : border,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: fg, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.selectedCount,
    required this.onSave,
    required this.onClear,
  });

  final int selectedCount;
  final VoidCallback? onSave;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: const Border(
            top: BorderSide(color: AppColors.creamLine, width: 0.8)),
        boxShadow: [
          BoxShadow(
            color: AppColors.midnightBurgundy.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md,
          AppSpacing.sm + bottomPad),
      child: Row(
        children: [
          Text(
            selectedCount > 0
                ? '$selectedCount selected'
                : 'Tap photos to select',
            style: TextStyle(
              color: selectedCount > 0
                  ? AppColors.charcoalInk
                  : AppColors.featherTaupe,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          PressableScale(
            onTap: onClear,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.warmCream,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                border: Border.all(color: AppColors.creamLine),
              ),
              child: const Text(
                'Clear',
                style: TextStyle(
                  color: AppColors.charcoalInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          PressableScale(
            onTap: onSave,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    onSave != null ? AppColors.brightGold : AppColors.creamLine,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Text(
                selectedCount > 0 ? 'Save $selectedCount' : 'Select photos',
                style: TextStyle(
                  color: onSave != null
                      ? AppColors.deepMaroon
                      : AppColors.featherTaupe,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadResumeBanner extends StatelessWidget {
  const _UploadResumeBanner({
    required this.remainingCount,
    required this.onResume,
  });

  final int remainingCount;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.deepMaroon,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: AppShadows.primaryButton,
      ),
      child: Row(
        children: [
          const Icon(Icons.pause_circle_outline,
              color: AppColors.brightGold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Upload paused.',
                  style: TextStyle(
                    color: AppColors.pearlCream,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${pluralize(remainingCount, 'file', 'files')} remaining',
                  style: TextStyle(
                    color: AppColors.warmCream.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onResume,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.brightGold,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: const Text(
                'Resume',
                style: TextStyle(
                  color: AppColors.deepMaroon,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

