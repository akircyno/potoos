import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../models/media_file.dart';

class GalleryTile extends StatelessWidget {
  const GalleryTile({
    required this.file,
    required this.onTap,
    this.selectionMode = false,
    this.selected = false,
    super.key,
  });

  final MediaFile file;
  final VoidCallback onTap;
  final bool selectionMode;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final palettes = [
      const [Color(0xFFD4A0AC), Color(0xFF8C2840)],
      const [Color(0xFFA0BCD4), Color(0xFF2C5880)],
      const [Color(0xFFD4C4A0), Color(0xFF8C7A30)],
      const [Color(0xFFA0D4B0), Color(0xFF2C8040)],
      const [Color(0xFFC4A0D4), Color(0xFF6B2C80)],
    ];
    final gradient = palettes[file.id.hashCode.abs() % palettes.length];

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: gradient,
                  ),
                ),
                child: Icon(
                  Icons.photo_outlined,
                  color: AppColors.white.withValues(alpha: 0.50),
                  size: 18,
                ),
              ),
            ),
            if (file.isVideo)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow, size: 8, color: AppColors.white),
                      SizedBox(width: 2),
                      Text('Video',
                          style:
                              TextStyle(color: AppColors.white, fontSize: 9)),
                    ],
                  ),
                ),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.softGold.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'OQ',
                  style: TextStyle(
                    color: AppColors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            if (selectionMode)
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.maroon
                        : AppColors.white.withValues(alpha: 0.80),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 1),
                  ),
                  child: selected
                      ? const Icon(Icons.check,
                          color: AppColors.white, size: 12)
                      : null,
                ),
              ),
            if (selected)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.maroon, width: 3),
                  ),
                ),
              ),
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Text(
                file.originalFilename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
