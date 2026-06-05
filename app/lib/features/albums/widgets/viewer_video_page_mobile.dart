import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

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
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    final supabase = ref.read(supabaseServiceProvider);
    final session = supabase.currentSession;
    if (session == null || !supabase.isConfigured) return;

    final uri = Uri.parse(
      '${supabase.env.supabaseUrl}/functions/v1/stream-media-preview',
    ).replace(queryParameters: {
      'media_file_id': widget.file.id,
      'access_token': session.accessToken,
    });

    final controller = VideoPlayerController.networkUrl(uri);
    await controller.initialize();
    if (!mounted) {
      controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _initialized = true;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    widget.onInteraction();
    final c = _controller;
    if (c == null) return;
    setState(() {
      c.value.isPlaying ? c.pause() : c.play();
    });
  }

  void _toggleMute() {
    widget.onInteraction();
    final c = _controller;
    if (c == null) return;
    setState(() {
      _muted = !_muted;
      c.setVolume(_muted ? 0 : 1);
    });
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.brightGold,
          strokeWidth: 2,
        ),
      );
    }

    final c = _controller!;

    return GestureDetector(
      onTap: _togglePlay,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: c.value.aspectRatio,
              child: VideoPlayer(c),
            ),
          ),
          // Centre play/pause overlay
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: c,
            builder: (_, value, __) {
              if (value.isPlaying) return const SizedBox.shrink();
              return Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.55),
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 36,
                ),
              );
            },
          ),
          // Bottom controls bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _MobileVideoControls(
              controller: c,
              muted: _muted,
              onTogglePlay: _togglePlay,
              onToggleMute: _toggleMute,
              onSeek: (pos) {
                widget.onInteraction();
                c.seekTo(pos);
              },
              fmt: _fmt,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileVideoControls extends StatelessWidget {
  const _MobileVideoControls({
    required this.controller,
    required this.muted,
    required this.onTogglePlay,
    required this.onToggleMute,
    required this.onSeek,
    required this.fmt,
  });

  final VideoPlayerController controller;
  final bool muted;
  final VoidCallback onTogglePlay;
  final VoidCallback onToggleMute;
  final ValueChanged<Duration> onSeek;
  final String Function(Duration) fmt;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (_, value, __) {
        final position = value.position;
        final duration = value.duration;
        final progress = duration.inMilliseconds > 0
            ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
            : 0.0;

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
                icon: Icon(
                  value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 22,
                ),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              Text(
                fmt(position),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
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
                        milliseconds: (v * duration.inMilliseconds).round())),
                  ),
                ),
              ),
              Text(
                fmt(duration),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w500),
              ),
              IconButton(
                onPressed: onToggleMute,
                icon: Icon(
                  muted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 20,
                ),
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        );
      },
    );
  }
}
