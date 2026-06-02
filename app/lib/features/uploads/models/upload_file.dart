import 'dart:typed_data';

import '../../albums/models/album.dart';

class UploadFile {
  const UploadFile({
    required this.name,
    required this.mimeType,
    required this.sizeBytes,
    required this.fileType,
    this.localPath,
    this.bytes,
  });

  final String name;
  final String mimeType;
  final int sizeBytes;
  final String fileType;
  final String? localPath;
  final Uint8List? bytes;

  String get sizeLabel {
    if (sizeBytes <= 0) return 'Unknown size';

    final mb = sizeBytes / (1024 * 1024);
    if (mb < 1) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';

    return '${mb.toStringAsFixed(1)} MB';
  }
}

class UploadProgressArgs {
  const UploadProgressArgs({
    required this.album,
    required this.files,
  });

  final Album album;
  final List<UploadFile> files;
}
