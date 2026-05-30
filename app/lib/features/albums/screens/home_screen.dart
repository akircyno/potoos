import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/litrato_header.dart';
import '../../../core/widgets/memory_stat_card.dart';
import '../../../core/widgets/notification_item.dart';
import '../../../core/widgets/quality_promise_card.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/album.dart';
import '../providers/album_provider.dart';
import '../widgets/album_card.dart';
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
      body: SafeArea(
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
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => setState(() => currentIndex = index),
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.warmCream,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.photo_album_outlined),
            selectedIcon: Icon(Icons.photo_album),
            label: 'Albums',
          ),
          NavigationDestination(
            icon: Icon(Icons.mail_outline),
            selectedIcon: Icon(Icons.mail),
            label: 'Invites',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Activity',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
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
    final albums = albumsAsync.when<List<Album>>(
      data: (albums) => albums,
      loading: () => const [],
      error: (_, __) => const [],
    );
    final fileCount =
        albums.fold<int>(0, (total, album) => total + album.fileCount);
    final memberCount =
        albums.fold<int>(0, (total, album) => total + album.memberCount);

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 86),
          children: [
            const LitratoHeader(),
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
                          'Invite-only spaces, sorted by recent activity.',
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
                    child: CircularProgressIndicator(color: AppColors.softGold),
                  ),
                ),
                error: (error, _) => AlbumEmptyState(
                  title: 'Albums unavailable',
                  message: error.toString(),
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
          ],
        ),
        Positioned(
          right: 20,
          bottom: 18,
          child: FloatingActionButton(
            tooltip: 'Create album',
            backgroundColor: AppColors.maroon,
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

class _InvitesTab extends StatelessWidget {
  const _InvitesTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Text('Invites', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 8),
        const Text(
          'Invite people with the right level of access. Viewer is safest by default.',
          style: TextStyle(color: AppColors.mutedInk, height: 1.4),
        ),
        const SizedBox(height: 14),
        const AppCard(
          child: Text(
            'Open an album to add members and choose their role.',
            style: TextStyle(color: AppColors.mutedInk, height: 1.4),
          ),
        ),
      ],
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
          subtitle: 'Recent updates from your albums',
          showAvatar: false,
        ),
        const SizedBox(height: 14),
        albumsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.softGold),
            ),
          ),
          error: (error, _) => AlbumEmptyState(
            title: 'Activity unavailable',
            message: error.toString(),
            actionLabel: 'Try Again',
            onAction: () => ref.invalidate(albumListProvider),
          ),
          data: (albums) {
            if (albums.isEmpty) {
              return const AlbumEmptyState(
                title: 'No activity yet',
                message:
                    'Create an album and upload originals to start building activity.',
              );
            }

            return Column(
              children: [
                for (final album in albums) ...[
                  NotificationItem(
                    title: album.fileCount > 0
                        ? '${album.fileCount} originals protected'
                        : 'Album ready',
                    message:
                        '${album.name} has ${album.memberCount} member${album.memberCount == 1 ? '' : 's'}. Your role is ${album.role}.',
                    time: album.updatedLabel,
                    unread: album.fileCount > 0,
                  ),
                  const SizedBox(height: 10),
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
    final displayName = profile?.displayName?.isNotEmpty == true
        ? profile!.displayName!
        : 'LitratoLink User';
    final email =
        profile?.email.isNotEmpty == true ? profile!.email : 'user@example.com';
    final initials = _initialsFor(displayName);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Text('Profile', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 14),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppColors.maroon,
                child: Text(initials,
                    style: const TextStyle(color: AppColors.white)),
              ),
              const SizedBox(height: 14),
              Text(displayName, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(email, style: const TextStyle(color: AppColors.mutedInk)),
              const SizedBox(height: 18),
              AppButton(
                label: 'Log out',
                icon: Icons.logout,
                secondary: true,
                onPressed: () async {
                  await ref.read(authControllerProvider.notifier).signOut();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, AppRoutes.login);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _initialsFor(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'LL';
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }

    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }
}
