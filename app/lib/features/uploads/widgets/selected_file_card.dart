import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_card.dart';
import '../models/upload_file.dart';

class SelectedFileCard extends StatelessWidget {
  const SelectedFileCard({
    required this.file,
    super.key,
  });

  final UploadFile file;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.warmCream,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              file.fileType == 'video' ? Icons.movie_outlined : Icons.image_outlined,
              color: AppColors.maroon,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  '${file.sizeLabel} - ${file.mimeType} - ${file.fileType}',
                  style: const TextStyle(color: AppColors.mutedInk),
                ),
                const SizedBox(height: 4),
                Text(
                  file.localPath ?? 'Browser-selected file',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.mutedInk, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
