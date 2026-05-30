import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../albums/models/media_file.dart';
import '../data/download_repository.dart';
import '../models/downloaded_file.dart';

final downloadControllerProvider =
    NotifierProvider.autoDispose<DownloadController, DownloadState>(
  DownloadController.new,
);

class DownloadState {
  const DownloadState({
    this.progress = 0,
    this.isDownloading = false,
    this.downloadedFile,
    this.errorMessage,
  });

  final double progress;
  final bool isDownloading;
  final DownloadedFile? downloadedFile;
  final String? errorMessage;

  DownloadState copyWith({
    double? progress,
    bool? isDownloading,
    DownloadedFile? downloadedFile,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DownloadState(
      progress: progress ?? this.progress,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadedFile: downloadedFile ?? this.downloadedFile,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class DownloadController extends Notifier<DownloadState> {
  @override
  DownloadState build() => const DownloadState();

  Future<void> download(MediaFile file) async {
    state = const DownloadState(isDownloading: true);

    try {
      final downloadedFile =
          await ref.read(downloadRepositoryProvider).downloadOriginal(
                file: file,
                onProgress: (progress) {
                  state = state.copyWith(progress: progress.clamp(0, 1));
                },
              );

      state = state.copyWith(
        progress: 1,
        isDownloading: false,
        downloadedFile: downloadedFile,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isDownloading: false,
        errorMessage: error.toString(),
      );
    }
  }
}
