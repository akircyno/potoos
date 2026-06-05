import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:potoos/config/env.dart';
import 'package:potoos/core/errors/app_error.dart';
import 'package:potoos/features/albums/models/album.dart';
import 'package:potoos/features/downloads/screens/save_all_screen.dart';
import 'package:potoos/features/albums/models/album_member.dart';
import 'package:potoos/features/albums/models/media_file.dart';
import 'package:potoos/features/auth/data/auth_repository.dart';
import 'package:potoos/features/downloads/models/downloaded_file.dart';
import 'package:potoos/features/uploads/models/upload_session.dart';

void main() {
  group('AppEnv', () {
    test('treats a blank Sentry DSN as disabled', () {
      const env = AppEnv(
        appEnv: 'test',
        supabaseUrl: '',
        supabaseAnonKey: '',
        googleWebClientId: '',
        googleIosClientId: '',
      );

      expect(env.hasSentryConfig, isFalse);
    });

    test('treats a populated Sentry DSN as enabled', () {
      const env = AppEnv(
        appEnv: 'production',
        supabaseUrl: '',
        supabaseAnonKey: '',
        googleWebClientId: '',
        googleIosClientId: '',
        sentryDsn: 'https://public@example.ingest.sentry.io/1',
      );

      expect(env.hasSentryConfig, isTrue);
    });
  });

  group('Album role helpers', () {
    test('allow Admin and Contributor to upload', () {
      expect(_albumWithRole('Admin').canUpload, isTrue);
      expect(_albumWithRole('Contributor').canUpload, isTrue);
    });

    test('block Viewer from uploading', () {
      expect(_albumWithRole('Viewer').canUpload, isFalse);
    });

    test('allow only Admin to manage members', () {
      expect(_albumWithRole('Admin').canManageMembers, isTrue);
      expect(_albumWithRole('Contributor').canManageMembers, isFalse);
      expect(_albumWithRole('Viewer').canManageMembers, isFalse);
    });
  });

  group('DownloadedFile quality check', () {
    test('matches when downloaded size equals expected size', () {
      const file = DownloadedFile(
        filename: 'IMG_3778.JPG',
        mimeType: 'image/jpeg',
        sizeBytes: 1194062,
        expectedSizeBytes: 1194062,
        savedPath: 'Browser downloads',
      );

      expect(file.sizeMatchesExpected, isTrue);
    });

    test('fails when downloaded size differs from expected size', () {
      const file = DownloadedFile(
        filename: 'IMG_3778.JPG',
        mimeType: 'image/jpeg',
        sizeBytes: 512000,
        expectedSizeBytes: 1194062,
        savedPath: 'Browser downloads',
      );

      expect(file.sizeMatchesExpected, isFalse);
    });
  });

  group('UploadSession', () {
    test('detects Google Drive resumable upload sessions', () {
      final session = UploadSession.fromJson({
        'media_file_id': 'media-id',
        'storage_object_id': 'storage-id',
        'upload_url':
            'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&upload_id=abc',
        'upload_method': 'PUT',
        'upload_strategy': 'google_drive_resumable',
        'chunk_size_bytes': 8388608,
        'required_headers': {'Content-Type': 'image/jpeg'},
      });

      expect(session.isGoogleDriveResumable, isTrue);
      expect(session.isDriveResumable, isTrue);
      expect(session.chunkSizeBytes, 8388608);
      expect(session.requiredHeaders['Content-Type'], 'image/jpeg');
    });

    test('detects Edge-backed Drive resumable upload sessions', () {
      final session = UploadSession.fromJson({
        'media_file_id': 'media-id',
        'storage_object_id': 'storage-id',
        'upload_url': 'upload-drive-chunk',
        'upload_method': 'PUT',
        'upload_strategy': 'edge_drive_resumable',
        'chunk_size_bytes': 2097152,
        'required_headers': {
          'Content-Type': 'video/mp4',
          'X-Google-Upload-Url':
              'https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable&upload_id=abc',
        },
      });

      expect(session.isEdgeDriveResumable, isTrue);
      expect(session.isDriveResumable, isTrue);
      expect(session.chunkSizeBytes, 2097152);
    });

    test('keeps legacy edge proxy sessions available as fallback', () {
      final session = UploadSession.fromJson({
        'media_file_id': 'media-id',
        'storage_object_id': 'storage-id',
        'upload_url': 'upload-original-file',
        'upload_method': 'POST',
        'required_headers': {'Content-Type': 'application/json'},
      });

      expect(session.isGoogleDriveResumable, isFalse);
      expect(session.isDriveResumable, isFalse);
      expect(session.uploadStrategy, 'edge_function_proxy');
    });
  });

  group('AlbumMember display helpers', () {
    test('uses shared profile display name and email from joined rows', () {
      final member = AlbumMember.fromJson({
        'album_id': 'album-id',
        'user_id': 'user-id',
        'role': 'viewer',
        'profile': {
          'email': 'viewer@example.com',
          'display_name': 'Album Viewer',
          'avatar_url': 'https://example.com/avatar.png',
        },
      });

      expect(member.title, 'Album Viewer');
      expect(member.subtitle, 'viewer@example.com');
      expect(member.roleLabel, 'Viewer');
    });

    test('falls back to role when profile details are hidden', () {
      final member = AlbumMember.fromJson({
        'album_id': 'album-id',
        'user_id': 'user-id',
        'role': 'contributor',
      });

      expect(member.title, 'Album member');
      expect(member.subtitle, 'Contributor');
    });
  });

  group('MediaFile display helpers', () {
    test('uses joined uploader profile display name', () {
      final file = MediaFile.fromJson({
        'id': 'file-id',
        'original_filename': 'IMG_3778.JPG',
        'file_type': 'photo',
        'mime_type': 'image/jpeg',
        'file_size_bytes': 1194062,
        'uploader': {
          'email': 'uploader@example.com',
          'display_name': 'Ian Aquino',
        },
      });

      expect(file.uploaderName, 'Ian Aquino');
      expect(file.fileSizeLabel, '1.1 MB');
    });

    test('falls back to uploader email when display name is hidden', () {
      final file = MediaFile.fromJson({
        'id': 'file-id',
        'original_filename': 'IMG_3778.JPG',
        'file_type': 'photo',
        'mime_type': 'image/jpeg',
        'uploader': {
          'email': 'uploader@example.com',
        },
      });

      expect(file.uploaderName, 'uploader@example.com');
    });
  });

  group('AppError.messageFor', () {
    test('uses the friendly message from an AppError', () {
      expect(
        AppError.messageFor(const AppError('Viewers cannot upload.')),
        'Viewers cannot upload.',
      );
    });

    test('returns connectivity message for network errors', () {
      expect(
        AppError.messageFor(Exception('ClientException: failed host lookup')),
        'No internet connection. Check your connection and try again.',
      );
      expect(
        AppError.messageFor(Exception('SocketException: connection refused')),
        'No internet connection. Check your connection and try again.',
      );
    });

    test('collapses unknown exceptions to a generic fallback', () {
      expect(
        AppError.messageFor(Exception('some random server error')),
        'Something went wrong. Please try again.',
      );
      expect(
        AppError.messageFor(null),
        'Something went wrong. Please try again.',
      );
    });
  });

  group('safeZipName', () {
    test('normal album name becomes lowercase-dashed', () {
      expect(safeZipName('Summer Trip'), 'summer-trip');
    });

    test('collapses runs of unsafe chars and separators', () {
      expect(safeZipName('My!!!Album'), 'my-album');
      expect(safeZipName('A  B   C'), 'a-b-c');
    });

    test('strips leading and trailing dashes', () {
      expect(safeZipName('!Hello!'), 'hello');
    });

    test('caps at 50 characters without a trailing dash', () {
      final long = 'a' * 60;
      final result = safeZipName(long);
      expect(result.length, lessThanOrEqualTo(50));
      expect(result.endsWith('-'), isFalse);
    });

    test('falls back to potoos-album for blank or all-symbol names', () {
      expect(safeZipName(''), 'potoos-album');
      expect(safeZipName('   '), 'potoos-album');
      expect(safeZipName('!!!'), 'potoos-album');
    });
  });

  group('uniqueZipFilename', () {
    test('returns the filename unchanged when no collision', () {
      final used = <String>{};
      expect(uniqueZipFilename('photo.jpg', used), 'photo.jpg');
    });

    test('strips leading hyphens, underscores, spaces, and dots', () {
      final used = <String>{};
      expect(uniqueZipFilename('-cover.jpg', used), 'cover.jpg');
      expect(uniqueZipFilename('..hidden.png', <String>{}), 'hidden.png');
    });

    test('appends counter on duplicate names', () {
      final used = <String>{};
      expect(uniqueZipFilename('photo.jpg', used), 'photo.jpg');
      expect(uniqueZipFilename('photo.jpg', used), 'photo (2).jpg');
      expect(uniqueZipFilename('photo.jpg', used), 'photo (3).jpg');
    });

    test('falls back to original-file for empty or all-stripped names', () {
      expect(uniqueZipFilename('', <String>{}), 'original-file');
      expect(uniqueZipFilename('---', <String>{}), 'original-file');
    });
  });

  group('OAuth redirect helper', () {
    test('keeps GitHub Pages base path and removes hash route', () {
      final redirectTo = webOAuthRedirectTo(
        Uri.parse('https://akircyno.github.io/potoos/#/login'),
      );

      expect(redirectTo, 'https://akircyno.github.io/potoos/');
    });

    test('keeps localhost origin and removes transient error query', () {
      final redirectTo = webOAuthRedirectTo(
        Uri.parse('http://localhost:8080/?error=server_error#/login'),
      );

      expect(redirectTo, 'http://localhost:8080/');
    });
  });
}

Album _albumWithRole(String role) {
  return Album(
    id: 'album-id',
    name: 'Test Album',
    role: role,
    fileCount: 0,
    memberCount: 1,
    updatedLabel: 'Just now',
    coverColors: const [Color(0xFF4A1220), Color(0xFFC4973A)],
  );
}
