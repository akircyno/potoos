import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_card.dart';
import '../models/album.dart';

class AlbumCard extends StatelessWidget {
  const AlbumCard({
    required this.album,
    required this.onTap,
    super.key,
  });

  final Album album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Cover ─────────────────────────────────────────────────────
          SizedBox(
            height: 116,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background: thumbnail photo or gradient fallback
                  if (album.coverThumbnailUrl != null)
                    Image.network(
                      album.coverThumbnailUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _GradientCover(album: album),
                    )
                  else
                    _GradientCover(album: album),

                  // Dark scrim so text is always readable over photos
                  if (album.coverThumbnailUrl != null)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.08),
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),

                  // Role badge
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.20),
                        border: Border.all(
                            color: AppColors.white.withValues(alpha: 0.30),
                            width: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        album.role.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 10,
                          letterSpacing: 0.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  // Album name
                  Positioned(
                    left: 16,
                    bottom: 14,
                    right: 16,
                    child: Text(
                      album.name,
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.white,
                        shadows: const [
                          Shadow(
                            color: Colors.black26,
                            offset: Offset(0, 1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Meta row ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.photo_outlined,
                    color: AppColors.brightGold, size: 14),
                const SizedBox(width: 4),
                Text('${album.fileCount} originals',
                    style: const TextStyle(
                        color: AppColors.mutedInk, fontSize: 12)),
                const SizedBox(width: 12),
                const Icon(Icons.group_outlined,
                    color: AppColors.brightGold, size: 14),
                const SizedBox(width: 4),
                Text('${album.memberCount} members',
                    style: const TextStyle(
                        color: AppColors.mutedInk, fontSize: 12)),
                const Spacer(),
                Text(album.updatedLabel,
                    style: const TextStyle(
                        color: AppColors.mutedInk, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientCover extends StatelessWidget {
  const _GradientCover({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: album.coverColors,
            ),
          ),
        ),
        Opacity(
          opacity: 0.08,
          child: GridPaper(
            color: AppColors.white,
            divisions: 1,
            interval: 16,
            subdivisions: 1,
          ),
        ),
      ],
    );
  }
}
