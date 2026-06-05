import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/media_preview_repository.dart';

class MediaPreviewImage extends ConsumerWidget {
  const MediaPreviewImage({
    required this.mediaFileId,
    required this.fallback,
    this.thumbnailUrl,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String? mediaFileId;
  final Widget fallback;
  final String? thumbnailUrl;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final networkFallback = _networkFallback();
    final fileId = mediaFileId;
    if (fileId == null || fileId.isEmpty) return networkFallback;

    final preview = ref.watch(mediaPreviewBytesProvider(fileId));

    return preview.when(
      data: (bytes) => bytes == null
          ? networkFallback
          : Image.memory(
              bytes,
              fit: fit,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
      loading: () => networkFallback,
      error: (_, __) => networkFallback,
    );
  }

  Widget _networkFallback() {
    final url = thumbnailUrl?.trim();
    if (url == null || url.isEmpty) return fallback;

    return Image.network(
      url,
      fit: fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}
