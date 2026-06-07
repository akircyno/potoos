import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/supabase_service.dart';

final mediaPreviewRepositoryProvider = Provider<MediaPreviewRepository>((ref) {
  return MediaPreviewRepository(
    ref.watch(supabaseServiceProvider),
    Dio(),
  );
});

final mediaPreviewBytesProvider =
    FutureProvider.autoDispose.family<Uint8List?, String>((ref, mediaFileId) {
  if (mediaFileId.isEmpty) return Future.value(null);
  return ref.watch(mediaPreviewRepositoryProvider).fetchPreview(mediaFileId);
});

final mediaFullResBytesProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>((ref, mediaFileId) async {
  if (mediaFileId.isEmpty) return null;
  final bytes = await ref
      .watch(mediaPreviewRepositoryProvider)
      .fetchPreview(mediaFileId, large: true);

  if (bytes != null && bytes.isNotEmpty) {
    ref.cacheFor(const Duration(minutes: 2));
  }

  return bytes;
});

extension _CacheForExtension on Ref {
  void cacheFor(Duration duration) {
    final link = keepAlive();
    final timer = Timer(duration, link.close);
    onDispose(timer.cancel);
  }
}

class MediaPreviewRepository {
  const MediaPreviewRepository(this.supabaseService, this.dio);

  final SupabaseService supabaseService;
  final Dio dio;

  Future<Uint8List?> fetchPreview(String mediaFileId,
      {bool large = false}) async {
    if (!supabaseService.isConfigured) return null;

    final session = supabaseService.currentSession;
    if (session == null) return null;

    try {
      final queryParams = <String, dynamic>{'media_file_id': mediaFileId};
      if (large) queryParams['size'] = 'large';

      final response = await dio.get<List<int>>(
        '${supabaseService.env.supabaseUrl}/functions/v1/get-media-preview',
        queryParameters: queryParams,
        options: Options(
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'apikey': supabaseService.env.supabaseAnonKey,
          },
          responseType: ResponseType.bytes,
          validateStatus: (_) => true,
        ),
      );

      if (response.statusCode != 200) return null;

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;

      return Uint8List.fromList(bytes);
    } on DioException {
      return null;
    }
  }
}
