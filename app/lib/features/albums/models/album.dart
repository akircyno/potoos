import 'package:flutter/material.dart';

class Album {
  const Album({
    required this.id,
    required this.name,
    this.description,
    required this.role,
    required this.fileCount,
    required this.memberCount,
    required this.updatedLabel,
    required this.coverColors,
    this.coverThumbnailUrl,
    this.coverMediaFileId,
  });

  final String id;
  final String name;
  final String? description;
  final String role;
  final int fileCount;
  final int memberCount;
  final String updatedLabel;
  final List<Color> coverColors;
  final String? coverThumbnailUrl;
  final String? coverMediaFileId;

  String get normalizedRole => role.toLowerCase();

  factory Album.fromData({
    required Map<String, dynamic> album,
    required String role,
    int fileCount = 0,
    int memberCount = 1,
    String? coverMediaFileId,
  }) {
    final id = album['id']?.toString() ?? '';
    final name = album['name']?.toString() ?? 'Untitled album';
    final updatedAt = DateTime.tryParse(album['updated_at']?.toString() ?? '');
    final rawThumb = album['cover_thumbnail_url']?.toString();

    return Album(
      id: id,
      name: name,
      description: album['description']?.toString(),
      role: _formatRole(role),
      fileCount: fileCount,
      memberCount: memberCount,
      updatedLabel: _updatedLabel(updatedAt),
      coverColors: _coverColorsFor(id),
      coverThumbnailUrl:
          (rawThumb != null && rawThumb.isNotEmpty) ? rawThumb : null,
      coverMediaFileId: _optionalText(coverMediaFileId),
    );
  }

  factory Album.fromCreateResponse(Map<String, dynamic> json) {
    final id = json['album_id']?.toString() ?? json['id']?.toString() ?? '';

    return Album(
      id: id,
      name: json['name']?.toString() ?? 'Untitled album',
      role: _formatRole(json['role']?.toString() ?? 'admin'),
      fileCount: 0,
      memberCount: 1,
      updatedLabel: 'Just now',
      coverColors: _coverColorsFor(id),
    );
  }

  bool get canUpload {
    return normalizedRole == 'admin' || normalizedRole == 'contributor';
  }

  bool get canManageMembers => normalizedRole == 'admin';

  static String _formatRole(String role) {
    if (role.isEmpty) return 'Viewer';
    return '${role[0].toUpperCase()}${role.substring(1).toLowerCase()}';
  }

  static String _updatedLabel(DateTime? updatedAt) {
    if (updatedAt == null) return 'Recently';

    final difference = DateTime.now().difference(updatedAt);
    if (difference.inMinutes < 2) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${updatedAt.month}/${updatedAt.day}/${updatedAt.year}';
  }

  static List<Color> _coverColorsFor(String id) {
    final palettes = [
      const [Color(0xFF6B1C2E), Color(0xFFC4973A)],
      const [Color(0xFF4A1220), Color(0xFF8C2840)],
      const [Color(0xFF2C5880), Color(0xFFC4973A)],
      const [Color(0xFF2C8040), Color(0xFF6B1C2E)],
    ];

    if (id.isEmpty) return palettes.first;
    return palettes[id.hashCode.abs() % palettes.length];
  }

  static String? _optionalText(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
