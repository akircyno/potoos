import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/errors/app_error.dart';
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
import '../../../core/widgets/poto_mascot.dart';
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
    final filesAsync = ref.watch(albumMediaFilesProvider(album.id));
    final membersAsync = ref.watch(albumMembersProvider(album.id));
    final inviteState = ref.watch(inviteMemberControllerProvider);
    final currentProfile = ref.watch(currentUserProfileProvider);
    final selectionMode = ref.watch(albumSelectionModeProvider(album.id));
    final selectedIds = ref.watch(selectedMediaIdsProvider(album.id));
    final loadedFiles = filesAsync.asData?.value;
    final selectedFiles = loadedFiles
            ?.where((file) => selectedIds.contains(file.id))
            .toList(growable: false) ??
        const <MediaFile>[];
    final hasSelection = selectedFiles.isNotEmpty;
    final canSaveSelection = !selectionMode || hasSelection;
    final filesForSaveAll =
        hasSelection ? selectedFiles : loadedFiles ?? const [];
    final visibleFileCount = loadedFiles?.length ?? album.fileCount;
    final loadedMembers = membersAsync.asData?.value;
    if (loadedMembers != null && loadedMembers.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Album Details')),
        body: AppScreen(
          children: [
            AlbumEmptyState(
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

    final visibleMemberCount = loadedMembers?.length ?? album.memberCount;
    final currentMember = _currentMember(loadedMembers, currentProfile?.id);
    final effectiveRole = currentMember?.role ?? album.role;
    final effectiveRoleLabel = _roleLabel(effectiveRole);
    final canUpload = _canUploadRole(effectiveRole);
    final isAdmin = _canManageRole(effectiveRole);

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
                        label: 'Your role: $effectiveRoleLabel'),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                if (canUpload) ...[
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
                    label: selectionMode
                        ? hasSelection
                            ? 'Save ${selectedFiles.length}'
                            : 'Save Selected'
                        : 'Save All',
                    icon: Icons.save_alt,
                    color: AppColors.goldFaint,
                    foreground: AppColors.softGold,
                    onTap: canSaveSelection
                        ? () => Navigator.pushNamed(
                              context,
                              AppRoutes.saveAll,
                              arguments: SaveAllArgs(
                                album: album,
                                files: filesForSaveAll,
                              ),
                            )
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  label: 'Members',
                  icon: Icons.group_outlined,
                  color: AppColors.maroonFaint,
                  foreground: AppColors.maroon,
                  onTap: () => Navigator.pushNamed(
                    context,
                    AppRoutes.members,
                    arguments: album,
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
                    selectionMode
                        ? '${selectedIds.length} selected'
                        : '$visibleFileCount memories',
                    style: TextStyle(
                        color: AppColors.mutedInk,
                        fontSize: 11,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton(
                  onPressed: loadedFiles == null || loadedFiles.isEmpty
                      ? null
                      : () {
                          final selectionNotifier = ref.read(
                              albumSelectionModeProvider(album.id).notifier);
                          final selectedNotifier = ref.read(
                              selectedMediaIdsProvider(album.id).notifier);
                          final nextMode = !selectionMode;
                          selectionNotifier.setEnabled(nextMode);
                          if (!nextMode) selectedNotifier.clear();
                        },
                  child: Text(selectionMode ? 'Done' : 'Select',
                      style: const TextStyle(
                          color: AppColors.softGold, fontSize: 11)),
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
                message: AppError.messageFor(error),
                expression: PotoExpression.error,
                actionLabel: 'Try Again',
                onAction: () =>
                    ref.invalidate(albumMediaFilesProvider(album.id)),
              ),
              data: (files) => files.isEmpty
                  ? AlbumEmptyState(
                      title: 'No files yet',
                      message: canUpload
                          ? 'Upload the first original-quality photo or video for this album.'
                          : 'Completed uploads will appear here.',
                      actionLabel: canUpload ? 'Upload' : null,
                      onAction: canUpload
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
                                selectionMode: selectionMode,
                                selected: selectedIds.contains(files[index].id),
                                onTap: selectionMode
                                    ? () => _toggleSelectedFile(
                                          ref,
                                          albumId: album.id,
                                          fileId: files[index].id,
                                        )
                                    : () => Navigator.pushNamed(
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
                            selectionMode: selectionMode,
                            selected: selectedIds.contains(file.id),
                            onTap: selectionMode
                                ? () => _toggleSelectedFile(
                                      ref,
                                      albumId: album.id,
                                      fileId: file.id,
                                    )
                                : () => Navigator.pushNamed(
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
                    message: AppError.messageFor(error),
                    expression: PotoExpression.error,
                    actionLabel: 'Try Again',
                    onAction: () =>
                        ref.invalidate(albumMembersProvider(album.id)),
                  ),
                  data: (members) => Column(
                    children: [
                      for (final member in members) ...[
                        _MemberRow(
                          member: member,
                          canManageMember:
                              isAdmin && currentProfile?.id != member.userId,
                          canEditRole: member.email?.isNotEmpty == true,
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
                          onRemoveSelected: () => _confirmRemoveMember(
                            context,
                            ref,
                            album: album,
                            member: member,
                          ),
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

  Future<void> _confirmRemoveMember(
    BuildContext context,
    WidgetRef ref, {
    required Album album,
    required AlbumMember member,
  }) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Remove member?'),
            content: Text('Remove ${member.title} from ${album.name}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.maroon,
                  foregroundColor: AppColors.white,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !context.mounted) return;

    await ref.read(inviteMemberControllerProvider.notifier).remove(
          albumId: album.id,
          member: member,
        );
  }

  void _toggleSelectedFile(
    WidgetRef ref, {
    required String albumId,
    required String fileId,
  }) {
    ref.read(selectedMediaIdsProvider(albumId).notifier).toggle(fileId);
  }

  AlbumMember? _currentMember(List<AlbumMember>? members, String? profileId) {
    if (members == null || profileId == null || profileId.isEmpty) return null;

    for (final member in members) {
      if (member.userId == profileId) return member;
    }

    return null;
  }

  String _roleLabel(String role) {
    if (role.isEmpty) return 'Viewer';
    return '${role[0].toUpperCase()}${role.substring(1).toLowerCase()}';
  }

  bool _canUploadRole(String role) {
    final normalized = role.toLowerCase();
    return normalized == 'admin' || normalized == 'contributor';
  }

  bool _canManageRole(String role) {
    return role.toLowerCase() == 'admin';
  }
}

class _FileMetadataRow extends StatelessWidget {
  const _FileMetadataRow({
    required this.file,
    required this.onTap,
    this.selectionMode = false,
    this.selected = false,
  });

  final MediaFile file;
  final VoidCallback onTap;
  final bool selectionMode;
  final bool selected;

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
              if (selectionMode)
                Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: selected ? AppColors.maroon : AppColors.mutedInk,
                  size: 18,
                )
              else
                Icon(
                  fileTypeIcon(file),
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
              if (!selectionMode)
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
    this.canManageMember = false,
    this.canEditRole = false,
    this.isSaving = false,
    this.onRoleSelected,
    this.onRemoveSelected,
  });

  final AlbumMember member;
  final bool canManageMember;
  final bool canEditRole;
  final bool isSaving;
  final ValueChanged<String>? onRoleSelected;
  final VoidCallback? onRemoveSelected;

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
          if (canManageMember) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              enabled: !isSaving,
              tooltip: 'Manage member',
              icon: const Icon(
                Icons.more_horiz,
                color: AppColors.mutedInk,
                size: 18,
              ),
              onSelected: (value) {
                if (value == 'remove') {
                  onRemoveSelected?.call();
                  return;
                }

                if (value == normalizedRole) return;
                onRoleSelected?.call(value);
              },
              itemBuilder: (context) => [
                if (canEditRole) ...const [
                  PopupMenuItem(value: 'admin', child: Text('Admin')),
                  PopupMenuItem(
                      value: 'contributor', child: Text('Contributor')),
                  PopupMenuItem(value: 'viewer', child: Text('Viewer')),
                  PopupMenuDivider(),
                ],
                const PopupMenuItem(
                  value: 'remove',
                  child: Text('Remove member'),
                ),
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
      color: onTap == null ? AppColors.creamLine : color,
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
              Icon(icon,
                  color: onTap == null ? AppColors.mutedInk : foreground,
                  size: 14),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: onTap == null ? AppColors.mutedInk : foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}
