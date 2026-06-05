// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/services/supabase_service.dart';
import '../models/media_file.dart';

class ViewerVideoPage extends ConsumerStatefulWidget {
  const ViewerVideoPage({
    required this.file,
    required this.onInteraction,
    super.key,
  });

  final MediaFile file;
  final VoidCallback onInteraction;

  @override
  ConsumerState<ViewerVideoPage> createState() => _ViewerVideoPageState();
}

class _ViewerVideoPageState extends ConsumerState<ViewerVideoPage> {
  html.VideoElement? _video;
  String? _viewType;
  bool _playing = false;
  bool _muted = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _registerVideo();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _video?.pause();
    super.dispose();
  }

  void _registerVideo() {
    final supabase = ref.read(supabaseServiceProvider);
    final session = supabase.currentSession;
    if (session == null || !supabase.isConfigured) return;

    final viewType =
        'potoos-viewer-${widget.file.id}-${DateTime.now().microsecondsSinceEpoch}';

    final uri = Uri.parse(
      '${supabase.env.supabaseUrl}/functions/v1/stream-media-preview',
    ).replace(queryParameters: {
      'media_file_id': widget.file.id,
      'access_token': session.accessToken,
    });

    final video = html.VideoElement()
      ..src = uri.toString()
      ..muted = false
      ..autoplay = false
      ..controls = false
      ..preload = 'metadata'
      ..setAttribute('playsinline', 'true')
      ..setAttribute('webkit-playsinline', 'true');

    video.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'contain'
      ..border = '0'
      ..display = 'block'
      ..pointerEvents = 'none';

    video.onLoadedMetadata.listen((_) {
      if (mounted) {
        setState(() => _duration =
            Duration(milliseconds: (video.duration * 1000).round()));
      }
    });

    ui_web.platformViewRegistry.registerViewFactory(viewType, (_) => video);

    setState(() {
      _video = video;
      _viewType = viewType;
    });
  }

  void _startTimer() {
    _progressTimer?.cancel();
    _progressTimer =
        Timer.periodic(const Duration(milliseconds: 250), (_) {
      final v = _video;
      if (v != null && mounted) {
        setState(() => _position =
            Duration(milliseconds: (v.currentTime * 1000).round()));
      }
    });
  }

  void _stopTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  void _togglePlay() {
    widget.onInteraction();
    final v = _video;
    if (v == null) return;
    if (_playing) {
      v.pause();
      _stopTimer();
    } else {
      v.play();
      _startTimer();
    }
    setState(() => _playing = !_playing);
  }

  void _toggleMute() {
    widget.onInteraction();
    final v = _video;
    if (v == null) return;
    setState(() {
      _muted = !_muted;
      v.muted = _muted;
    });
  }

  void _seek(Duration position) {
    widget.onInteraction();
    final v = _video;
    if (v == null) return;
    v.currentTime = position.inMilliseconds / 1000.0;
    setState(() => _position = position);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final viewType = _viewType;
    if (viewType == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.brightGold,
          strokeWidth: 2,
        ),
      );
    }

    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds)
            .clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: HtmlElementView(viewType: viewType)),
          if (!_playing)
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.55),
              ),
              child: const Icon(
                  Icons.play_arrow, color: Colors.white, size: 36),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _WebVideoControls(
              playing: _playing,
              muted: _muted,
              position: _position,
              duration: _duration,
              progress: progress,
              onTogglePlay: _togglePlay,
              onToggleMute: _toggleMute,
              onSeek: _seek,
              fmt: _fmt,
            ),
          ),
        ],
      ),
    );
  }
}

class _WebVideoControls extends StatelessWidget {
  const _WebVideoControls({
    required this.playing,
    required this.muted,
    required this.position,
    required this.duration,
    required this.progress,
    required this.onTogglePlay,
    required this.onToggleMute,
    required this.onSeek,
    required this.fmt,
  });

  final bool playing;
  final bool muted;
  final Duration position;
  final Duration duration;
  final double progress;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleMute;
  final ValueChanged<Duration> onSeek;
  final String Function(Duration) fmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.65),
          ],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onTogglePlay,
            icon: Icon(playing ? Icons.pause : Icons.play_arrow,
                color: Colors.white, size: 22),
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          Text(fmt(position),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape:
                    const RoundSliderOverlayShape(overlayRadius: 12),
                activeTrackColor: Colors.white,
                inactiveTrackColor:
                    Colors.white.withValues(alpha: 0.35),
                thumbColor: Colors.white,
                overlayColor: Colors.white.withValues(alpha: 0.18),
              ),
              child: Slider(
                value: progress,
                onChanged: (v) => onSeek(Duration(
                    milliseconds:
                        (v * duration.inMilliseconds).round())),
              ),
            ),
          ),
          Text(fmt(duration),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
          IconButton(
            onPressed: onToggleMute,
            icon: Icon(muted ? Icons.volume_off : Icons.volume_up,
                color: Colors.white, size: 20),
            padding: EdgeInsets.zero,
            constraints:
                const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}
