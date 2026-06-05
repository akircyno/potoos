import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/quality_test_log.dart';
import '../models/upload_file.dart';
import '../models/upload_session.dart';

final uploadRepositoryProvider = Provider<UploadRepository>((ref) {
  return UploadRepository(
    ref.watch(edgeFunctionServiceProvider),
    ref.watch(supabaseServiceProvider),
    Dio(),
  );
});

class UploadRepository {
  const UploadRepository(
      this.edgeFunctionService, this.supabaseService, this.dio);

  final EdgeFunctionService edgeFunctionService;
  final SupabaseService supabaseService;
  final Dio dio;

  static const _defaultDriveChunkSizeBytes = 8 * 1024 * 1024;
  static const _driveChunkQuantumBytes = 256 * 1024;
  static const _maxChunkAttempts = 3;
  static const _legacyProxyMaxBytes = 5 * 1024 * 1024;

  Future<UploadSession> createUploadSession({
    required String albumId,
    required UploadFile file,
  }) {
    return edgeFunctionService.call<UploadSession>(
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
  }

  Future<CompletedUpload> uploadOriginalFile({
    required String albumId,
    required UploadFile file,
    UploadSession? existingSession,
    CancelToken? cancelToken,
    void Function(UploadSession session)? onSessionCreated,
    required void Function(double progress) onProgress,
  }) async {
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw const AppError('Could not read the selected original file.');
    }

    if (bytes.length != file.sizeBytes) {
      throw const AppError(
        'Selected file size changed. Choose the original again and retry.',
        code: 'UPLOAD_FAILED',
      );
    }

    final checksumHex = QualityTestLog.sha256Hex(bytes);
    QualityTestLog.originalUpload(
      filename: file.name,
      sizeBytes: file.sizeBytes,
      mimeType: file.mimeType,
      localPath: file.localPath,
      checksumHex: checksumHex,
    );

    final session = existingSession ??
        await createUploadSession(
          albumId: albumId,
          file: file,
        );
    if (existingSession == null) {
      onSessionCreated?.call(session);
    }

    onProgress(0.05);

    if (session.isDriveResumable) {
      return _uploadWithGoogleDriveResumableSession(
        session: session,
        file: file,
        bytes: bytes,
        checksumHex: checksumHex,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );
    }

    if (file.sizeBytes > _legacyProxyMaxBytes) {
      throw const AppError(
        'This upload needs the latest original-file uploader. Refresh Potoos and try again.',
        code: 'UPLOAD_FAILED',
      );
    }

    return _uploadWithLegacyEdgeProxy(
      session: session,
      file: file,
      bytes: bytes,
      onProgress: onProgress,
    );
  }

  Future<CompletedUpload> _uploadWithGoogleDriveResumableSession({
    required UploadSession session,
    required UploadFile file,
    required Uint8List bytes,
    required String? checksumHex,
    CancelToken? cancelToken,
    required void Function(double progress) onProgress,
  }) async {
    String providerFileId;

    providerFileId = await _uploadRawBytesToDrive(
      session: session,
      file: file,
      bytes: bytes,
      cancelToken: cancelToken,
      onProgress: (p) => onProgress(0.05 + p.clamp(0.0, 1.0) * 0.88),
    );

    onProgress(0.95);

    final completed = await _completeDirectUploadWithRetry(
      session: session,
      providerFileId: providerFileId,
      finalFileSizeBytes: file.sizeBytes,
      checksumHex: checksumHex,
    );

    onProgress(1);
    return completed;
  }

  Future<String> _uploadRawBytesToDrive({
    required UploadSession session,
    required UploadFile file,
    required Uint8List bytes,
    CancelToken? cancelToken,
    required void Function(double progress) onProgress,
  }) async {
    final totalBytes = bytes.length;
    final chunkSize = _normalizeDriveChunkSize(
      session.chunkSizeBytes ?? _defaultDriveChunkSizeBytes,
    );
    var offset = 0;
    Object? finalPayload;

    final startingStatus = await _queryDriveUploadStatus(
      session: session,
      totalBytes: totalBytes,
      cancelToken: cancelToken,
    );
    if (startingStatus != null) {
      if (startingStatus.statusCode == 200 ||
          startingStatus.statusCode == 201) {
        finalPayload = startingStatus.data;
        offset = totalBytes;
        onProgress(1);
      } else if (startingStatus.statusCode == 404) {
        throw _appErrorFromDriveStatus(404);
      } else if (startingStatus.statusCode == 308) {
        offset = (startingStatus.nextOffset ?? 0).clamp(0, totalBytes).toInt();
        onProgress(offset / totalBytes);
      }
    }

    while (offset < totalBytes) {
      final chunkStart = offset;
      final chunkEndExclusive = math.min(chunkStart + chunkSize, totalBytes);
      final chunkEndInclusive = chunkEndExclusive - 1;
      final chunk = Uint8List.sublistView(
        bytes,
        chunkStart,
        chunkEndExclusive,
      );

      final result = await _putDriveChunkWithRetry(
        session: session,
        file: file,
        chunk: chunk,
        chunkStart: chunkStart,
        chunkEndInclusive: chunkEndInclusive,
        totalBytes: totalBytes,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );

      if (result.statusCode == 308) {
        final nextOffset = result.nextOffset ?? chunkEndExclusive;
        if (nextOffset <= chunkStart) {
          throw const AppError(
            'Upload could not make progress. Check your connection and try again.',
            code: 'NETWORK',
          );
        }

        offset = nextOffset.clamp(chunkStart, totalBytes).toInt();
        onProgress(offset / totalBytes);
        continue;
      }

      if (result.statusCode == 200 || result.statusCode == 201) {
        finalPayload = result.data;
        offset = totalBytes;
        onProgress(1);
        break;
      }

      throw _appErrorFromDriveStatus(result.statusCode);
    }

    final providerFileId = _driveFileIdFromPayload(finalPayload);
    if (providerFileId == null) {
      throw const AppError(
        'Upload reached storage but could not be confirmed. Please try again.',
        code: 'UPLOAD_FAILED',
      );
    }

    return providerFileId;
  }

  Future<_DriveUploadResult> _putDriveChunkWithRetry({
    required UploadSession session,
    required UploadFile file,
    required Uint8List chunk,
    required int chunkStart,
    required int chunkEndInclusive,
    required int totalBytes,
    CancelToken? cancelToken,
    required void Function(double progress) onProgress,
  }) async {
    for (var attempt = 1; attempt <= _maxChunkAttempts; attempt++) {
      try {
        final result = await _putDriveChunk(
          session: session,
          file: file,
          chunk: chunk,
          chunkStart: chunkStart,
          chunkEndInclusive: chunkEndInclusive,
          totalBytes: totalBytes,
          cancelToken: cancelToken,
          onProgress: onProgress,
        );

        final madeNoProgress =
            result.statusCode == 308 && (result.nextOffset ?? 0) <= chunkStart;

        if (attempt < _maxChunkAttempts &&
            (_isRetryableDriveStatus(result.statusCode) || madeNoProgress)) {
          final statusResult = await _queryDriveUploadStatus(
            session: session,
            totalBytes: totalBytes,
            cancelToken: cancelToken,
          );
          if (_canContinueFromDriveStatus(statusResult, chunkStart)) {
            return statusResult!;
          }

          await _chunkRetryDelay(attempt);
          continue;
        }

        return result;
      } on AppError catch (error) {
        if (attempt < _maxChunkAttempts && error.code == 'NETWORK') {
          final statusResult = await _queryDriveUploadStatus(
            session: session,
            totalBytes: totalBytes,
            cancelToken: cancelToken,
          );
          if (_canContinueFromDriveStatus(statusResult, chunkStart)) {
            return statusResult!;
          }

          await _chunkRetryDelay(attempt);
          continue;
        }

        rethrow;
      } on DioException catch (error) {
        // Cancellation must propagate immediately — don't retry or convert.
        if (error.type == DioExceptionType.cancel) rethrow;

        if (attempt < _maxChunkAttempts && _isRetryableDioUpload(error)) {
          final statusResult = await _queryDriveUploadStatus(
            session: session,
            totalBytes: totalBytes,
            cancelToken: cancelToken,
          );
          if (_canContinueFromDriveStatus(statusResult, chunkStart)) {
            return statusResult!;
          }

          await _chunkRetryDelay(attempt);
          continue;
        }

        throw _appErrorFromDioUpload(error);
      }
    }

    throw const AppError(
      'Upload could not finish. Check your connection and try again.',
      code: 'NETWORK',
    );
  }

  Future<_DriveUploadResult> _putDriveChunk({
    required UploadSession session,
    required UploadFile file,
    required Uint8List chunk,
    required int chunkStart,
    required int chunkEndInclusive,
    required int totalBytes,
    CancelToken? cancelToken,
    required void Function(double progress) onProgress,
  }) async {
    if (session.isEdgeDriveResumable) {
      final response = await dio.put<dynamic>(
        _edgeFunctionUrl(session.uploadUrl),
        data: chunk,
        cancelToken: cancelToken,
        options: Options(
          headers: _edgeDriveChunkHeaders(
            session: session,
            mimeType: file.mimeType,
            chunkStart: chunkStart,
            chunkEndInclusive: chunkEndInclusive,
            totalBytes: totalBytes,
          ),
          responseType: ResponseType.json,
          validateStatus: (_) => true,
        ),
        onSendProgress: (sent, _) {
          final uploaded = (chunkStart + sent).clamp(0, totalBytes).toInt();
          onProgress(uploaded / totalBytes);
        },
      );

      return _edgeDriveUploadResultFromResponse(response);
    }

    final response = await dio.put<dynamic>(
      session.uploadUrl,
      data: chunk,
      cancelToken: cancelToken,
      options: Options(
        headers: _driveChunkHeaders(
          mimeType: file.mimeType,
          chunkLength: chunk.length,
          chunkStart: chunkStart,
          chunkEndInclusive: chunkEndInclusive,
          totalBytes: totalBytes,
        ),
        responseType: ResponseType.json,
        validateStatus: (_) => true,
      ),
      onSendProgress: (sent, _) {
        final uploaded = (chunkStart + sent).clamp(0, totalBytes).toInt();
        onProgress(uploaded / totalBytes);
      },
    );

    return _driveUploadResultFromResponse(response);
  }

  Future<_DriveUploadResult?> _queryDriveUploadStatus({
    required UploadSession session,
    required int totalBytes,
    CancelToken? cancelToken,
  }) async {
    try {
      final Response<dynamic> response;
      if (session.isEdgeDriveResumable) {
        response = await dio.put<dynamic>(
          _edgeFunctionUrl(session.uploadUrl),
          data: Uint8List(0),
          cancelToken: cancelToken,
          options: Options(
            headers: _edgeDriveProbeHeaders(
              session: session,
              totalBytes: totalBytes,
            ),
            responseType: ResponseType.json,
            validateStatus: (_) => true,
          ),
        );
      } else {
        response = await dio.put<dynamic>(
          session.uploadUrl,
          data: Uint8List(0),
          cancelToken: cancelToken,
          options: Options(
            headers: {
              'Content-Range': 'bytes */$totalBytes',
            },
            responseType: ResponseType.json,
            validateStatus: (_) => true,
          ),
        );
      }

      final result = session.isEdgeDriveResumable
          ? _edgeDriveUploadResultFromResponse(response)
          : _driveUploadResultFromResponse(response);
      final statusCode = result.statusCode;
      if (statusCode == 308 ||
          statusCode == 200 ||
          statusCode == 201 ||
          statusCode == 404) {
        return result;
      }

      return null;
    } on DioException catch (e) {
      // Cancellation must propagate so the upload loop can transition to paused.
      if (e.type == DioExceptionType.cancel) rethrow;
      return null;
    } on AppError {
      return null;
    }
  }

  Map<String, String> _driveChunkHeaders({
    required String mimeType,
    required int chunkLength,
    required int chunkStart,
    required int chunkEndInclusive,
    required int totalBytes,
  }) {
    final headers = <String, String>{
      'Content-Type': mimeType,
      'Content-Range': 'bytes $chunkStart-$chunkEndInclusive/$totalBytes',
    };

    // Browsers set Content-Length themselves and block apps from overriding it.
    if (!kIsWeb) {
      headers['Content-Length'] = chunkLength.toString();
    }

    return headers;
  }

  Map<String, String> _edgeDriveChunkHeaders({
    required UploadSession session,
    required String mimeType,
    required int chunkStart,
    required int chunkEndInclusive,
    required int totalBytes,
  }) {
    return {
      ..._edgeDriveBaseHeaders(session),
      'Content-Type': mimeType,
      'Content-Range': 'bytes $chunkStart-$chunkEndInclusive/$totalBytes',
    };
  }

  Map<String, String> _edgeDriveProbeHeaders({
    required UploadSession session,
    required int totalBytes,
  }) {
    return {
      ..._edgeDriveBaseHeaders(session),
      'Content-Range': 'bytes */$totalBytes',
    };
  }

  Map<String, String> _edgeDriveBaseHeaders(UploadSession session) {
    final accessToken = supabaseService.currentSession?.accessToken;
    final googleUploadUrl = session.requiredHeaders['X-Google-Upload-Url'];

    if (accessToken == null || accessToken.isEmpty) {
      throw const AppError('Please log in to continue.',
          code: 'UNAUTHENTICATED');
    }

    if (googleUploadUrl == null || googleUploadUrl.isEmpty) {
      throw const AppError(
        'Upload session is incomplete. Please choose the original again and retry.',
        code: 'UPLOAD_FAILED',
      );
    }

    return {
      'Authorization': 'Bearer $accessToken',
      'X-Media-File-Id': session.mediaFileId,
      'X-Storage-Object-Id': session.storageObjectId,
      'X-Google-Upload-Url': googleUploadUrl,
    };
  }

  String _edgeFunctionUrl(String functionName) {
    final baseUrl = supabaseService.env.supabaseUrl.replaceFirst(
      RegExp(r'/$'),
      '',
    );
    return '$baseUrl/functions/v1/$functionName';
  }

  Future<CompletedUpload> _completeDirectUploadWithRetry({
    required UploadSession session,
    required String providerFileId,
    required int finalFileSizeBytes,
    required String? checksumHex,
  }) async {
    for (var attempt = 1; attempt <= _maxChunkAttempts; attempt++) {
      try {
        return await edgeFunctionService.call<CompletedUpload>(
          'complete-upload',
          body: {
            'media_file_id': session.mediaFileId,
            'storage_object_id': session.storageObjectId,
            'provider_file_id': providerFileId,
            'final_file_size_bytes': finalFileSizeBytes,
            if (checksumHex != null) 'checksum': checksumHex,
          },
          parser: (data) =>
              CompletedUpload.fromJson(Map<String, dynamic>.from(data as Map)),
        );
      } on AppError catch (error) {
        if (attempt < _maxChunkAttempts && error.code == 'NETWORK') {
          await _chunkRetryDelay(attempt);
          continue;
        }

        rethrow;
      }
    }

    throw const AppError(
      'Upload reached storage but could not be confirmed. Check the album before retrying.',
      code: 'UPLOAD_FAILED',
    );
  }

  Future<CompletedUpload> _uploadWithLegacyEdgeProxy({
    required UploadSession session,
    required UploadFile file,
    required Uint8List bytes,
    required void Function(double progress) onProgress,
  }) async {
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
    final progressTimer =
        Timer.periodic(const Duration(milliseconds: 300), (_) {
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

  int _normalizeDriveChunkSize(int chunkSizeBytes) {
    final atLeastOneQuantum = math.max(chunkSizeBytes, _driveChunkQuantumBytes);
    final quanta = (atLeastOneQuantum / _driveChunkQuantumBytes).floor();
    return quanta * _driveChunkQuantumBytes;
  }

  int? _nextDriveOffset(Headers headers) {
    final values = headers['range'];
    if (values == null || values.isEmpty) return null;

    return _nextDriveOffsetFromRange(values.first);
  }

  int? _nextDriveOffsetFromRange(String? value) {
    if (value == null) return null;

    final match = RegExp(r'^bytes=0-(\d+)$').firstMatch(value.trim());
    if (match == null) return null;

    final lastByte = int.tryParse(match.group(1) ?? '');
    if (lastByte == null) return null;

    return lastByte + 1;
  }

  _DriveUploadResult _driveUploadResultFromResponse(
    Response<dynamic> response,
  ) {
    final statusCode = response.statusCode ?? 0;
    return _DriveUploadResult(
      statusCode: statusCode,
      nextOffset: statusCode == 308 ? _nextDriveOffset(response.headers) : null,
      data: response.data,
    );
  }

  _DriveUploadResult _edgeDriveUploadResultFromResponse(
    Response<dynamic> response,
  ) {
    final httpStatus = response.statusCode ?? 0;
    final payload = response.data;

    if (httpStatus < 200 || httpStatus >= 300) {
      throw _appErrorFromEdgePayload(payload);
    }

    if (payload is! Map || payload['success'] != true) {
      throw _appErrorFromEdgePayload(payload);
    }

    final data = payload['data'];
    if (data is! Map) {
      throw const AppError(
        'Upload reached storage but could not be confirmed. Please try again.',
        code: 'UPLOAD_FAILED',
      );
    }

    final statusCode = int.tryParse(data['status_code']?.toString() ?? '') ?? 0;
    final range = data['range']?.toString();

    return _DriveUploadResult(
      statusCode: statusCode,
      nextOffset: statusCode == 308 ? _nextDriveOffsetFromRange(range) : null,
      data: data['data'],
    );
  }

  bool _canContinueFromDriveStatus(
    _DriveUploadResult? result,
    int chunkStart,
  ) {
    if (result == null) return false;
    if (result.statusCode == 200 ||
        result.statusCode == 201 ||
        result.statusCode == 404) {
      return true;
    }

    return result.statusCode == 308 &&
        result.nextOffset != null &&
        result.nextOffset! > chunkStart;
  }

  bool _isRetryableDriveStatus(int statusCode) {
    return statusCode == 408 || statusCode == 429 || statusCode >= 500;
  }

  bool _isRetryableDioUpload(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode != null) return _isRetryableDriveStatus(statusCode);

    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.unknown;
  }

  Future<void> _chunkRetryDelay(int attempt) {
    return Future<void>.delayed(Duration(milliseconds: 400 * attempt));
  }

  AppError _appErrorFromDriveStatus(int statusCode) {
    if (statusCode == 404) {
      return const AppError(
        'Upload session expired. Please choose the original again and retry.',
        code: 'UPLOAD_FAILED',
      );
    }

    if (_isRetryableDriveStatus(statusCode)) {
      return const AppError(
        'Upload could not finish. Check your connection and try again.',
        code: 'NETWORK',
      );
    }

    return const AppError(
      'Upload was rejected by storage. Please try again.',
      code: 'UPLOAD_FAILED',
    );
  }

  AppError _appErrorFromDioUpload(DioException error) {
    final statusCode = error.response?.statusCode;
    if (statusCode != null) return _appErrorFromDriveStatus(statusCode);

    return const AppError(
      'Upload could not reach storage. Check your connection and try again.',
      code: 'NETWORK',
    );
  }

  AppError _appErrorFromEdgePayload(Object? payload) {
    if (payload is Map) {
      final message = payload['message']?.toString() ??
          'Upload could not finish. Check your connection and try again.';
      final rawCode = payload['error_code']?.toString() ?? 'UPLOAD_FAILED';
      final code = rawCode == 'STORAGE_ERROR' &&
              message.toLowerCase().contains('reach storage')
          ? 'NETWORK'
          : rawCode;

      return AppError(
        message,
        code: code,
      );
    }

    return const AppError(
      'Upload could not finish. Check your connection and try again.',
      code: 'NETWORK',
    );
  }

  String? _driveFileIdFromPayload(Object? payload) {
    if (payload is Map) return payload['id']?.toString();

    if (payload is String && payload.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) return decoded['id']?.toString();
      } catch (_) {
        return null;
      }
    }

    return null;
  }
}

class _DriveUploadResult {
  const _DriveUploadResult({
    required this.statusCode,
    required this.data,
    this.nextOffset,
  });

  final int statusCode;
  final int? nextOffset;
  final Object? data;
}
