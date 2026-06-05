import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/media_preview_repository.dart';

class MediaPreviewImage extends ConsumerWidget {
  const MediaPreviewImage({
    required this.mediaFileId,
    required this.fallback,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String? mediaFileId;
  final Widget fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileId = mediaFileId;
    if (fileId == null || fileId.isEmpty) return fallback;

    final preview = ref.watch(mediaPreviewBytesProvider(fileId));

    return preview.when(
      data: (bytes) => bytes == null
          ? fallback
          : Image.memory(
              bytes,
              fit: fit,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
      loading: () => fallback,
      error: (_, __) => fallback,
    );
  }
}
