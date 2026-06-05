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
      // Scale centred on widget centre (spec: toggle 1x ↔ 2.5x)
      final matrix = Matrix4.identity()
        ..translateByDouble(cx, cy, 0, 0)
        ..scaleByDouble(targetScale, targetScale, 1.0, 1.0)
        ..translateByDouble(-cx, -cy, 0, 0);
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
