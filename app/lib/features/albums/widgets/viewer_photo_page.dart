import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:typed_data';

import '../data/media_preview_repository.dart';
import '../models/media_file.dart';

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
  double _dragY = 0.0;
  bool _draggingDown = false;

  // Pointer tracking for swipe-down dismiss via Listener (avoids gesture-arena
  // conflict with InteractiveViewer's ScaleGestureRecognizer).
  final _activePointers = <int, Offset>{};

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

  void _onDoubleTapDown(TapDownDetails details) {}

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
      // T(cx,cy) * S(s) * T(-cx,-cy) centred on widget centre.
      // w must be 1.0 so the homogeneous coordinate stays valid.
      final matrix = Matrix4.identity()
        ..translateByDouble(cx, cy, 0, 1.0)
        ..scaleByDouble(targetScale, targetScale, 1.0, 1.0)
        ..translateByDouble(-cx, -cy, 0, 1.0);
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

  // ── Swipe-down dismiss via Listener (at 1x, single finger) ──────────────
  // Using Listener instead of GestureDetector.onVerticalDrag* avoids
  // competing with InteractiveViewer's ScaleGestureRecognizer in the arena,
  // which was preventing 2-finger pinch-to-zoom from working.

  void _onPointerDown(PointerDownEvent e) {
    _activePointers[e.pointer] = e.localPosition;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_scale > 1.0 || _activePointers.length != 1) return;
    if (!_activePointers.containsKey(e.pointer)) return;
    final dy = e.delta.dy;
    final dx = e.delta.dx;
    if (!_draggingDown) {
      if (dy > 0 && dy.abs() > dx.abs()) {
        setState(() {
          _draggingDown = true;
          _dragY = 0;
        });
      }
      return;
    }
    setState(() => _dragY += dy);
    widget.onDragOffsetChanged(_dragY.abs());
  }

  void _onPointerUp(PointerUpEvent e) {
    _activePointers.remove(e.pointer);
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

  void _onPointerCancel(PointerCancelEvent e) {
    _activePointers.remove(e.pointer);
    if (_draggingDown) {
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
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: GestureDetector(
        onDoubleTapDown: _onDoubleTapDown,
        onDoubleTap: _onDoubleTap,
        onTap: widget.onInteraction,
        child: Transform.translate(
          offset: Offset(0, _draggingDown ? _dragY : 0),
          child: InteractiveViewer(
            transformationController: _transformController,
            minScale: 1.0,
            maxScale: 5.0,
            clipBehavior: Clip.none,
            panEnabled: _scale > 1.0,
            onInteractionUpdate: _onInteractionUpdate,
            onInteractionEnd: _onInteractionEnd,
            child: _FullResPhoto(file: widget.file),
          ),
        ),
      ),
    );
  }
}

class _FullResPhoto extends ConsumerWidget {
  const _FullResPhoto({required this.file});
  final MediaFile file;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fullRes = ref.watch(mediaFullResBytesProvider(file.id));
    final Uint8List? bytes = fullRes.asData?.value;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeOut,
      child: bytes != null && bytes.isNotEmpty
          ? Image.memory(
              bytes,
              key: ValueKey('full-res-${file.id}'),
              fit: BoxFit.contain,
              gaplessPlayback: true,
              filterQuality: FilterQuality.high,
            )
          : const _ViewerPhotoLoading(),
    );
  }
}

class _ViewerPhotoLoading extends StatelessWidget {
  const _ViewerPhotoLoading();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }
}
