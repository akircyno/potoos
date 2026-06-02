import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/uploads/models/upload_file.dart';
import '../errors/app_error.dart';
import '../utils/file_utils.dart';

final fileServiceProvider = Provider<FileService>((ref) => const FileService());

class FileService {
  const FileService();

  Future<UploadFile?> pickOriginalMediaFile({bool includeVideos = false}) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: FileUtils.allowedMediaExtensions(includeVideos: includeVideos),
      withData: true,
      withReadStream: false,
      compressionQuality: 0,
    );

    final file = result?.files.singleOrNull;
    if (file == null) return null;

    final mimeType = FileUtils.inferMimeType(file.name, file.extension);
    if (mimeType == null) {
      throw const AppError('Please choose a supported photo or video file.');
    }

    final fileType = FileUtils.inferFileType(mimeType);
    if (fileType == null) {
      throw const AppError('Please choose a supported photo or video file.');
    }

    return UploadFile(
      name: file.name,
      mimeType: mimeType,
      sizeBytes: file.size,
      fileType: fileType,
      localPath: file.path,
      bytes: file.bytes,
    );
  }

  Future<List<UploadFile>> pickOriginalMediaFiles({bool includeVideos = false}) async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: FileUtils.allowedMediaExtensions(includeVideos: includeVideos),
      withData: true,
      withReadStream: false,
      compressionQuality: 0,
    );

    if (result == null || result.files.isEmpty) return [];

    final files = <UploadFile>[];
    for (final f in result.files) {
      final mimeType = FileUtils.inferMimeType(f.name, f.extension);
      if (mimeType == null) continue;
      final fileType = FileUtils.inferFileType(mimeType);
      if (fileType == null) continue;
      files.add(UploadFile(
        name: f.name,
        mimeType: mimeType,
        sizeBytes: f.size,
        fileType: fileType,
        localPath: f.path,
        bytes: f.bytes,
      ));
    }

    if (files.isEmpty) {
      throw const AppError('None of the selected files are supported. Choose photos or videos.');
    }

    return files;
  }
}
