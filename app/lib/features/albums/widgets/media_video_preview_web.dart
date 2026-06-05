// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';

class MediaVideoPreview extends ConsumerStatefulWidget {
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
  ConsumerState<MediaVideoPreview> createState() => _MediaVideoPreviewState();
}

class _MediaVideoPreviewState extends ConsumerState<MediaVideoPreview> {
  String? _viewType;

  @override
  void initState() {
    super.initState();
    _registerVideoView();
  }

  @override
  void didUpdateWidget(MediaVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaFileId != widget.mediaFileId) {
      _registerVideoView();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewType = _viewType;
    if (viewType == null) return widget.fallback;

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.fallback,
        HtmlElementView(viewType: viewType),
      ],
    );
  }

  void _registerVideoView() {
    final mediaFileId = widget.mediaFileId?.trim();
    final supabaseService = ref.read(supabaseServiceProvider);
    final session = supabaseService.currentSession;

    if (mediaFileId == null ||
        mediaFileId.isEmpty ||
        !supabaseService.isConfigured ||
        session == null) {
      setState(() => _viewType = null);
      return;
    }

    final viewType =
        'potoos-video-preview-$mediaFileId-${DateTime.now().microsecondsSinceEpoch}';
    final uri = Uri.parse(
      '${supabaseService.env.supabaseUrl}/functions/v1/stream-media-preview',
    ).replace(
      queryParameters: {
        'media_file_id': mediaFileId,
        'access_token': session.accessToken,
      },
    );

    final video = html.VideoElement()
      ..src = uri.toString()
      ..muted = true
      ..autoplay = true
      ..loop = false
      ..controls = false
      ..preload = 'metadata'
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true');

    video.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = _objectFitCss(widget.fit)
      ..border = '0'
      ..display = 'block'
      ..pointerEvents = 'none';

    video.onCanPlay.first.then((_) {
      video.pause();
      video.currentTime = 0;
    });

    ui_web.platformViewRegistry.registerViewFactory(viewType, (_) => video);

    setState(() => _viewType = viewType);
  }

  String _objectFitCss(BoxFit fit) {
    return switch (fit) {
      BoxFit.contain => 'contain',
      BoxFit.fill => 'fill',
      BoxFit.fitHeight => 'contain',
      BoxFit.fitWidth => 'contain',
      BoxFit.none => 'none',
      BoxFit.scaleDown => 'scale-down',
      BoxFit.cover => 'cover',
    };
  }
}
