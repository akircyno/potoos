class AlbumInvite {
  const AlbumInvite({
    required this.id,
    required this.albumId,
    required this.albumName,
    required this.inviterName,
    required this.role,
    required this.createdAt,
    this.albumCoverThumbnailUrl,
  });

  final String id;
  final String albumId;
  final String albumName;
  final String inviterName;
  final String role;
  final DateTime createdAt;
  final String? albumCoverThumbnailUrl;

  String get roleLabel {
    if (role.isEmpty) return 'Contributor';
    return '${role[0].toUpperCase()}${role.substring(1).toLowerCase()}';
  }

  factory AlbumInvite.fromJson(Map<String, dynamic> json) {
    return AlbumInvite(
      id: json['id']?.toString() ?? '',
      albumId: json['album_id']?.toString() ?? '',
      albumName: json['album_name']?.toString() ?? 'Unknown album',
      inviterName: json['invited_by_name']?.toString() ?? 'Someone',
      role: json['role']?.toString() ?? 'contributor',
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      albumCoverThumbnailUrl: _optionalText(json['album_cover_thumbnail_url']),
    );
  }

  static String? _optionalText(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
