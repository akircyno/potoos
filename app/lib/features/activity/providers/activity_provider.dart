import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/auth_provider.dart';
import '../data/activity_repository.dart';
import '../models/activity_event.dart';

// ── Feed state ───────────────────────────────────────────────────────────────

class ActivityFeedState {
  const ActivityFeedState({
    this.events = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.errorMessage,
    this.lastReadAt,
  });

  final List<ActivityEvent> events;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorMessage;
  final DateTime? lastReadAt;

  ActivityFeedState copyWith({
    List<ActivityEvent>? events,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorMessage,
    bool clearError = false,
    DateTime? lastReadAt,
  }) {
    return ActivityFeedState(
      events: events ?? this.events,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      lastReadAt: lastReadAt ?? this.lastReadAt,
    );
  }
}

// ── Feed notifier ────────────────────────────────────────────────────────────

final activityFeedProvider =
    NotifierProvider.autoDispose<ActivityFeedNotifier, ActivityFeedState>(
  ActivityFeedNotifier.new,
);

class ActivityFeedNotifier extends Notifier<ActivityFeedState> {
  static const _pageSize = 20;

  @override
  ActivityFeedState build() {
    ref.watch(currentUserProfileProvider); // rebuild when auth changes
    Future.microtask(loadInitial);
    return const ActivityFeedState(isLoading: true);
  }

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final repo = ref.read(activityRepositoryProvider);
      final lastReadAt = await repo.fetchLastReadAt();
      final events = await repo.fetchFeed(offset: 0, lastReadAt: lastReadAt);
      state = state.copyWith(
        events: events,
        isLoading: false,
        hasMore: events.length >= _pageSize,
        lastReadAt: lastReadAt,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final repo = ref.read(activityRepositoryProvider);
      final more = await repo.fetchFeed(
        offset: state.events.length,
        lastReadAt: state.lastReadAt,
      );
      state = state.copyWith(
        events: [...state.events, ...more],
        isLoadingMore: false,
        hasMore: more.length >= _pageSize,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> markRead() async {
    await ref.read(activityRepositoryProvider).markRead();
    // Clear unread dots in current list without re-fetching.
    state = state.copyWith(
      events: state.events.map((e) => e.copyWith(isUnread: false)).toList(),
      lastReadAt: DateTime.now(),
    );
    ref.invalidate(unreadActivityCountProvider);
  }
}

// ── Unread count ─────────────────────────────────────────────────────────────

final unreadActivityCountProvider =
    FutureProvider.autoDispose<int>((ref) async {
  final profile = ref.watch(currentUserProfileProvider);
  if (profile == null) return 0;

  final repo = ref.read(activityRepositoryProvider);
  final lastReadAt = await repo.fetchLastReadAt();
  return repo.fetchUnreadCount(lastReadAt);
});
