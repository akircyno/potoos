class UploadSession {
  const UploadSession({
    required this.mediaFileId,
    required this.storageObjectId,
    required this.uploadUrl,
    required this.uploadMethod,
    required this.requiredHeaders,
    required this.uploadStrategy,
    required this.chunkSizeBytes,
  });

  final String mediaFileId;
  final String storageObjectId;
  final String uploadUrl;
  final String uploadMethod;
  final Map<String, String> requiredHeaders;
  final String uploadStrategy;
  final int? chunkSizeBytes;

  bool get isGoogleDriveResumable {
    final uri = Uri.tryParse(uploadUrl);
    return uploadStrategy == 'google_drive_resumable' &&
        uploadMethod.toUpperCase() == 'PUT' &&
        uri != null &&
        uri.scheme == 'https' &&
        uri.host == 'www.googleapis.com';
  }

  bool get isEdgeDriveResumable {
    final googleUploadUrl = requiredHeaders['X-Google-Upload-Url'];
    final googleUri = Uri.tryParse(googleUploadUrl ?? '');
    return uploadStrategy == 'edge_drive_resumable' &&
        uploadMethod.toUpperCase() == 'PUT' &&
        uploadUrl == 'upload-drive-chunk' &&
        googleUri != null &&
        googleUri.scheme == 'https' &&
        googleUri.host == 'www.googleapis.com';
  }

  bool get isDriveResumable => isGoogleDriveResumable || isEdgeDriveResumable;

  factory UploadSession.fromJson(Map<String, dynamic> json) {
    final headers =
        Map<String, dynamic>.from(json['required_headers'] as Map? ?? {});
    final rawChunkSize =
        int.tryParse(json['chunk_size_bytes']?.toString() ?? '');

    return UploadSession(
      mediaFileId: json['media_file_id']?.toString() ?? '',
      storageObjectId: json['storage_object_id']?.toString() ?? '',
      uploadUrl: json['upload_url']?.toString() ?? '',
      uploadMethod: json['upload_method']?.toString() ?? 'PUT',
      requiredHeaders:
          headers.map((key, value) => MapEntry(key, value.toString())),
      uploadStrategy:
          json['upload_strategy']?.toString() ?? 'edge_function_proxy',
      chunkSizeBytes:
          rawChunkSize != null && rawChunkSize > 0 ? rawChunkSize : null,
    );
  }
}

class CompletedUpload {
  const CompletedUpload({
    required this.mediaFileId,
    required this.uploadStatus,
    required this.uploadedAt,
  });

  final String mediaFileId;
  final String uploadStatus;
  final DateTime? uploadedAt;

  factory CompletedUpload.fromJson(Map<String, dynamic> json) {
    return CompletedUpload(
      mediaFileId: json['media_file_id']?.toString() ?? '',
      uploadStatus: json['upload_status']?.toString() ?? '',
      uploadedAt: DateTime.tryParse(json['uploaded_at']?.toString() ?? ''),
    );
  }
}
