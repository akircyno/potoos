import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../core/utils/quality_test_log.dart';
import '../models/upload_file.dart';
import '../models/upload_session.dart';

final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  return UploadRepository(
    ref.watch(edgeFunctionServiceProvider),
  );
});

class UploadRepository {
  const UploadRepository(this.edgeFunctionService);

  final EdgeFunctionService edgeFunctionService;

  Future<CompletedUpload> uploadOriginalFile({
    required String albumId,
    required UploadFile file,
    required void Function(double progress) onProgress,
  }) async {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const AppError('Could not read the selected original file.');
    }

    QualityTestLog.originalUpload(
      filename: file.name,
      sizeBytes: file.sizeBytes,
      mimeType: file.mimeType,
      localPath: file.localPath,
      checksumHex: QualityTestLog.sha256Hex(bytes),
    );

    final session = await edgeFunctionService.call<UploadSession>(
      'create-upload-session',
      body: {
        'album_id': albumId,
        'original_filename': file.name,
        'mime_type': file.mimeType,
        'file_size_bytes': file.sizeBytes,
        'file_type': file.fileType,
      },
      parser: (data) =>
          UploadSession.fromJson(Map<String, dynamic>.from(data as Map)),
    );

    onProgress(0.15);

    // Simulate granular progress while the upload POST is in-flight.
    // The edge function receives the full base64 body before responding, so
    // there is no real streaming progress signal. We advance from 15% toward
    // 90% using an ease-out curve based on a conservative 800 KB/s estimate,
    // then snap to 100% when the response arrives.
    const progressStart = 0.15;
    const progressTarget = 0.90;
    final uploadStart = DateTime.now();
    final estimatedMs = (bytes.length / 819.2).clamp(2000.0, 90000.0);
    final progressTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      final elapsed = DateTime.now().difference(uploadStart).inMilliseconds;
      final t = (elapsed / estimatedMs).clamp(0.0, 1.0);
      final eased = 1 - (1 - t) * (1 - t);
      onProgress(progressStart + eased * (progressTarget - progressStart));
    });

    final CompletedUpload completed;
    try {
      completed = await edgeFunctionService.call<CompletedUpload>(
        'upload-original-file',
        body: {
          'media_file_id': session.mediaFileId,
          'storage_object_id': session.storageObjectId,
          'file_data_base64': base64Encode(bytes),
          'file_size_bytes': file.sizeBytes,
        },
        parser: (data) =>
            CompletedUpload.fromJson(Map<String, dynamic>.from(data as Map)),
      );
    } catch (e) {
      progressTimer.cancel();
      rethrow;
    }
    progressTimer.cancel();
    onProgress(1);

    return completed;
  }
}
