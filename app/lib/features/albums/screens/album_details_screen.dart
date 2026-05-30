import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_screen.dart';
import '../../../core/widgets/invite_form.dart';
import '../../../core/widgets/role_chip.dart';
import '../../auth/providers/auth_provider.dart';
import '../../downloads/screens/save_all_screen.dart';
import '../models/album.dart';
import '../models/album_member.dart';
import '../models/media_file.dart';
import '../providers/album_provider.dart';
import '../widgets/album_empty_state.dart';
import '../widgets/gallery_tile.dart';

class AlbumDetailsScreen extends ConsumerWidget {
  const AlbumDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeAlbum = ModalRoute.of(context)?.settings.arguments;
    if (routeAlbum is! Album) {
      return Scaffold(
        appBar: AppBar(title: const Text('Album Details')),
        body: AppScreen(
          children: [
            AlbumEmptyState(
              title: 'Album unavailable',
              message: 'Open an album from your album list.',
              actionLabel: 'Back to Albums',
              onAction: () =>
                  Navigator.pushReplacementNamed(context, AppRoutes.home),
            ),
          ],
        ),
      );
    }

    final album = routeAlbum;
    final filesAsync = ref.watch(albumMediaFilesProvider(album.id));
    final membersAsync = ref.watch(albumMembersProvider(album.id));
    final inviteState = ref.watch(inviteMemberControllerProvider);
    final currentProfile = ref.watch(currentUserProfileProvider);
    final loadedFiles = filesAsync.asData?.value;
    final visibleFileCount = loadedFiles?.length ?? album.fileCount;
    final loadedMembers = membersAsync.asData?.value;
    final visibleMemberCount = loadedMembers?.length ?? album.memberCount;
    final isAdmin = album.canManageMembers;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0,
        backgroundColor: AppColors.deepMaroon,
        automaticallyImplyLeading: false,
      ),
      body: AppScreen(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: const BoxDecoration(
              color: AppColors.deepMaroon,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
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
                    ),
                    const SizedBox(width: 8),
                    Text('Albums',
                        style: TextStyle(
                            color: AppColors.white.withValues(alpha: 0.70),
                            fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  album.name,
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(color: AppColors.warmCream),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _HeaderMeta(
                        icon: Icons.photo_outlined,
                        label: '$visibleFileCount files'),
                    _HeaderMeta(
                        icon: Icons.group_outlined,
                        label: '$visibleMemberCount members'),
                    _HeaderMeta(
                        icon: Icons.verified_user_outlined,
                        label: 'Your role: ${album.role}'),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                if (album.canUpload) ...[
                  Expanded(
                    child: _ActionButton(
                      label: 'Upload',
                      icon: Icons.upload,
                      color: AppColors.maroon,
                      foreground: AppColors.white,
                      onTap: () => Navigator.pushNamed(
                          context, AppRoutes.upload,
                          arguments: album),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: _ActionButton(
                    label: 'Save All',
                    icon: Icons.save_alt,
                    color: AppColors.goldFaint,
                    foreground: AppColors.softGold,
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.saveAll,
                      arguments: SaveAllArgs(
                        album: album,
                        files: loadedFiles ?? const [],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$visibleFileCount memories',
                    style: TextStyle(
                        color: AppColors.mutedInk,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('Select',
                      style:
                          TextStyle(color: AppColors.softGold, fontSize: 11)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: filesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(color: AppColors.softGold),
                ),
              ),
              error: (error, _) => AlbumEmptyState(
                title: 'Files unavailable',
                message: error.toString(),
                actionLabel: 'Try Again',
                onAction: () =>
                    ref.invalidate(albumMediaFilesProvider(album.id)),
              ),
              data: (files) => files.isEmpty
                  ? AlbumEmptyState(
                      title: 'No files yet',
                      message: album.canUpload
                          ? 'Upload the first original-quality photo or video for this album.'
                          : 'Completed uploads will appear here.',
                      actionLabel: album.canUpload ? 'Upload' : null,
                      onAction: album.canUpload
                          ? () => Navigator.pushNamed(context, AppRoutes.upload,
                              arguments: album)
                          : null,
                    )
                  : Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: files.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 3,
                              mainAxisSpacing: 3,
                              childAspectRatio: 1,
                            ),
                            itemBuilder: (context, index) {
                              return GalleryTile(
                                file: files[index],
                                onTap: () => Navigator.pushNamed(
                                    context, AppRoutes.filePreview,
                                    arguments: files[index]),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                        for (final file in files) ...[
                          _FileMetadataRow(
                            file: file,
                            onTap: () => Navigator.pushNamed(
                                context, AppRoutes.filePreview,
                                arguments: file),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Members', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                membersAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child:
                          CircularProgressIndicator(color: AppColors.softGold),
                    ),
                  ),
                  error: (error, _) => AlbumEmptyState(
                    title: 'Members unavailable',
                    message: error.toString(),
                    actionLabel: 'Try Again',
                    onAction: () =>
                        ref.invalidate(albumMembersProvider(album.id)),
                  ),
                  data: (members) => Column(
                    children: [
                      for (final member in members) ...[
                        _MemberRow(
                          member: member,
                          canEditRole: isAdmin &&
                              currentProfile?.id != member.userId &&
                              member.email?.isNotEmpty == true,
                          isSaving: inviteState.isSending,
                          onRoleSelected: (role) {
                            final email = member.email;
                            if (email == null || email.isEmpty) return;
                            ref
                                .read(inviteMemberControllerProvider.notifier)
                                .invite(
                                  albumId: album.id,
                                  email: email,
                                  role: role,
                                );
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                ),
                if (isAdmin) ...[
                  const SizedBox(height: 10),
                  AppCard(
                    child: InviteForm(
                      isSending: inviteState.isSending,
                      successMessage: inviteState.successMessage,
                      errorMessage: inviteState.errorMessage,
                      onInvite: (email, role) {
                        return ref
                            .read(inviteMemberControllerProvider.notifier)
                            .invite(
                              albumId: album.id,
                              email: email,
                              role: role,
                            );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _FileMetadataRow extends StatelessWidget {
  const _FileMetadataRow({
    required this.file,
    required this.onTap,
  });

  final MediaFile file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.creamLine, width: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                file.isVideo ? Icons.movie_outlined : Icons.image_outlined,
                color: AppColors.maroon,
                size: 18,
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
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${file.fileSizeLabel} - ${file.mimeType} - ${file.uploadedLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.mutedInk, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppColors.mutedInk, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    this.canEditRole = false,
    this.isSaving = false,
    this.onRoleSelected,
  });

  final AlbumMember member;
  final bool canEditRole;
  final bool isSaving;
  final ValueChanged<String>? onRoleSelected;

  @override
  Widget build(BuildContext context) {
    final normalizedRole = member.role.toLowerCase();

    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.maroonFaint,
            foregroundColor: AppColors.maroon,
            child: Text(
              member.title.substring(0, 1).toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  member.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: AppColors.mutedInk, fontSize: 11),
                ),
              ],
            ),
          ),
          RoleChip(label: member.roleLabel, selected: true),
          if (canEditRole) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              enabled: !isSaving,
              tooltip: 'Change role',
              icon: const Icon(
                Icons.more_horiz,
                color: AppColors.mutedInk,
                size: 18,
              ),
              onSelected: (role) {
                if (role == normalizedRole) return;
                onRoleSelected?.call(role);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'admin', child: Text('Admin')),
                PopupMenuItem(value: 'contributor', child: Text('Contributor')),
                PopupMenuItem(value: 'viewer', child: Text('Viewer')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeaderMeta extends StatelessWidget {
  const _HeaderMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            color: AppColors.warmCream.withValues(alpha: 0.60), size: 12),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                color: AppColors.warmCream.withValues(alpha: 0.60),
                fontSize: 11)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.foreground,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
                color: AppColors.maroon.withValues(alpha: 0.12), width: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foreground, size: 14),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
