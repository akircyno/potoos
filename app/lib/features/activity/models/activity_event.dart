class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.albumId,
    required this.albumName,
    required this.actorId,
    required this.actorDisplayName,
    this.actorAvatarUrl,
    required this.eventType,
    required this.metadata,
    required this.createdAt,
    this.isUnread = false,
  });

  final String id;
  final String albumId;
  final String albumName;
  final String actorId;
  final String actorDisplayName;
  final String? actorAvatarUrl;
  final String eventType;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final bool isUnread;

  factory ActivityEvent.fromJson(
    Map<String, dynamic> json, {
    bool isUnread = false,
  }) {
    final actor = json['actor'] as Map<String, dynamic>? ?? {};
    final album = json['album'] as Map<String, dynamic>? ?? {};

    return ActivityEvent(
      id: json['id']?.toString() ?? '',
      albumId: json['album_id']?.toString() ?? '',
      albumName: album['name']?.toString() ?? '',
      actorId: json['actor_id']?.toString() ?? '',
      actorDisplayName: actor['display_name']?.toString() ?? 'Someone',
      actorAvatarUrl: _optional(actor['avatar_url']),
      eventType: json['event_type']?.toString() ?? '',
      metadata: Map<String, dynamic>.from(
          (json['metadata'] as Map?)?.cast<String, dynamic>() ?? {}),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      isUnread: isUnread,
    );
  }

  ActivityEvent copyWith({bool? isUnread}) => ActivityEvent(
        id: id,
        albumId: albumId,
        albumName: albumName,
        actorId: actorId,
        actorDisplayName: actorDisplayName,
        actorAvatarUrl: actorAvatarUrl,
        eventType: eventType,
        metadata: metadata,
        createdAt: createdAt,
        isUnread: isUnread ?? this.isUnread,
      );

  static String? _optional(Object? value) {
    final text = value?.toString().trim();
    return (text == null || text.isEmpty) ? null : text;
  }
}
