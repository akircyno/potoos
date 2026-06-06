import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../models/activity_event.dart';

class ActivityEventCard extends StatelessWidget {
  const ActivityEventCard({required this.event, required this.currentUserId, super.key});

  final ActivityEvent event;
  final String currentUserId;

  @override
  Widget build(BuildContext context) {
    final description = _describe(event, currentUserId);
    final timestamp = _relativeTime(event.createdAt);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: event.isUnread
            ? AppColors.velvetMaroon.withValues(alpha: 0.04)
            : AppColors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(
          color: event.isUnread
              ? AppColors.velvetMaroon.withValues(alpha: 0.12)
              : AppColors.velvetMaroon.withValues(alpha: 0.07),
          width: 0.8,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Avatar(
            displayName: event.actorDisplayName,
            avatarUrl: event.actorAvatarUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.charcoalInk,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (event.isUnread)
                      Container(
                        width: 7,
                        height: 7,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: const BoxDecoration(
                          color: AppColors.brightGold,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  timestamp,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.featherTaupe,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.displayName, this.avatarUrl});

  final String displayName;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(displayName);
    final url = avatarUrl?.trim();

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.velvetMaroon,
        border: Border.all(
          color: AppColors.brightGold.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: (url != null && url.isNotEmpty)
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _Initials(initials),
              )
            : _Initials(initials),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: AppTheme.headingFont,
          color: AppColors.pearlCream,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _describe(ActivityEvent event, String currentUserId) {
  final isYou = event.actorId == currentUserId;
  final firstName = isYou
      ? 'You'
      : (event.actorDisplayName.trim().split(RegExp(r'\s+')).firstOrNull ??
          'Someone');
  final album = event.albumName.isNotEmpty ? event.albumName : 'a space';

  switch (event.eventType) {
    case 'file_uploaded':
      final count = (event.metadata['file_count'] as num?)?.toInt() ?? 1;
      final noun = count == 1 ? 'file' : 'files';
      return isYou
          ? 'You uploaded $count $noun to $album'
          : '$firstName uploaded $count $noun to $album';

    case 'member_joined':
      return isYou ? 'You joined $album' : '$firstName joined $album';

    case 'member_left':
      final isSelf = event.metadata['self_leave'] == true;
      if (isSelf) {
        return isYou ? 'You left $album' : '$firstName left $album';
      }
      final removedName =
          event.metadata['removed_display_name']?.toString().trim();
      final target = (removedName != null && removedName.isNotEmpty)
          ? removedName.split(RegExp(r'\s+')).firstOrNull ?? removedName
          : 'someone';
      return isYou
          ? 'You removed $target from $album'
          : '$firstName removed $target from $album';

    case 'member_declined':
      return isYou
          ? 'You declined the invite to $album'
          : '$firstName declined your invite to $album';

    case 'album_created':
      return isYou ? 'You created $album' : '$firstName created $album';

    default:
      return 'Something happened in $album';
  }
}

String _relativeTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);

  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return _weekdayName(dt.weekday);
  return _monthDay(dt);
}

String _weekdayName(int weekday) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[(weekday - 1).clamp(0, 6)];
}

String _monthDay(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) {
    return parts.first.characters.take(2).toString().toUpperCase();
  }
  return '${parts.first.characters.first}${parts.last.characters.first}'.toUpperCase();
}
