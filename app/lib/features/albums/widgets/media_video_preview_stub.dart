import 'package:flutter/material.dart';

class MediaVideoPreview extends StatelessWidget {
  const MediaVideoPreview({
    required this.mediaFileId,
    required this.fallback,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String? mediaFileId;
  final Widget fallback;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) => fallback;
}
