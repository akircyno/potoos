# Media Viewer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a full-screen photo/video viewer that opens from the album gallery with a Hero animation, supports pinch/zoom, swipe navigation, swipe-down dismiss, inline video playback, and a download button.

**Architecture:** New `MediaViewerScreen` uses `PageView` for left/right swipe navigation. Each page is either `ViewerPhotoPage` (InteractiveViewer + zoom) or `ViewerVideoPage` (video_player on mobile, HtmlVideoElement on web). A `Hero(tag: 'media-${file.id}')` on the active page connects the grid thumbnail to the full-screen view. Chrome (back button, counter, download, filename) auto-hides after 2s.

**Tech Stack:** Flutter, Riverpod, `video_player ^2.9.2`, existing `supabase_flutter`, `InteractiveViewer`, `PageView`, `AnimationController`, `Matrix4Tween`

---

## File Map

### New files
| Path | Responsibility |
|---|---|
| `app/lib/features/albums/screens/media_viewer_screen.dart` | Screen, PageView, Hero management, chrome overlay, download |
| `app/lib/features/albums/widgets/viewer_photo_page.dart` | InteractiveViewer, zoom, double-tap, swipe-down dismiss |
| `app/lib/features/albums/widgets/viewer_video_page.dart` | Conditional export dispatcher |
| `app/lib/features/albums/widgets/viewer_video_page_mobile.dart` | video_player controller + custom controls |
| `app/lib/features/albums/widgets/viewer_video_page_web.dart` | HtmlVideoElement + custom controls |

### Modified files
| Path | Change |
|---|---|
| `app/pubspec.yaml` | Add `video_player: ^2.9.2` |
| `app/lib/app/routes.dart` | Add `mediaViewer` constant + zero-duration route + import |
| `app/lib/features/albums/widgets/gallery_tile.dart` | Wrap `Material` with `Hero(tag: 'media-${file.id}')` |
| `app/lib/features/albums/screens/album_details_screen.dart` | Change tile `onTap` (line 444) to push `/media-viewer` |

---

## Task 1 — Add video_player dependency

**Files:**
- Modify: `app/pubspec.yaml`

- [ ] **Add the dependency**

Open `app/pubspec.yaml`. In the `dependencies:` block, after `url_launcher: ^6.3.1`, add:

```yaml
  video_player: ^2.9.2
```

The block should look like:
```yaml
dependencies:
  archive: ^4.0.9
  crypto: ^3.0.7
  dio: ^5.9.2
  file_picker: ^11.0.2
  flutter:
    sdk: flutter
  flutter_dotenv: ^6.0.1
  flutter_riverpod: ^3.3.1
  flutter_svg: ^2.0.10+1
  sentry_flutter: ^8.13.2
  shared_preferences: ^2.5.3
  supabase_flutter: ^2.12.4
  url_launcher: ^6.3.1
  video_player: ^2.9.2
```

- [ ] **Fetch packages** (run from `app/` directory)

```
flutter pub get
```

Expected: resolves `video_player` and its transitive deps without conflicts.

- [ ] **Commit**

```
git add app/pubspec.yaml app/pubspec.lock
git commit -m "Add video_player dependency"
```

---

## Task 2 — Route constant, MediaViewerArgs, zero-duration route

**Files:**
- Modify: `app/lib/app/routes.dart`

- [ ] **Add import and constant**

In `app/lib/app/routes.dart`, add the import at the top and the constant:

```dart
import '../features/albums/screens/media_viewer_screen.dart';
```

In the `AppRoutes` constants block, add after `members`:
```dart
static const mediaViewer = '/media-viewer';
```

- [ ] **Add the route page case**

In `generateRoute`, in the `switch (settings.name)` block, add before `default:`:
```dart
case mediaViewer:
  page = const MediaViewerScreen();
```

- [ ] **Add zero-duration route builder**

Add this private static method to `AppRoutes` (after `_slideUpRoute`):

```dart
static Route<dynamic> _heroRoute(Widget page, RouteSettings settings) =>
    PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      ),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
```

- [ ] **Wire the route to use the hero builder**

Update the `return switch` at the bottom of `generateRoute`:

```dart
return switch (settings.name) {
  splash || login || onboarding => _fadeRoute(page, settings),
  upload || saveAll || createAlbum => _slideUpRoute(page, settings),
  mediaViewer => _heroRoute(page, settings),
  _ => _slideRightRoute(page, settings),
};
```

- [ ] **Commit**

```
git add app/lib/app/routes.dart
git commit -m "Add /media-viewer route with zero-duration Hero transition"
```

---

## Task 3 — Hero tag on GalleryTile

**Files:**
- Modify: `app/lib/features/albums/widgets/gallery_tile.dart`

- [ ] **Wrap Material widget in Hero**

In `GalleryTile.build()`, the `return` statement currently returns a `Material(...)`. Wrap it:

```dart
@override
Widget build(BuildContext context) {
  // ... existing palette/fallback setup unchanged ...

  return Hero(
    tag: 'media-${file.id}',
    child: Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(0),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            // ... all existing Stack children unchanged ...
          ],
        ),
      ),
    ),
  );
}
```

No other changes to this file.

- [ ] **Commit**

```
git add app/lib/features/albums/widgets/gallery_tile.dart
git commit -m "Add Hero tag to GalleryTile for media viewer transition"
```

---

## Task 4 — ViewerVideoPage mobile (video_player)

**Files:**
- Create: `app/lib/features/albums/widgets/viewer_video_page_mobile.dart`

- [ ] **Create the file**

```dart
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
```

- [ ] **Commit**

```
git add app/lib/features/albums/widgets/viewer_video_page_mobile.dart
git commit -m "Add ViewerVideoPage mobile (video_player)"
```

---

## Task 5 — ViewerVideoPage web (HtmlVideoElement)

**Files:**
- Create: `app/lib/features/albums/widgets/viewer_video_page_web.dart`

- [ ] **Create the file**

```dart
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
```

- [ ] **Commit**

```
git add app/lib/features/albums/widgets/viewer_video_page_web.dart
git commit -m "Add ViewerVideoPage web (HtmlVideoElement with controls)"
```

---

## Task 6 — ViewerVideoPage conditional dispatcher

**Files:**
- Create: `app/lib/features/albums/widgets/viewer_video_page.dart`

- [ ] **Create the conditional export**

```dart
export 'viewer_video_page_mobile.dart'
    if (dart.library.html) 'viewer_video_page_web.dart';
```

- [ ] **Commit**

```
git add app/lib/features/albums/widgets/viewer_video_page.dart
git commit -m "Add ViewerVideoPage conditional export dispatcher"
```

---

## Task 7 — ViewerPhotoPage

**Files:**
- Create: `app/lib/features/albums/widgets/viewer_photo_page.dart`

- [ ] **Create the file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/media_file.dart';
import 'media_preview_image.dart';

class ViewerPhotoPage extends ConsumerStatefulWidget {
  const ViewerPhotoPage({
    required this.file,
    required this.onScaleChanged,
    required this.onInteraction,
    required this.onDismiss,
    required this.onDragOffsetChanged,
    super.key,
  });

  final MediaFile file;
  /// Called when scale changes so parent can toggle PageView physics.
  final ValueChanged<double> onScaleChanged;
  /// Called on any user interaction to reset the chrome hide timer.
  final VoidCallback onInteraction;
  /// Called when swipe-down threshold (100px) is exceeded.
  final VoidCallback onDismiss;
  /// Called during swipe-down drag to let parent fade background.
  final ValueChanged<double> onDragOffsetChanged;

  @override
  ConsumerState<ViewerPhotoPage> createState() => _ViewerPhotoPageState();
}

class _ViewerPhotoPageState extends ConsumerState<ViewerPhotoPage>
    with SingleTickerProviderStateMixin {
  final _transformController = TransformationController();
  late final AnimationController _animController;
  Animation<Matrix4>? _animation;

  double _scale = 1.0;
  Offset _lastDoubleTapOffset = Offset.zero;
  double _dragY = 0.0;
  bool _draggingDown = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        final anim = _animation;
        if (anim != null) _transformController.value = anim.value;
      });
  }

  @override
  void dispose() {
    _transformController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── Scale handling ────────────────────────────────────────────────────────

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    widget.onInteraction();
    final newScale =
        _transformController.value.getMaxScaleOnAxis().clamp(1.0, 5.0);
    if ((newScale - _scale).abs() > 0.05) {
      setState(() => _scale = newScale);
      widget.onScaleChanged(_scale);
    }
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    final newScale =
        _transformController.value.getMaxScaleOnAxis().clamp(1.0, 5.0);
    if (newScale != _scale) {
      setState(() => _scale = newScale);
      widget.onScaleChanged(_scale);
    }
  }

  // ── Double-tap zoom ───────────────────────────────────────────────────────

  void _onDoubleTapDown(TapDownDetails details) {
    _lastDoubleTapOffset = details.localPosition;
  }

  void _onDoubleTap() {
    widget.onInteraction();
    if (_scale > 1.0) {
      _animateTo(Matrix4.identity());
      setState(() => _scale = 1.0);
      widget.onScaleChanged(1.0);
    } else {
      const targetScale = 2.5;
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) return;
      final size = renderBox.size;
      final cx = size.width / 2;
      final cy = size.height / 2;
      // Scale centred on widget centre (spec: toggle 1x ↔ 2.5x)
      final matrix = Matrix4.identity()
        ..translate(cx, cy)
        ..scale(targetScale, targetScale, 1.0)
        ..translate(-cx, -cy);
      _animateTo(matrix);
      setState(() => _scale = targetScale);
      widget.onScaleChanged(targetScale);
    }
  }

  void _animateTo(Matrix4 target) {
    _animation = Matrix4Tween(
      begin: _transformController.value,
      end: target,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward(from: 0);
  }

  // ── Swipe-down dismiss (enabled only at 1x) ───────────────────────────────

  void _onVerticalDragStart(DragStartDetails _) {
    if (_scale > 1.0) return;
    setState(() {
      _draggingDown = true;
      _dragY = 0;
    });
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (!_draggingDown) return;
    setState(() => _dragY += details.delta.dy);
    widget.onDragOffsetChanged(_dragY.abs());
  }

  void _onVerticalDragEnd(DragEndDetails _) {
    if (!_draggingDown) return;
    if (_dragY > 100) {
      widget.onDismiss();
    } else {
      setState(() {
        _dragY = 0;
        _draggingDown = false;
      });
      widget.onDragOffsetChanged(0);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: _onDoubleTapDown,
      onDoubleTap: _onDoubleTap,
      onTap: widget.onInteraction,
      onVerticalDragStart: _onVerticalDragStart,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: Transform.translate(
        offset: Offset(0, _draggingDown ? _dragY : 0),
        child: InteractiveViewer(
          transformationController: _transformController,
          minScale: 1.0,
          maxScale: 5.0,
          clipBehavior: Clip.none,
          // When at 1x, disable pan so swipe-down gesture reaches GestureDetector
          panEnabled: _scale > 1.0,
          onInteractionUpdate: _onInteractionUpdate,
          onInteractionEnd: _onInteractionEnd,
          child: MediaPreviewImage(
            mediaFileId: widget.file.id,
            thumbnailUrl: widget.file.thumbnailUrl,
            fallback: const ColoredBox(color: Colors.black),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Commit**

```
git add app/lib/features/albums/widgets/viewer_photo_page.dart
git commit -m "Add ViewerPhotoPage with zoom, double-tap, swipe-down dismiss"
```

---

## Task 8 — MediaViewerScreen

**Files:**
- Create: `app/lib/features/albums/screens/media_viewer_screen.dart`

- [ ] **Create the file**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
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
```

- [ ] **Commit**

```
git add app/lib/features/albums/screens/media_viewer_screen.dart
git commit -m "Add MediaViewerScreen with PageView, Hero, chrome auto-hide"
```

---

## Task 9 — Wire album_details_screen tile tap

**Files:**
- Modify: `app/lib/features/albums/screens/album_details_screen.dart`

The tile `onTap` is at approximately line 438. The current non-selection handler is:

```dart
: () => _pushAndRefresh(
      context,
      routeName: AppRoutes.filePreview,
      routeArguments: file,
      album: album,
    ),
```

- [ ] **Add the import** at the top of the file:

```dart
import '../../../app/routes.dart'; // already imported
import 'media_viewer_screen.dart';
```

- [ ] **Replace the tile onTap** (the non-selection branch only, keep the selection branch unchanged):

```dart
onTap: selectionMode
    ? () => _toggleSelectedFile(
          ref,
          albumId: album.id,
          fileId: file.id,
        )
    : () => _pushAndRefresh(
          context,
          routeName: AppRoutes.mediaViewer,
          routeArguments: MediaViewerArgs(
            files: files,
            initialIndex: index,
          ),
          album: album,
        ),
```

- [ ] **Verify the file compiles**

```
flutter analyze app/lib/features/albums/screens/album_details_screen.dart
```

Expected: no errors.

- [ ] **Commit**

```
git add app/lib/features/albums/screens/album_details_screen.dart
git commit -m "Open media viewer from gallery tile tap"
```

---

## Task 10 — Full analyze + push

- [ ] **Run full analyze**

From `app/` directory:
```
flutter analyze
```

Expected: no errors. Warnings about deprecated `dart:html` in the web file are acceptable (same pattern as existing `media_video_preview_web.dart`).

- [ ] **Smoke-check the build compiles** (web target — fastest build check)

```
flutter build web --no-tree-shake-icons
```

Expected: build succeeds.

- [ ] **Push to remote**

```
git push origin main
```

Expected: all 9 commits pushed successfully.

---

## Acceptance Checklist

After implementation, verify manually on device/simulator:

- [ ] Tapping a gallery thumbnail opens viewer with Hero expand animation
- [ ] Pinch to zoom: smooth between 1x and 5x
- [ ] Double-tap: toggles 1x ↔ 2.5x with animation
- [ ] At scale > 1x: horizontal page swipe is disabled, vertical drag pans image
- [ ] At scale 1x: swipe left/right navigates files
- [ ] At first file: swipe right has no effect
- [ ] At last file: swipe left has no effect
- [ ] Swipe down at 1x: background fades, releases > 100px dismisses
- [ ] Chrome hides after 2s, reappears on tap
- [ ] "N of M" counter updates when swiping
- [ ] Back button (X) dismisses with reverse Hero to correct grid tile
- [ ] Download button triggers file download
- [ ] Videos show play button overlay and play inline on tap
- [ ] Video controls: play/pause, scrubber, elapsed/total time, mute all work
- [ ] No crash when disposing (leave screen mid-download, mid-video)
