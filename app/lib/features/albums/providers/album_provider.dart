import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/album_repository.dart';
import '../models/album.dart';
import '../models/album_invite.dart';
import '../models/album_member.dart';
import '../models/media_file.dart';

final albumListProvider = FutureProvider.autoDispose<List<Album>>((ref) {
  final profile = ref.watch(currentUserProfileProvider);
  if (profile == null) return const [];

  return ref.watch(albumRepositoryProvider).fetchMyAlbums();
});

final albumMediaFilesProvider =
    FutureProvider.autoDispose.family<List<MediaFile>, String>((ref, albumId) {
  final profile = ref.watch(currentUserProfileProvider);
  if (profile == null) return const [];

  return ref.watch(albumRepositoryProvider).fetchAlbumMediaFiles(albumId);
});

final albumMembersProvider = FutureProvider.autoDispose
    .family<List<AlbumMember>, String>((ref, albumId) {
  final profile = ref.watch(currentUserProfileProvider);
  if (profile == null) return const [];

  return ref.watch(albumRepositoryProvider).fetchAlbumMembers(albumId);
});

final albumRealtimeRefreshProvider =
    Provider.autoDispose.family<void, String>((ref, albumId) {
  final profile = ref.watch(currentUserProfileProvider);
  final supabaseService = ref.watch(supabaseServiceProvider);
  if (profile == null || !supabaseService.isConfigured) return;

  Timer? refreshDebounce;
  void scheduleRefresh() {
    refreshDebounce?.cancel();
    refreshDebounce = Timer(const Duration(milliseconds: 600), () {
      ref.invalidate(albumMediaFilesProvider(albumId));
      ref.invalidate(albumListProvider);
    });
  }

  final channel = supabaseService.client
      .channel('album-media-files-$albumId')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'media_files',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'album_id',
          value: albumId,
        ),
        callback: (payload) {
          if (_mediaChangeAffectsVisibleAlbumFiles(payload)) {
            scheduleRefresh();
          }
        },
      )
      .subscribe();

  ref.onDispose(() {
    refreshDebounce?.cancel();
    unawaited(supabaseService.client.removeChannel(channel));
  });
});

final inviteMemberControllerProvider =
    NotifierProvider.autoDispose<InviteMemberController, InviteMemberState>(
  InviteMemberController.new,
);

final albumSelectionModeProvider =
    NotifierProvider.autoDispose.family<AlbumSelectionMode, bool, String>(
  AlbumSelectionMode.new,
);

final selectedMediaIdsProvider =
    NotifierProvider.autoDispose.family<SelectedMediaIds, Set<String>, String>(
  SelectedMediaIds.new,
);

class AlbumSelectionMode extends Notifier<bool> {
  AlbumSelectionMode(this.albumId);

  final String albumId;

  @override
  bool build() => false;

  void setEnabled(bool enabled) {
    state = enabled;
  }
}

class SelectedMediaIds extends Notifier<Set<String>> {
  SelectedMediaIds(this.albumId);

  final String albumId;

  @override
  Set<String> build() => <String>{};

  void clear() {
    state = <String>{};
  }

  void removeAll(Iterable<String> fileIds) {
    if (fileIds.isEmpty) return;
    state = <String>{...state}..removeAll(fileIds);
  }

  void toggle(String fileId) {
    final nextSelection = <String>{...state};
    if (!nextSelection.add(fileId)) {
      nextSelection.remove(fileId);
    }
    state = nextSelection;
  }
}

class InviteMemberState {
  const InviteMemberState({
    this.isSending = false,
    this.successMessage,
    this.errorMessage,
  });

  final bool isSending;
  final String? successMessage;
  final String? errorMessage;

  InviteMemberState copyWith({
    bool? isSending,
    String? successMessage,
    String? errorMessage,
    bool clearMessages = false,
  }) {
    return InviteMemberState(
      isSending: isSending ?? this.isSending,
      successMessage:
          clearMessages ? null : successMessage ?? this.successMessage,
      errorMessage: clearMessages ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class InviteMemberController extends Notifier<InviteMemberState> {
  @override
  InviteMemberState build() => const InviteMemberState();

  Future<void> invite({
    required String albumId,
    required String email,
    required String role,
  }) async {
    state = const InviteMemberState(isSending: true);

    try {
      final action = await ref.read(albumRepositoryProvider).inviteAlbumMember(
            albumId: albumId,
            email: email,
            role: role,
          );

      ref.invalidate(albumMembersProvider(albumId));
      ref.invalidate(albumListProvider);
      final roleLabel = role.isNotEmpty
          ? '${role[0].toUpperCase()}${role.substring(1).toLowerCase()}'
          : 'Contributor';
      state = InviteMemberState(
        successMessage: action == 'updated'
            ? 'Role updated to $roleLabel.'
            : 'Invite sent as $roleLabel.',
      );
    } catch (error) {
      state = InviteMemberState(errorMessage: AppError.messageFor(error));
    }
  }

  Future<void> remove({
    required String albumId,
    required AlbumMember member,
  }) async {
    state = const InviteMemberState(isSending: true);

    try {
      await ref.read(albumRepositoryProvider).removeAlbumMember(
            albumId: albumId,
            userId: member.userId,
          );

      ref.invalidate(albumMembersProvider(albumId));
      ref.invalidate(albumListProvider);
      state = InviteMemberState(
        successMessage: '${member.title} was removed from this album.',
      );
    } catch (error) {
      state = InviteMemberState(errorMessage: AppError.messageFor(error));
    }
  }
}

// ── Album Management (Rename / Archive / Unarchive / Delete) ─────────────

enum AlbumManagementAction { rename, archive, unarchive, delete }

final albumManagementProvider = NotifierProvider.autoDispose<
    AlbumManagementController, AlbumManagementState>(
  AlbumManagementController.new,
);

class AlbumManagementState {
  const AlbumManagementState({
    this.isBusy = false,
    this.errorMessage,
    this.done = false,
    this.action,
    this.successMessage,
  });

  final bool isBusy;
  final String? errorMessage;
  final bool done;
  final AlbumManagementAction? action;
  final String? successMessage;
}

class AlbumManagementController extends Notifier<AlbumManagementState> {
  @override
  AlbumManagementState build() => const AlbumManagementState();

  Future<void> rename({required String albumId, required String name}) async {
    state = const AlbumManagementState(isBusy: true);
    try {
      await ref
          .read(albumRepositoryProvider)
          .renameAlbum(albumId: albumId, name: name);
      ref.invalidate(albumListProvider);
      state = AlbumManagementState(
        done: true,
        action: AlbumManagementAction.rename,
        successMessage: 'Space renamed to "$name".',
      );
    } catch (e) {
      state = AlbumManagementState(errorMessage: AppError.messageFor(e));
    }
  }

  Future<void> archive({required String albumId}) async {
    state = const AlbumManagementState(isBusy: true);
    try {
      await ref.read(albumRepositoryProvider).archiveAlbum(albumId: albumId);
      ref.invalidate(albumListProvider);
      ref.invalidate(archivedAlbumsProvider);
      state = const AlbumManagementState(
        done: true,
        action: AlbumManagementAction.archive,
        successMessage:
            'Space archived. You can restore it from the Albums tab.',
      );
    } catch (e) {
      state = AlbumManagementState(errorMessage: AppError.messageFor(e));
    }
  }

  Future<void> unarchive({required String albumId}) async {
    state = const AlbumManagementState(isBusy: true);
    try {
      await ref.read(albumRepositoryProvider).unarchiveAlbum(albumId: albumId);
      ref.invalidate(albumListProvider);
      ref.invalidate(archivedAlbumsProvider);
      state = const AlbumManagementState(
        done: true,
        action: AlbumManagementAction.unarchive,
        successMessage: 'Space restored.',
      );
    } catch (e) {
      state = AlbumManagementState(errorMessage: AppError.messageFor(e));
    }
  }

  Future<void> delete({required String albumId}) async {
    state = const AlbumManagementState(isBusy: true);
    try {
      await ref.read(albumRepositoryProvider).deleteAlbum(albumId: albumId);
      ref.invalidate(albumListProvider);
      ref.invalidate(archivedAlbumsProvider);
      state = const AlbumManagementState(
        done: true,
        action: AlbumManagementAction.delete,
        successMessage: 'Space permanently deleted.',
      );
    } catch (e) {
      state = AlbumManagementState(errorMessage: AppError.messageFor(e));
    }
  }
}

// ── Pending invites ───────────────────────────────────────────────────────

final pendingInvitesProvider =
    FutureProvider.autoDispose<List<AlbumInvite>>((ref) {
  final profile = ref.watch(currentUserProfileProvider);
  if (profile == null) return const [];
  return ref.watch(albumRepositoryProvider).fetchPendingInvites();
});

final inviteResponseControllerProvider =
    NotifierProvider.autoDispose<InviteResponseController,
        InviteResponseState>(
  InviteResponseController.new,
);

class InviteResponseState {
  const InviteResponseState({
    this.isBusy = false,
    this.errorMessage,
    this.successMessage,
  });

  final bool isBusy;
  final String? errorMessage;
  final String? successMessage;
}

class InviteResponseController extends Notifier<InviteResponseState> {
  @override
  InviteResponseState build() => const InviteResponseState();

  Future<void> accept({
    required String inviteId,
    required String albumName,
  }) async {
    state = const InviteResponseState(isBusy: true);
    try {
      await ref.read(albumRepositoryProvider).acceptInvite(inviteId);
      ref.invalidate(pendingInvitesProvider);
      ref.invalidate(albumListProvider);
      state = InviteResponseState(successMessage: 'You joined $albumName.');
    } catch (e) {
      state = InviteResponseState(errorMessage: AppError.messageFor(e));
    }
  }

  Future<void> decline({
    required String inviteId,
    required String albumName,
  }) async {
    state = const InviteResponseState(isBusy: true);
    try {
      await ref.read(albumRepositoryProvider).declineInvite(inviteId);
      ref.invalidate(pendingInvitesProvider);
      state = InviteResponseState(
        successMessage: 'You declined the invite to $albumName.',
      );
    } catch (e) {
      state = InviteResponseState(errorMessage: AppError.messageFor(e));
    }
  }
}

// ── Unique people count ───────────────────────────────────────────────────

/// Distinct users across all albums the current user belongs to, excluding self.
/// Re-evaluates whenever albumListProvider is invalidated (join, leave, invite, remove).
final uniquePeopleCountProvider = FutureProvider.autoDispose<int>((ref) {
  final profile = ref.watch(currentUserProfileProvider);
  if (profile == null) return 0;

  ref.watch(albumListProvider);

  return ref.watch(albumRepositoryProvider).fetchUniquePeopleCount();
});

// ── Archived albums ───────────────────────────────────────────────────────

final archivedAlbumsProvider = FutureProvider.autoDispose<List<Album>>((ref) {
  final profile = ref.watch(currentUserProfileProvider);
  if (profile == null) return const [];
  return ref.watch(albumRepositoryProvider).fetchArchivedAlbums();
});

// ── Leave Album ────────────────────────────────────────────────────────────

final leaveAlbumControllerProvider =
    NotifierProvider.autoDispose<LeaveAlbumController, LeaveAlbumState>(
  LeaveAlbumController.new,
);

class LeaveAlbumState {
  const LeaveAlbumState({
    this.isLeaving = false,
    this.errorMessage,
    this.left = false,
  });

  final bool isLeaving;
  final String? errorMessage;
  final bool left;

  LeaveAlbumState copyWith({
    bool? isLeaving,
    String? errorMessage,
    bool? left,
    bool clearError = false,
  }) {
    return LeaveAlbumState(
      isLeaving: isLeaving ?? this.isLeaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      left: left ?? this.left,
    );
  }
}

class LeaveAlbumController extends Notifier<LeaveAlbumState> {
  @override
  LeaveAlbumState build() => const LeaveAlbumState();

  Future<void> leave({required String albumId}) async {
    state = const LeaveAlbumState(isLeaving: true);

    try {
      await ref.read(albumRepositoryProvider).leaveAlbum(albumId: albumId);
      ref.invalidate(albumListProvider);
      state = const LeaveAlbumState(left: true);
    } catch (error) {
      state = LeaveAlbumState(errorMessage: AppError.messageFor(error));
    }
  }
}

bool _mediaChangeAffectsVisibleAlbumFiles(PostgresChangePayload payload) {
  final newRecord = payload.newRecord;
  final oldRecord = payload.oldRecord;

  bool isCompletedVisible(Map<String, dynamic> record) {
    if (record.isEmpty) return false;
    return record['upload_status'] == 'completed' &&
        record['is_deleted'] != true &&
        record['permanently_deleted_at'] == null;
  }

  return isCompletedVisible(newRecord) || isCompletedVisible(oldRecord);
}
