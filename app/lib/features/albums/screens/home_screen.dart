import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_error.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/litrato_header.dart';
import '../../../core/widgets/memory_stat_card.dart';
import '../../../core/widgets/notification_item.dart';
import '../../../core/widgets/quality_promise_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/album.dart';
import '../providers/album_provider.dart';
import '../widgets/album_card.dart';
import '../widgets/media_preview_image.dart';
import '../widgets/media_video_preview.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/poto_mascot.dart';
import '../../../core/widgets/pwa_install_banner.dart';
import '../widgets/album_empty_state.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    this.initialIndex = 0,
    super.key,
  });

  final int initialIndex;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late int currentIndex = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: IndexedStack(
              index: currentIndex,
              children: const [
                _AlbumsTab(),
                _InvitesTab(),
                _NotificationsTab(),
                _ProfileTab(),
              ],
            ),
          ),
          // PWA install banner — floats above bottom nav, slides in after delay
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: PwaInstallBanner(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => setState(() => currentIndex = index),
        backgroundColor: AppColors.warmCream,
        indicatorColor: AppColors.velvetMaroon.withValues(alpha: 0.08),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon:
                Icon(Icons.photo_album_outlined, color: AppColors.featherTaupe),
            selectedIcon:
                Icon(Icons.photo_album, color: AppColors.velvetMaroon),
            label: 'Albums',
          ),
          NavigationDestination(
            icon: Icon(Icons.mail_outline, color: AppColors.featherTaupe),
            selectedIcon: Icon(Icons.mail, color: AppColors.velvetMaroon),
            label: 'Invites',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none, color: AppColors.featherTaupe),
            selectedIcon:
                Icon(Icons.notifications, color: AppColors.velvetMaroon),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: AppColors.featherTaupe),
            selectedIcon: Icon(Icons.person, color: AppColors.velvetMaroon),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(albumListProvider);
    final archivedAsync = ref.watch(archivedAlbumsProvider);
    final profile = ref.watch(currentUserProfileProvider);
    final albums = albumsAsync.when<List<Album>>(
      data: (albums) => albums,
      loading: () => const [],
      error: (_, __) => const [],
    );
    final archived = archivedAsync.asData?.value ?? const [];
    final fileCount =
        albums.fold<int>(0, (total, album) => total + album.fileCount);
    final memberCount =
        albums.fold<int>(0, (total, album) => total + album.memberCount);
    final initials = _initialsFor(profile?.displayName);

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 86),
          children: [
            LitratoHeader(avatarInitials: initials),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: QualityPromiseCard(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  MemoryStatCard(
                      label: 'Files',
                      value: '$fileCount',
                      icon: Icons.photo_library_outlined),
                  const SizedBox(width: 10),
                  MemoryStatCard(
                      label: 'Albums',
                      value: '${albums.length}',
                      icon: Icons.auto_awesome_motion_outlined,
                      gold: true),
                  const SizedBox(width: 10),
                  MemoryStatCard(
                      label: 'People',
                      value: '$memberCount',
                      icon: Icons.group_outlined),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Albums',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Only the people you choose can see these.',
                          style: TextStyle(
                              color: AppColors.mutedInk, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.maroon,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.createAlbum),
                    icon: const Icon(Icons.add, size: 12),
                    label:
                        const Text('New Album', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: albumsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child:
                        CircularProgressIndicator(color: AppColors.brightGold),
                  ),
                ),
                error: (error, _) => AlbumEmptyState(
                  title: 'Albums unavailable',
                  message: AppError.messageFor(error),
                  expression: PotoExpression.error,
                  actionLabel: 'Try Again',
                  onAction: () => ref.invalidate(albumListProvider),
                ),
                data: (albums) => albums.isEmpty
                    ? AlbumEmptyState(
                        title: 'No albums yet',
                        message:
                            'Create your first private album and start sharing original-quality memories.',
                        actionLabel: 'Create Album',
                        onAction: () =>
                            Navigator.pushNamed(context, AppRoutes.createAlbum),
                      )
                    : Column(
                        children: [
                          for (final album in albums) ...[
                            AlbumCard(
                              album: album,
                              onTap: () => Navigator.pushNamed(
                                context,
                                AppRoutes.albumDetails,
                                arguments: album,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
              ),
            ),

            // ── Archived spaces ────────────────────────────────────────
            if (archived.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(
                      'Archived (${archived.length})',
                      style: const TextStyle(
                        color: AppColors.featherTaupe,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    iconColor: AppColors.featherTaupe,
                    collapsedIconColor: AppColors.featherTaupe,
                    children: [
                      for (final album in archived)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _ArchivedAlbumRow(
                            album: album,
                            onRestore: () async {
                              await ref
                                  .read(albumManagementProvider.notifier)
                                  .unarchive(albumId: album.id);
                              if (context.mounted) {
                                showAppToast(context,
                                    message: '"${album.name}" restored.');
                              }
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (albums.isNotEmpty)
          Positioned(
            right: 20,
            bottom: 18,
            child: FloatingActionButton(
              tooltip: 'Create album',
              backgroundColor: AppColors.velvetMaroon,
              foregroundColor: AppColors.white,
              shape: const CircleBorder(),
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.createAlbum),
              child: const Icon(Icons.add),
            ),
          ),
      ],
    );
  }
}

class _InvitesTab extends ConsumerWidget {
  const _InvitesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(albumListProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const LitratoHeader(
          title: 'Invites',
          subtitle: "Who's in your spaces.",
          showAvatar: false,
        ),
        const SizedBox(height: 14),
        albumsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                  color: AppColors.brightGold, strokeWidth: 2),
            ),
          ),
          error: (error, _) => AlbumEmptyState(
            title: 'Invites unavailable',
            message: AppError.messageFor(error),
            expression: PotoExpression.error,
            actionLabel: 'Try Again',
            onAction: () => ref.invalidate(albumListProvider),
          ),
          data: (albums) {
            if (albums.isEmpty) {
              return AlbumEmptyState(
                title: 'No spaces yet.',
                message:
                    'Create a space first, then invite the people who were actually there.',
                actionLabel: 'Create a space',
                onAction: () =>
                    Navigator.pushNamed(context, AppRoutes.createAlbum),
              );
            }

            final adminAlbums =
                albums.where((album) => album.canManageMembers).toList();
            final sharedAlbums =
                albums.where((album) => !album.canManageMembers).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (adminAlbums.isNotEmpty) ...[
                  Text('Spaces you manage.',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  for (final album in adminAlbums) ...[
                    _InviteAlbumRow(
                      album: album,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.albumDetails,
                        arguments: album,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
                if (sharedAlbums.isNotEmpty) ...[
                  if (adminAlbums.isNotEmpty)
                    const SizedBox(height: AppSpacing.sm),
                  Text('Spaces you\'re in.',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  const Text(
                    'Open a space to see its members, or leave from the Members screen.',
                    style: TextStyle(color: AppColors.mutedInk, fontSize: 11),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final album in sharedAlbums) ...[
                    _InviteAlbumRow(
                      album: album,
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.members,
                        arguments: album,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
                if (adminAlbums.isEmpty && sharedAlbums.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      'You\'re a member in ${sharedAlbums.length} space${sharedAlbums.length == 1 ? '' : 's'} but don\'t manage any. Admins can invite and change roles.',
                      style: const TextStyle(
                          color: AppColors.featherTaupe,
                          fontSize: 12,
                          height: 1.5),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _InviteAlbumRow extends StatelessWidget {
  const _InviteAlbumRow({required this.album, required this.onTap});

  final Album album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Album thumbnail or gradient swatch
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: SizedBox(
              width: 44,
              height: 44,
              child: album.coverIsVideo
                  ? MediaVideoPreview(
                      mediaFileId: album.coverMediaFileId,
                      fallback: _AlbumSwatch(album: album),
                    )
                  : MediaPreviewImage(
                      mediaFileId: album.coverMediaFileId,
                      thumbnailUrl: album.coverThumbnailUrl,
                      fallback: _AlbumSwatch(album: album),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: AppColors.charcoalInk),
                ),
                const SizedBox(height: 3),
                Text(
                  '${album.memberCount} member${album.memberCount == 1 ? '' : 's'} · ${album.role}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: AppColors.featherTaupe, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            album.canManageMembers ? 'Manage' : 'View',
            style: const TextStyle(
              color: AppColors.brightGold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right,
              color: AppColors.brightGold, size: 18),
        ],
      ),
    );
  }
}

class _AlbumSwatch extends StatelessWidget {
  const _AlbumSwatch({required this.album});
  final Album album;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: album.coverColors,
        ),
      ),
    );
  }
}

class _ArchivedAlbumRow extends StatelessWidget {
  const _ArchivedAlbumRow({required this.album, required this.onRestore});

  final Album album;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.65,
      child: AppCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: SizedBox(
                width: 44,
                height: 44,
                child: album.coverIsVideo
                    ? MediaVideoPreview(
                        mediaFileId: album.coverMediaFileId,
                        fallback: _AlbumSwatch(album: album),
                      )
                    : MediaPreviewImage(
                        mediaFileId: album.coverMediaFileId,
                        thumbnailUrl: album.coverThumbnailUrl,
                        fallback: _AlbumSwatch(album: album),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    album.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.charcoalInk,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Archived',
                    style: TextStyle(
                      color: AppColors.featherTaupe,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            PressableScale(
              onTap: onRestore,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.velvetMaroon.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: AppColors.velvetMaroon.withValues(alpha: 0.20),
                    width: 0.8,
                  ),
                ),
                child: const Text(
                  'Restore',
                  style: TextStyle(
                    color: AppColors.velvetMaroon,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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

class _NotificationsTab extends ConsumerWidget {
  const _NotificationsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final albumsAsync = ref.watch(albumListProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const LitratoHeader(
          title: 'Activity',
          subtitle: "What's been happening.",
          showAvatar: false,
        ),
        const SizedBox(height: 14),
        albumsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                  color: AppColors.brightGold, strokeWidth: 2),
            ),
          ),
          error: (error, _) => AlbumEmptyState(
            title: 'Activity unavailable',
            message: AppError.messageFor(error),
            expression: PotoExpression.error,
            actionLabel: 'Try Again',
            onAction: () => ref.invalidate(albumListProvider),
          ),
          data: (albums) {
            if (albums.isEmpty) {
              return const AlbumEmptyState(
                title: 'Nothing yet.',
                message:
                    'Create a space, upload your first original, and it will show up here.',
              );
            }

            final withFiles = albums.where((a) => a.fileCount > 0).toList();
            final empty = albums.where((a) => a.fileCount == 0).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (withFiles.isNotEmpty) ...[
                  for (final album in withFiles) ...[
                    NotificationItem(
                      title:
                          '${album.fileCount} original${album.fileCount == 1 ? '' : 's'} in ${album.name}.',
                      message:
                          '${album.memberCount} member${album.memberCount == 1 ? '' : 's'} · Your role: ${album.role}',
                      time: album.updatedLabel,
                      unread: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
                if (empty.isNotEmpty) ...[
                  if (withFiles.isNotEmpty)
                    const SizedBox(height: AppSpacing.sm),
                  for (final album in empty) ...[
                    NotificationItem(
                      title: '${album.name} is ready.',
                      message: 'No files yet. Be the first to add something.',
                      time: album.updatedLabel,
                      unread: false,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider);
    final albumsAsync = ref.watch(albumListProvider);
    final albums = albumsAsync.asData?.value ?? const <Album>[];
    final fileCount =
        albums.fold<int>(0, (total, album) => total + album.fileCount);
    final memberCount =
        albums.fold<int>(0, (total, album) => total + album.memberCount);
    final adminCount = albums.where((album) => album.canManageMembers).length;
    final displayName = profile?.displayName?.isNotEmpty == true
        ? profile!.displayName!
        : 'Potoos User';
    final email = profile?.email.isNotEmpty == true
        ? profile!.email
        : 'Signed in with Google';
    final avatarUrl = profile?.avatarUrl?.trim();
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;
    final initials = _initialsFor(displayName);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.xxl),
      children: [
        // ── Avatar hero ───────────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.velvetMaroon,
                  border: Border.all(
                    color: AppColors.brightGold.withValues(alpha: 0.40),
                    width: 2.5,
                  ),
                  boxShadow: AppShadows.float,
                ),
                child: ClipOval(
                  child: hasAvatar
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontFamily: AppTheme.headingFont,
                                color: AppColors.pearlCream,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontFamily: AppTheme.headingFont,
                              color: AppColors.pearlCream,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                displayName,
                style: const TextStyle(
                  fontFamily: AppTheme.headingFont,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepMaroon,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: const TextStyle(
                  color: AppColors.featherTaupe,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // ── Stat row ─────────────────────────────────────────────────────
        Row(
          children: [
            MemoryStatCard(
              label: 'originals',
              value: '$fileCount',
              icon: Icons.photo_outlined,
              gold: true,
            ),
            const SizedBox(width: AppSpacing.sm),
            MemoryStatCard(
              label: 'albums',
              value: '${albums.length}',
              icon: Icons.auto_awesome_motion_outlined,
            ),
            const SizedBox(width: AppSpacing.sm),
            MemoryStatCard(
              label: 'people',
              value: '$memberCount',
              icon: Icons.group_outlined,
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.md),

        // ── Admin spaces ────────────────────────────────────────────────
        if (adminCount > 0) ...[
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                  color: AppColors.velvetMaroon.withValues(alpha: 0.10),
                  width: 0.8),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.brightGold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                  ),
                  child: const Icon(Icons.admin_panel_settings_outlined,
                      color: AppColors.brightGold, size: 18),
                ),
                const SizedBox(width: AppSpacing.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'You manage',
                        style: TextStyle(
                          fontFamily: AppTheme.headingFont,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoalInk,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$adminCount Admin space${adminCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: AppColors.featherTaupe,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        // ── Storage guarantee ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
                color: AppColors.velvetMaroon.withValues(alpha: 0.10),
                width: 0.8),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.verified_outlined,
                      color: AppColors.velvetMaroon, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'What Potoos promises you.',
                    style: TextStyle(
                      fontFamily: AppTheme.headingFont,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppColors.deepMaroon,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _GuaranteeRow(
                icon: Icons.high_quality_outlined,
                text: 'Every file stored without compression.',
              ),
              const SizedBox(height: 8),
              _GuaranteeRow(
                icon: Icons.lock_outline,
                text: 'Albums are invite-only. Nothing is public.',
              ),
              const SizedBox(height: 8),
              _GuaranteeRow(
                icon: Icons.download_outlined,
                text: 'Download the exact original any time.',
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // ── Log out ──────────────────────────────────────────────────────
        PressableScale(
          onTap: () async {
            final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Log out?'),
                    content: const Text(
                        'Your albums and originals stay safe. Sign back in any time.'),
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
                        child: const Text('Log out'),
                      ),
                    ],
                  ),
                ) ??
                false;

            if (!confirmed || !context.mounted) return;
            await ref.read(authControllerProvider.notifier).signOut();
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, AppRoutes.login);
            }
          },
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          child: Container(
            height: 52,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: AppColors.velvetMaroon.withValues(alpha: 0.28),
                width: 1.5,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_outlined,
                    color: AppColors.velvetMaroon, size: 17),
                SizedBox(width: 8),
                Text(
                  'Log out',
                  style: TextStyle(
                    color: AppColors.velvetMaroon,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // ── Legal & Support ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
                color: AppColors.velvetMaroon.withValues(alpha: 0.08),
                width: 0.8),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Legal & Support',
                style: TextStyle(
                  fontFamily: AppTheme.headingFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.deepMaroon,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _LegalRow(
                icon: Icons.shield_outlined,
                label: 'Privacy Policy',
                onTap: () => launchUrl(
                  Uri.parse('https://akircyno.github.io/potoos/privacy.html'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const _ThinDivider(),
              _LegalRow(
                icon: Icons.description_outlined,
                label: 'Terms of Use',
                onTap: () => launchUrl(
                  Uri.parse('https://akircyno.github.io/potoos/terms.html'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const _ThinDivider(),
              _LegalRow(
                icon: Icons.mail_outline,
                label: 'Contact support',
                onTap: () => launchUrl(
                  Uri.parse('mailto:prcmarketingteam@gmail.com'
                      '?subject=Potoos%20Support'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // ── Delete account ────────────────────────────────────────────────
        _DeleteAccountButton(ref: ref),
      ],
    );
  }
}

class _DeleteAccountButton extends StatefulWidget {
  const _DeleteAccountButton({required this.ref});
  final WidgetRef ref;

  @override
  State<_DeleteAccountButton> createState() => _DeleteAccountButtonState();
}

class _DeleteAccountButtonState extends State<_DeleteAccountButton> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 0.6,
          color: AppColors.creamLine,
        ),
        const SizedBox(height: AppSpacing.lg),
        GestureDetector(
          onTap: _isDeleting ? null : () => _confirmDelete(context),
          child: Text(
            _isDeleting ? 'Deleting account...' : 'Delete my account',
            style: TextStyle(
              color: _isDeleting
                  ? AppColors.featherTaupe
                  : AppColors.velvetMaroon.withValues(alpha: 0.60),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This will permanently remove:\n'
          '• All spaces you manage and their files\n'
          '• Your membership from all other spaces\n'
          '• Your profile and account\n\n'
          'This cannot be undone.',
        ),
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
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    setState(() => _isDeleting = true);

    try {
      await widget.ref.read(deleteAccountProvider.notifier).deleteAccount();
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.login, (_) => false);
      }
    } catch (e) {
      if (context.mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppError.messageFor(e)),
            backgroundColor: AppColors.velvetMaroon,
          ),
        );
      }
    }
  }
}

class _LegalRow extends StatelessWidget {
  const _LegalRow(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.featherTaupe),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.charcoalInk,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.open_in_new,
                size: 13, color: AppColors.featherTaupe),
          ],
        ),
      ),
    );
  }
}

class _ThinDivider extends StatelessWidget {
  const _ThinDivider();

  @override
  Widget build(BuildContext context) {
    return Container(height: 0.6, color: AppColors.creamLine);
  }
}

String _initialsFor(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.length == 1) {
    return parts.first.characters.take(2).toString().toUpperCase();
  }
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}

class _GuaranteeRow extends StatelessWidget {
  const _GuaranteeRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.maroon),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: AppColors.mutedInk, fontSize: 12, height: 1.4)),
        ),
      ],
    );
  }
}
