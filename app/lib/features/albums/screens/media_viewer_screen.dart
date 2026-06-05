import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/pressable_scale.dart';
import '../../downloads/providers/download_provider.dart';
import '../models/media_file.dart';
import '../widgets/viewer_photo_page.dart';
import '../widgets/viewer_video_page.dart';

class MediaViewerArgs {
  const MediaViewerArgs({
    required this.files,
    required this.initialIndex,
  });

  final List<MediaFile> files;
  final int initialIndex;
}

class MediaViewerScreen extends ConsumerStatefulWidget {
  const MediaViewerScreen({super.key});

  @override
  ConsumerState<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends ConsumerState<MediaViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  late List<MediaFile> _files;
  bool _initialized = false;

  bool _chromeVisible = true;
  Timer? _hideTimer;

  // PageView physics — switched to NeverScrollable when any photo is zoomed
  ScrollPhysics _pagePhysics = const PageScrollPhysics();

  // Background opacity during swipe-down drag
  double _bgOpacity = 1.0;

  @override
  void initState() {
    super.initState();
    _resetHideTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is MediaViewerArgs) {
      _files = args.files;
      _currentIndex = args.initialIndex;
      _pageController = PageController(initialPage: _currentIndex);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    if (_initialized) _pageController.dispose();
    super.dispose();
  }

  void _resetHideTimer() {
    _hideTimer?.cancel();
    if (mounted && !_chromeVisible) setState(() => _chromeVisible = true);
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _chromeVisible = false);
    });
  }

  void _onInteraction() => _resetHideTimer();

  void _onScaleChanged(double scale) {
    final newPhysics = scale > 1.0
        ? const NeverScrollableScrollPhysics()
        : const PageScrollPhysics();
    if (newPhysics.runtimeType != _pagePhysics.runtimeType) {
      setState(() => _pagePhysics = newPhysics);
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _resetHideTimer();
  }

  void _onDragOffsetChanged(double offset) {
    final opacity = (1.0 - (offset / 300)).clamp(0.15, 1.0);
    if ((opacity - _bgOpacity).abs() > 0.01) {
      setState(() => _bgOpacity = opacity);
    }
  }

  void _dismiss() => Navigator.of(context).pop();

  void _download() {
    _resetHideTimer();
    if (!_initialized) return;
    ref
        .read(downloadControllerProvider.notifier)
        .download(_files[_currentIndex]);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const SizedBox.shrink();

    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: _bgOpacity),
        body: GestureDetector(
          onTap: _onInteraction,
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              // ── PageView ──────────────────────────────────────────
              PageView.builder(
                controller: _pageController,
                physics: _pagePhysics,
                onPageChanged: _onPageChanged,
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final file = _files[index];
                  final isActive = index == _currentIndex;

                  final Widget content = file.isVideo
                      ? ViewerVideoPage(
                          key: ValueKey(file.id),
                          file: file,
                          onInteraction: _onInteraction,
                        )
                      : ViewerPhotoPage(
                          key: ValueKey(file.id),
                          file: file,
                          onScaleChanged: _onScaleChanged,
                          onInteraction: _onInteraction,
                          onDismiss: _dismiss,
                          onDragOffsetChanged: _onDragOffsetChanged,
                        );

                  // Only the active page carries the Hero tag — this ensures
                  // the reverse-Hero animates back to the correct grid tile.
                  return isActive
                      ? Hero(tag: 'media-${file.id}', child: content)
                      : content;
                },
              ),

              // ── Chrome ───────────────────────────────────────────
              AnimatedOpacity(
                opacity: _chromeVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_chromeVisible,
                  child: Stack(
                    children: [
                      // Top bar
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _TopBar(
                          topPad: topPad,
                          current: _currentIndex + 1,
                          total: _files.length,
                          onClose: _dismiss,
                          onDownload: _download,
                        ),
                      ),
                      // Bottom filename + uploader
                      Positioned(
                        bottom: bottomPad + 16,
                        left: 20,
                        right: 20,
                        child: _BottomInfo(file: _files[_currentIndex]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chrome widgets ────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.topPad,
    required this.current,
    required this.total,
    required this.onClose,
    required this.onDownload,
  });

  final double topPad;
  final int current;
  final int total;
  final VoidCallback onClose;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, topPad + 12, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.55),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Close
          PressableScale(
            onTap: onClose,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 18),
            ),
          ),
          const Spacer(),
          // Counter
          Text(
            '$current of $total',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 14),
          // Download
          PressableScale(
            onTap: onDownload,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.download_outlined,
                  color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomInfo extends StatelessWidget {
  const _BottomInfo({required this.file});
  final MediaFile file;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          file.originalFilename,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'by ${file.uploaderName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 11,
            shadows: const [Shadow(color: Colors.black45, blurRadius: 4)],
          ),
        ),
      ],
    );
  }
}
