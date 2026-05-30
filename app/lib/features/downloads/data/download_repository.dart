import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../core/utils/quality_test_log.dart';
import '../../albums/models/media_file.dart';
import '../models/downloaded_file.dart';

final downloadRepositoryProvider = Provider<DownloadRepository>((ref) {
  return DownloadRepository(
    ref.watch(edgeFunctionServiceProvider),
    Dio(),
  );
});

class DownloadRepository {
  const DownloadRepository(this.edgeFunctionService, this.dio);

  final EdgeFunctionService edgeFunctionService;
  final Dio dio;

  Future<DownloadedFile> downloadOriginal({
    required MediaFile file,
    required void Function(double progress) onProgress,
  }) async {
    final response = await dio.post<List<int>>(
      '${edgeFunctionService.supabaseService.env.supabaseUrl}/functions/v1/download-original-file',
      data: {'media_file_id': file.id},
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {
          'Authorization':
              'Bearer ${edgeFunctionService.supabaseService.currentSession?.accessToken}',
          'apikey': edgeFunctionService.supabaseService.env.supabaseAnonKey,
        },
        responseType: ResponseType.bytes,
      ),
      onReceiveProgress: (received, total) {
        if (total <= 0) return;
        onProgress(received / total);
      },
    );

    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw const AppError('Downloaded file was empty. Please try again.');
    }

    final originalFilename = _readHeader(
          response.headers,
          'x-original-filename',
        ) ??
        file.originalFilename;
    final mimeType =
        _readHeader(response.headers, 'x-mime-type') ?? file.mimeType;
    final expectedSize = int.tryParse(
          _readHeader(response.headers, 'x-file-size-bytes') ?? '',
        ) ??
        bytes.length;

    final savedPath = await FilePicker.saveFile(
      dialogTitle: 'Save original file',
      fileName: Uri.decodeComponent(originalFilename),
      bytes: Uint8List.fromList(bytes),
    );

    if (savedPath == null && !kIsWeb) {
      throw const AppError('Download was cancelled.');
    }

    QualityTestLog.downloadedFile(
      filename: Uri.decodeComponent(originalFilename),
      downloadedSizeBytes: bytes.length,
      expectedSizeBytes: expectedSize,
      mimeType: mimeType,
      savedPath: savedPath ?? 'Browser downloads',
    );

    onProgress(1);

    return DownloadedFile(
      filename: Uri.decodeComponent(originalFilename),
      mimeType: mimeType,
      sizeBytes: bytes.length,
      expectedSizeBytes: expectedSize,
      savedPath: savedPath ?? 'Browser downloads',
    );
  }

  String? _readHeader(Headers headers, String name) {
    final values = headers[name];
    if (values == null || values.isEmpty) return null;
    return values.first;
  }
}
