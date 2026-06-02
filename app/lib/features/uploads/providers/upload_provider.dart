import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../albums/providers/album_provider.dart';
import '../data/upload_repository.dart';
import '../models/upload_file.dart';
import '../models/upload_session.dart';

final uploadControllerProvider =
    NotifierProvider.autoDispose<UploadController, UploadState>(
  UploadController.new,
);

class UploadState {
  const UploadState({
    this.progress = 0,
    this.isUploading = false,
    this.currentFileIndex = -1,
    this.completedCount = 0,
    this.totalCount = 0,
    this.completedUploads = const [],
    this.errorMessage,
  });

  final double progress;
  final bool isUploading;
  final int currentFileIndex;
  final int completedCount;
  final int totalCount;
  final List<CompletedUpload> completedUploads;
  final String? errorMessage;

  bool get isComplete =>
      !isUploading && totalCount > 0 && completedCount == totalCount;

  UploadState copyWith({
    double? progress,
    bool? isUploading,
    int? currentFileIndex,
    int? completedCount,
    int? totalCount,
    List<CompletedUpload>? completedUploads,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UploadState(
      progress: progress ?? this.progress,
      isUploading: isUploading ?? this.isUploading,
      currentFileIndex: currentFileIndex ?? this.currentFileIndex,
      completedCount: completedCount ?? this.completedCount,
      totalCount: totalCount ?? this.totalCount,
      completedUploads: completedUploads ?? this.completedUploads,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class UploadController extends Notifier<UploadState> {
  @override
  UploadState build() => const UploadState();

  Future<void> upload({
    required String albumId,
    required List<UploadFile> files,
  }) async {
    state = UploadState(isUploading: true, totalCount: files.length);
    final completed = <CompletedUpload>[];

    for (var i = 0; i < files.length; i++) {
      state = state.copyWith(currentFileIndex: i);

      try {
        final result =
            await ref.read(uploadRepositoryProvider).uploadOriginalFile(
                  albumId: albumId,
                  file: files[i],
                  onProgress: (p) {
                    final overall = (i + p.clamp(0.0, 1.0)) / files.length;
                    state = state.copyWith(progress: overall.clamp(0.0, 1.0));
                  },
                );
        completed.add(result);
        state = state.copyWith(
          completedCount: i + 1,
          completedUploads: List.unmodifiable(completed),
          progress: ((i + 1) / files.length).clamp(0.0, 1.0),
          clearError: true,
        );
      } catch (error) {
        state = state.copyWith(
          isUploading: false,
          errorMessage: AppError.messageFor(error),
        );
        return;
      }
    }

    ref.invalidate(albumMediaFilesProvider(albumId));
    ref.invalidate(albumListProvider);
    state = state.copyWith(isUploading: false, progress: 1);
  }
}
