import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../core/services/supabase_service.dart';
import '../models/album.dart';
import '../models/album_invite.dart';
import '../models/album_member.dart';
import '../models/media_file.dart';

final albumRepositoryProvider = Provider<AlbumRepository>((ref) {
  return AlbumRepository(
    ref.watch(supabaseServiceProvider),
    ref.watch(edgeFunctionServiceProvider),
  );
});

class AlbumRepository {
  const AlbumRepository(this.supabaseService, this.edgeFunctionService);

  final SupabaseService supabaseService;
  final EdgeFunctionService edgeFunctionService;

  Future<List<Album>> fetchMyAlbums() async {
    if (!supabaseService.isConfigured ||
        supabaseService.currentSession == null) {
      return const [];
    }

    final userId = supabaseService.currentSession!.user.id;

    try {
      final membershipRows = await supabaseService.client
          .from('album_members')
          .select('album_id, user_id, role')
          .eq('user_id', userId)
          .eq('is_active', true);

      final memberships = (membershipRows as List)
          .map((row) =>
              AlbumMember.fromJson(Map<String, dynamic>.from(row as Map)))
          .where((member) => member.albumId.isNotEmpty)
          .toList();

      if (memberships.isEmpty) return const [];

      final albumIds = memberships.map((member) => member.albumId).toList();
      final albumRows = await supabaseService.client
          .from('albums')
          .select('id, name, description, updated_at, cover_thumbnail_url')
          .inFilter('id', albumIds)
          .eq('is_deleted', false)
          .eq('is_archived', false)
          .order('updated_at', ascending: false);

      final memberCounts = await _countRowsByAlbum('album_members', albumIds,
          activeMembersOnly: true);
      final fileCounts = await _countRowsByAlbum('media_files', albumIds,
          completedMediaOnly: true);
      final coverFileIds = await _latestCoverFileIdsByAlbum(albumIds);
      final roleByAlbum = {
        for (final member in memberships) member.albumId: member.role,
      };

      return (albumRows as List).map((row) {
        final album = Map<String, dynamic>.from(row as Map);
        final albumId = album['id']?.toString() ?? '';

        return Album.fromData(
          album: album,
          role: roleByAlbum[albumId] ?? 'viewer',
          fileCount: fileCounts[albumId] ?? 0,
          memberCount: memberCounts[albumId] ?? 1,
          coverMediaFileId: coverFileIds[albumId]?.mediaFileId,
          coverThumbnailUrl: coverFileIds[albumId]?.thumbnailUrl,
          coverIsVideo: coverFileIds[albumId]?.isVideo ?? false,
        );
      }).toList();
    } catch (e) {
      throw AppError('Could not load your albums. ($e)');
    }
  }

  Future<Album> createAlbum({
    required String name,
    String? description,
  }) {
    return edgeFunctionService.callFunction<Album>(
      'create-album',
      body: {
        'name': name,
        'description': description,
      },
      parser: (data) =>
          Album.fromCreateResponse(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<void> renameAlbum({
    required String albumId,
    required String name,
  }) async {
    await supabaseService.client.from('albums').update({
      'name': name.trim(),
      'updated_at': DateTime.now().toIso8601String()
    }).eq('id', albumId);
  }

  Future<void> archiveAlbum({required String albumId}) async {
    await edgeFunctionService.callFunction<Object?>(
      'archive-album',
      body: {'album_id': albumId, 'archive': true},
    );
  }

  Future<void> unarchiveAlbum({required String albumId}) async {
    await edgeFunctionService.callFunction<Object?>(
      'archive-album',
      body: {'album_id': albumId, 'archive': false},
    );
  }

  Future<List<Album>> fetchArchivedAlbums() async {
    if (!supabaseService.isConfigured ||
        supabaseService.currentSession == null) {
      return const [];
    }

    final userId = supabaseService.currentSession!.user.id;

    try {
      final membershipRows = await supabaseService.client
          .from('album_members')
          .select('album_id, role')
          .eq('user_id', userId)
          .eq('is_active', true);

      final albumIds = (membershipRows as List)
          .map((r) => (r as Map)['album_id']?.toString())
          .whereType<String>()
          .toList();

      if (albumIds.isEmpty) return const [];

      final albumRows = await supabaseService.client
          .from('albums')
          .select('id, name, description, updated_at, cover_thumbnail_url')
          .inFilter('id', albumIds)
          .eq('is_deleted', false)
          .eq('is_archived', true)
          .order('updated_at', ascending: false);

      final roleByAlbum = {
        for (final row in membershipRows as List)
          (row as Map)['album_id']?.toString() ?? '':
              (row)['role']?.toString() ?? 'viewer',
      };
      final coverFileIds = await _latestCoverFileIdsByAlbum(albumIds);

      return (albumRows as List).map((row) {
        final album = Map<String, dynamic>.from(row as Map);
        final albumId = album['id']?.toString() ?? '';
        return Album.fromData(
          album: album,
          role: roleByAlbum[albumId] ?? 'viewer',
          coverMediaFileId: coverFileIds[albumId]?.mediaFileId,
          coverThumbnailUrl: coverFileIds[albumId]?.thumbnailUrl,
          coverIsVideo: coverFileIds[albumId]?.isVideo ?? false,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> deleteAlbum({required String albumId}) async {
    final userId = supabaseService.currentSession?.user.id;
    debugPrint('[deleteAlbum] albumId=$albumId userId=$userId');
    try {
      await edgeFunctionService.callFunction<Object?>(
        'delete-album',
        body: {'album_id': albumId},
      );
      debugPrint('[deleteAlbum] success');
    } catch (e) {
      debugPrint('[deleteAlbum] failed: $e');
      rethrow;
    }
  }

  Future<List<MediaFile>> fetchAlbumMediaFiles(String albumId) async {
    if (!supabaseService.isConfigured ||
        supabaseService.currentSession == null) {
      return const [];
    }

    try {
      final rows = await supabaseService.client
          .from('media_files')
          .select(
              'id, original_filename, file_type, mime_type, file_size_bytes, thumbnail_url, uploaded_at, uploader:user_profiles!media_files_uploader_id_fkey(email, display_name)')
          .eq('album_id', albumId)
          .eq('upload_status', 'completed')
          .eq('is_deleted', false)
          .isFilter('permanently_deleted_at', null)
          .order('uploaded_at', ascending: false);

      return (rows as List)
          .map((row) =>
              MediaFile.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (_) {
      throw const AppError('Could not load album files. Please try again.');
    }
  }

  Future<List<AlbumMember>> fetchAlbumMembers(String albumId) async {
    if (!supabaseService.isConfigured ||
        supabaseService.currentSession == null) {
      return const [];
    }

    try {
      final rows = await supabaseService.client
          .from('album_members')
          .select(
              'album_id, user_id, role, joined_at, profile:user_profiles!album_members_user_id_fkey(email, display_name, avatar_url)')
          .eq('album_id', albumId)
          .eq('is_active', true)
          .order('joined_at', ascending: true);

      return (rows as List)
          .map((row) =>
              AlbumMember.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (_) {
      throw const AppError('Could not load album members. Please try again.');
    }
  }

  /// Sends a pending invite. Returns the action string ('invited' or 'updated').
  Future<String> inviteAlbumMember({
    required String albumId,
    required String email,
    required String role,
  }) {
    return edgeFunctionService.callFunction<String>(
      'invite-album-member',
      body: {
        'album_id': albumId,
        'email': email,
        'role': role,
      },
      parser: (data) {
        final payload = Map<String, dynamic>.from(data as Map);
        return payload['action']?.toString() ?? 'invited';
      },
    );
  }

  Future<List<AlbumInvite>> fetchPendingInvites() async {
    if (!supabaseService.isConfigured ||
        supabaseService.currentSession == null) {
      return const [];
    }
    final userId = supabaseService.currentSession!.user.id;
    try {
      final rows = await supabaseService.client
          .from('album_invites')
          .select(
            'id, album_id, album_name, invited_by_name, role, status, created_at',
          )
          .eq('invited_user_id', userId)
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      return (rows as List)
          .map((row) =>
              AlbumInvite.fromJson(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (_) {
      throw const AppError('Could not load invites. Please try again.');
    }
  }

  Future<void> acceptInvite(String inviteId) async {
    await edgeFunctionService.callFunction<Object?>(
      'accept-album-invite',
      body: {'invite_id': inviteId},
    );
  }

  Future<void> declineInvite(String inviteId) async {
    await edgeFunctionService.callFunction<Object?>(
      'decline-album-invite',
      body: {'invite_id': inviteId},
    );
  }

  Future<void> removeAlbumMember({
    required String albumId,
    required String userId,
  }) async {
    await edgeFunctionService.callFunction<Object?>(
      'remove-album-member',
      body: {
        'album_id': albumId,
        'user_id': userId,
      },
    );
  }

  Future<void> leaveAlbum({required String albumId}) async {
    await edgeFunctionService.callFunction<Object?>(
      'leave-album',
      body: {'album_id': albumId},
    );
  }

  Future<Map<String, int>> _countRowsByAlbum(
    String table,
    List<String> albumIds, {
    bool activeMembersOnly = false,
    bool completedMediaOnly = false,
  }) async {
    var query = supabaseService.client
        .from(table)
        .select('album_id')
        .inFilter('album_id', albumIds);

    if (activeMembersOnly) {
      query = query.eq('is_active', true);
    }

    if (completedMediaOnly) {
      query = query
          .eq('upload_status', 'completed')
          .eq('is_deleted', false)
          .isFilter('permanently_deleted_at', null);
    }

    final rows = await query;
    final counts = <String, int>{};

    for (final row in rows as List) {
      final albumId = (row as Map)['album_id']?.toString();
      if (albumId == null) continue;
      counts[albumId] = (counts[albumId] ?? 0) + 1;
    }

    return counts;
  }

  Future<Map<String, _AlbumCoverPreview>> _latestCoverFileIdsByAlbum(
    List<String> albumIds,
  ) async {
    if (albumIds.isEmpty) return const {};

    final rows = await supabaseService.client
        .from('media_files')
        .select('id, album_id, file_type, thumbnail_url, uploaded_at')
        .inFilter('album_id', albumIds)
        .eq('upload_status', 'completed')
        .eq('is_deleted', false)
        .isFilter('permanently_deleted_at', null)
        .order('uploaded_at', ascending: false);

    final coverFileIds = <String, _AlbumCoverPreview>{};
    for (final row in rows as List) {
      final data = Map<String, dynamic>.from(row as Map);
      final albumId = data['album_id']?.toString();
      final fileId = data['id']?.toString();
      if (albumId == null || fileId == null) continue;
      coverFileIds.putIfAbsent(
        albumId,
        () => _AlbumCoverPreview(
          mediaFileId: fileId,
          thumbnailUrl: _optionalText(data['thumbnail_url']),
          isVideo: data['file_type']?.toString() == 'video',
        ),
      );
    }

    return coverFileIds;
  }

  static String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}

class _AlbumCoverPreview {
  const _AlbumCoverPreview({
    required this.mediaFileId,
    required this.thumbnailUrl,
    required this.isVideo,
  });

  final String mediaFileId;
  final String? thumbnailUrl;
  final bool isVideo;
}
