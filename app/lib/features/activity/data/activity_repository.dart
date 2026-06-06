import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/services/supabase_service.dart';
import '../models/activity_event.dart';

final activityRepositoryProvider = Provider<ActivityRepository>((ref) {
  return ActivityRepository(ref.watch(supabaseServiceProvider));
});

class ActivityRepository {
  const ActivityRepository(this._supabase);

  final SupabaseService _supabase;

  static const _pageSize = 20;

  Future<List<ActivityEvent>> fetchFeed({
    required int offset,
    DateTime? lastReadAt,
  }) async {
    if (!_supabase.isConfigured || _supabase.currentSession == null) {
      return const [];
    }

    try {
      final rows = await _supabase.client
          .from('activity_events')
          .select('''
            id,
            album_id,
            actor_id,
            event_type,
            metadata,
            created_at,
            actor:user_profiles!activity_events_actor_id_fkey(display_name, avatar_url),
            album:albums!activity_events_album_id_fkey(name)
          ''')
          .order('created_at', ascending: false)
          .range(offset, offset + _pageSize - 1);

      return (rows as List).map((row) {
        final json = Map<String, dynamic>.from(row as Map);
        final createdAt =
            DateTime.tryParse(json['created_at']?.toString() ?? '') ??
                DateTime.now();
        final isUnread =
            lastReadAt == null || createdAt.isAfter(lastReadAt);
        return ActivityEvent.fromJson(json, isUnread: isUnread);
      }).toList();
    } catch (e) {
      throw AppError('Could not load activity. ($e)');
    }
  }

  Future<int> fetchUnreadCount(DateTime? lastReadAt) async {
    if (!_supabase.isConfigured || _supabase.currentSession == null) {
      return 0;
    }

    try {
      final since = lastReadAt?.toIso8601String() ?? '1970-01-01T00:00:00Z';
      final result = await _supabase.client
          .from('activity_events')
          .select('id')
          .gt('created_at', since);
      return (result as List).length;
    } catch (_) {
      return 0;
    }
  }

  Future<DateTime?> fetchLastReadAt() async {
    if (!_supabase.isConfigured || _supabase.currentSession == null) {
      return null;
    }

    final userId = _supabase.currentSession!.user.id;
    try {
      final row = await _supabase.client
          .from('user_activity_reads')
          .select('last_read_at')
          .eq('user_id', userId)
          .maybeSingle();

      if (row == null) return null;
      return DateTime.tryParse(
          (row as Map)['last_read_at']?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  Future<void> markRead() async {
    if (!_supabase.isConfigured || _supabase.currentSession == null) return;

    final userId = _supabase.currentSession!.user.id;
    try {
      await _supabase.client.from('user_activity_reads').upsert({
        'user_id': userId,
        'last_read_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Non-critical — swallow silently.
    }
  }
}
