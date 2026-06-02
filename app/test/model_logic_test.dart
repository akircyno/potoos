import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litratolink/core/errors/app_error.dart';
import 'package:litratolink/features/albums/models/album.dart';
import 'package:litratolink/features/albums/models/album_member.dart';
import 'package:litratolink/features/albums/models/media_file.dart';
import 'package:litratolink/features/auth/data/auth_repository.dart';
import 'package:litratolink/features/downloads/models/downloaded_file.dart';

void main() {
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

    test('collapses non-AppError exceptions to a generic fallback', () {
      expect(
        AppError.messageFor(Exception('ClientException: failed host lookup')),
        'Something went wrong. Please try again.',
      );
      expect(
        AppError.messageFor(null),
        'Something went wrong. Please try again.',
      );
    });
  });

  group('OAuth redirect helper', () {
    test('keeps GitHub Pages base path and removes hash route', () {
      final redirectTo = webOAuthRedirectTo(
        Uri.parse('https://akircyno.github.io/litratolink/#/login'),
      );

      expect(redirectTo, 'https://akircyno.github.io/litratolink/');
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
