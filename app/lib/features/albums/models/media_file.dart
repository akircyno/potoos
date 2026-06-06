class MediaFile {
  const MediaFile({
    required this.id,
    required this.originalFilename,
    required this.fileType,
    required this.mimeType,
    required this.fileSizeLabel,
    required this.uploaderName,
    required this.uploadedLabel,
    required this.isVideo,
    this.thumbnailUrl,
  });

  final String id;
  final String originalFilename;
  final String fileType;
  final String mimeType;
  final String fileSizeLabel;
  final String uploaderName;
  final String uploadedLabel;
  final bool isVideo;
  final String? thumbnailUrl;

  factory MediaFile.fromJson(Map<String, dynamic> json) {
    final fileType = json['file_type']?.toString() ?? 'photo';
    final size = int.tryParse(json['file_size_bytes']?.toString() ?? '');
    final uploadedAt = DateTime.tryParse(json['uploaded_at']?.toString() ?? '');
    final uploader = json['uploader'] ?? json['user_profiles'];
    final uploaderMap = uploader is List && uploader.isNotEmpty
        ? Map<String, dynamic>.from(uploader.first as Map)
        : uploader is Map
            ? Map<String, dynamic>.from(uploader)
            : <String, dynamic>{};

    return MediaFile(
      id: json['id']?.toString() ?? '',
      originalFilename:
          json['original_filename']?.toString() ?? 'File',
      fileType: _formatFileType(fileType),
      mimeType: json['mime_type']?.toString() ?? '',
      fileSizeLabel: _formatFileSize(size),
      uploaderName: _uploaderName(uploaderMap),
      uploadedLabel: _uploadedLabel(uploadedAt),
      isVideo: fileType == 'video',
      thumbnailUrl: _optionalText(json['thumbnail_url']),
    );
  }

  static String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String _uploaderName(Map<String, dynamic> uploader) {
    final displayName = uploader['display_name']?.toString().trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    final email = uploader['email']?.toString().trim();
    if (email != null && email.isNotEmpty) return email;

    return 'Member';
  }

  static String _formatFileType(String value) {
    if (value.isEmpty) return 'Photo';
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()}';
  }

  static String _formatFileSize(int? bytes) {
    if (bytes == null || bytes <= 0) return 'File';
    final mb = bytes / (1024 * 1024);
    if (mb < 1) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${mb.toStringAsFixed(1)} MB';
  }

  static String _uploadedLabel(DateTime? uploadedAt) {
    if (uploadedAt == null) return 'Recently';

    final difference = DateTime.now().difference(uploadedAt);
    if (difference.inMinutes < 2) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';

    return '${difference.inDays}d ago';
  }
}
