import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../albums/providers/album_provider.dart';
import '../data/upload_repository.dart';
import '../models/upload_file.dart';
import '../models/upload_session.dart';

// Non-autoDispose — state must survive navigation so uploads can be paused/resumed.
final uploadControllerProvider =
    NotifierProvider<UploadController, UploadState>(
  UploadController.new,
);

class UploadState {
  const UploadState({
    this.progress = 0,
    this.isUploading = false,
    this.isPaused = false,
    this.currentFileIndex = -1,
    this.completedCount = 0,
    this.totalCount = 0,
    this.completedUploads = const [],
    this.errorMessage,
    this.albumId,
  });

  final double progress;
  final bool isUploading;
  final bool isPaused;
  final int currentFileIndex;
  final int completedCount;
  final int totalCount;
  final List<CompletedUpload> completedUploads;
  final String? errorMessage;
  final String? albumId;

  int get remainingCount => (totalCount - completedCount).clamp(0, totalCount);

  bool get isComplete =>
      !isUploading &&
      !isPaused &&
      totalCount > 0 &&
      completedCount == totalCount;

  UploadState copyWith({
    double? progress,
    bool? isUploading,
    bool? isPaused,
    int? currentFileIndex,
    int? completedCount,
    int? totalCount,
    List<CompletedUpload>? completedUploads,
    String? errorMessage,
    String? albumId,
    bool clearError = false,
  }) {
    return UploadState(
      progress: progress ?? this.progress,
      isUploading: isUploading ?? this.isUploading,
      isPaused: isPaused ?? this.isPaused,
      currentFileIndex: currentFileIndex ?? this.currentFileIndex,
      completedCount: completedCount ?? this.completedCount,
      totalCount: totalCount ?? this.totalCount,
      completedUploads: completedUploads ?? this.completedUploads,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      albumId: albumId ?? this.albumId,
    );
  }
}

class UploadController extends Notifier<UploadState> {
  UploadProgressArgs? _uploadArgs;
  List<UploadSession?> _sessions = const [];
  List<CompletedUpload> _completedUploads = const [];
  bool _paused = false;
  CancelToken? _cancelToken;

  @override
  UploadState build() => const UploadState();

  /// Returns the original args when an upload is paused, for resume navigation.
  UploadProgressArgs? get pausedArgs => state.isPaused ? _uploadArgs : null;

  Future<void> upload(UploadProgressArgs args) async {
    _uploadArgs = args;
    _sessions = List<UploadSession?>.filled(args.files.length, null);
    _completedUploads = const [];
    _paused = false;
    _cancelToken = null;
    state = UploadState(
      isUploading: true,
      totalCount: args.files.length,
      albumId: args.album.id,
    );

    await _uploadFromIndex(0);
  }

  /// Pauses the current upload. The in-flight HTTP request is cancelled immediately.
  /// State transitions to isPaused inside _uploadFromIndex's catch.
  Future<void> pause() async {
    if (!state.isUploading) return;
    _paused = true;
    _cancelToken?.cancel();
  }

  /// Resumes from the file that was being uploaded when paused.
  Future<void> resume() async {
    if (!state.isPaused || _uploadArgs == null) return;
    _paused = false;
    _cancelToken = null;

    final resumeIndex = state.currentFileIndex >= 0
        ? state.currentFileIndex
        : state.completedCount;

    state = state.copyWith(
      isUploading: true,
      isPaused: false,
      clearError: true,
    );

    await _uploadFromIndex(resumeIndex);
  }

  Future<void> retryFailed() async {
    final args = _uploadArgs;
    if (args == null || state.isUploading) return;

    final failedIndex = state.currentFileIndex >= 0
        ? state.currentFileIndex
        : state.completedCount;

    if (failedIndex < 0 || failedIndex >= args.files.length) return;

    _paused = false;
    _cancelToken = null;
    state = state.copyWith(
      isUploading: true,
      currentFileIndex: failedIndex,
      clearError: true,
    );

    await _uploadFromIndex(failedIndex);
  }

  Future<void> _uploadFromIndex(int startIndex) async {
    final args = _uploadArgs;
    if (args == null) return;

    final files = args.files;
    final albumId = args.album.id;
    final completed = _completedUploads.toList();

    for (var i = startIndex; i < files.length; i++) {
      // Check pause flag set between files (no in-flight request to cancel).
      if (_paused) {
        state = state.copyWith(
          isUploading: false,
          isPaused: true,
          currentFileIndex: i,
        );
        return;
      }

      final token = CancelToken();
      _cancelToken = token;
      state = state.copyWith(currentFileIndex: i);

      try {
        final result =
            await ref.read(uploadRepositoryProvider).uploadOriginalFile(
                  albumId: albumId,
                  file: files[i],
                  existingSession: _sessions[i],
                  cancelToken: token,
                  onSessionCreated: (session) {
                    _sessions[i] = session;
                  },
                  onProgress: (p) {
                    final overall = (i + p.clamp(0.0, 1.0)) / files.length;
                    state = state.copyWith(progress: overall.clamp(0.0, 1.0));
                  },
                );
        completed.add(result);
        _completedUploads = List.unmodifiable(completed);
        state = state.copyWith(
          completedCount: i + 1,
          completedUploads: _completedUploads,
          progress: ((i + 1) / files.length).clamp(0.0, 1.0),
          clearError: true,
        );
      } catch (error) {
        // _paused is set before cancel() is called, so this handles both
        // mid-chunk cancellation (DioException) and between-file pausing.
        if (_paused) {
          state = state.copyWith(
            isUploading: false,
            isPaused: true,
            currentFileIndex: i,
          );
          return;
        }
        state = state.copyWith(
          isUploading: false,
          errorMessage: AppError.messageFor(error),
        );
        return;
      }
    }

    ref.invalidate(albumMediaFilesProvider(albumId));
    ref.invalidate(albumListProvider);
    state = state.copyWith(isUploading: false, isPaused: false, progress: 1);
  }
}
