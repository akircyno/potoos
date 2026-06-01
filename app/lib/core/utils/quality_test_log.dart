import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';

class QualityTestLog {
  const QualityTestLog._();

  static String? sha256Hex(List<int>? bytes) {
    if (!kDebugMode || bytes == null || bytes.isEmpty) return null;
    return sha256.convert(bytes).toString();
  }

  static void originalUpload({
    required String filename,
    required int sizeBytes,
    required String mimeType,
    required String? localPath,
    String? checksumHex,
  }) {
    if (!kDebugMode) return;

    debugPrint('[LitratoLink Quality] Original upload');
    debugPrint('  filename: $filename');
    debugPrint('  size_bytes: $sizeBytes');
    debugPrint('  mime_type: $mimeType');
    debugPrint('  local_path: ${localPath ?? "browser-selected file"}');
    if (checksumHex != null) {
      debugPrint('  sha256: $checksumHex');
    }
  }

  static void downloadedFile({
    required String filename,
    required int downloadedSizeBytes,
    required int expectedSizeBytes,
    required String mimeType,
    required String savedPath,
    String? checksumHex,
  }) {
    if (!kDebugMode) return;

    debugPrint('[LitratoLink Quality] Downloaded original');
    debugPrint('  filename: $filename');
    debugPrint('  downloaded_size_bytes: $downloadedSizeBytes');
    debugPrint('  expected_size_bytes: $expectedSizeBytes');
    debugPrint('  mime_type: $mimeType');
    debugPrint('  saved_path: $savedPath');
    if (checksumHex != null) {
      debugPrint('  sha256: $checksumHex');
    }

    if (expectedSizeBytes > 0 && downloadedSizeBytes != expectedSizeBytes) {
      debugPrint(
        '  warning: downloaded size differs from expected original size.',
      );
    }
  }
}
