import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    this.completedUpload,
    this.errorMessage,
  });

  final double progress;
  final bool isUploading;
  final CompletedUpload? completedUpload;
  final String? errorMessage;

  UploadState copyWith({
    double? progress,
    bool? isUploading,
    CompletedUpload? completedUpload,
    String? errorMessage,
    bool clearError = false,
  }) {
    return UploadState(
      progress: progress ?? this.progress,
      isUploading: isUploading ?? this.isUploading,
      completedUpload: completedUpload ?? this.completedUpload,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class UploadController extends Notifier<UploadState> {
  @override
  UploadState build() => const UploadState();

  Future<void> upload({
    required String albumId,
    required UploadFile file,
  }) async {
    state = const UploadState(isUploading: true);

    try {
      final completed =
          await ref.read(uploadRepositoryProvider).uploadOriginalFile(
                albumId: albumId,
                file: file,
                onProgress: (progress) {
                  state = state.copyWith(progress: progress.clamp(0, 1));
                },
              );

      ref.invalidate(albumMediaFilesProvider(albumId));
      ref.invalidate(albumListProvider);
      state = state.copyWith(
        progress: 1,
        isUploading: false,
        completedUpload: completed,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isUploading: false,
        errorMessage: error.toString(),
      );
    }
  }
}
