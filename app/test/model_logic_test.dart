import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:litratolink/features/albums/models/album.dart';
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
