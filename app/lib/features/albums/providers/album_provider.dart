import 'dart:async';

import 'package:collection/collection.dart';
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

/// Signals rollback errors from optimistic mutations to listening screens.
/// Screens listen, show a toast, then clear back to null.
final albumMutationErrorProvider =
    NotifierProvider<_AlbumMutationErrorNotifier, String?>(
  _AlbumMutationErrorNotifier.new,
);

// ── New AsyncNotifierProvider declarations ────────────────────────────────────

final albumListNotifierProvider =
    AsyncNotifierProvider<AlbumListNotifier, List<Album>>(
  AlbumListNotifier.new,
);

final archivedAlbumsNotifierProvider =
    AsyncNotifierProvider.autoDispose<ArchivedAlbumsNotifier, List<Album>>(
  ArchivedAlbumsNotifier.new,
);

final pendingInvitesNotifierProvider =
    AsyncNotifierProvider.autoDispose<PendingInvitesNotifier, List<AlbumInvite>>(
  PendingInvitesNotifier.new,
);

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

  void select(String fileId) {
    state = <String>{...state}..add(fileId);
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
    state = AlbumManagementState(
      done: true,
      action: AlbumManagementAction.rename,
      successMessage: 'Space renamed to "$name".',
    );
    unawaited(
      ref.read(albumListNotifierProvider.notifier).renameAlbum(albumId: albumId, name: name),
    );
  }

  Future<void> archive({required String albumId}) async {
    state = const AlbumManagementState(
      done: true,
      action: AlbumManagementAction.archive,
      successMessage: 'Space archived. You can restore it from the Albums tab.',
    );
    unawaited(
      ref.read(albumListNotifierProvider.notifier).archiveAlbum(albumId: albumId),
    );
  }

  Future<void> unarchive({required String albumId, required Album album}) async {
    state = const AlbumManagementState(
      done: true,
      action: AlbumManagementAction.unarchive,
      successMessage: 'Space restored.',
    );
    unawaited(
      ref.read(albumListNotifierProvider.notifier).unarchiveAlbum(albumId: albumId, album: album),
    );
  }

  Future<void> delete({required String albumId}) async {
    state = const AlbumManagementState(isBusy: true);
    try {
      await ref.read(albumRepositoryProvider).deleteAlbum(albumId: albumId);
      ref.invalidate(albumListNotifierProvider);
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
    NotifierProvider.autoDispose<InviteResponseController, InviteResponseState>(
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

  Future<void> accept({required AlbumInvite invite}) async {
    ref.read(pendingInvitesNotifierProvider.notifier).removeOptimistic(invite.id);
    ref.read(albumListNotifierProvider.notifier).addOptimisticAlbum(invite);
    state = InviteResponseState(successMessage: 'You joined ${invite.albumName}.');
    unawaited(_doAccept(invite));
  }

  Future<void> _doAccept(AlbumInvite invite) async {
    try {
      await ref.read(albumRepositoryProvider).acceptInvite(invite.id);
    } catch (e) {
      try {
        ref.read(pendingInvitesNotifierProvider.notifier).addOptimistic(invite);
      } catch (_) {}
      try {
        ref.read(albumListNotifierProvider.notifier).removeOptimisticAlbum(invite.albumId);
      } catch (_) {}
      try {
        ref.read(albumMutationErrorProvider.notifier).setError("Couldn't join the space. Try again.");
      } catch (_) {}
    }
  }

  Future<void> decline({required AlbumInvite invite}) async {
    ref.read(pendingInvitesNotifierProvider.notifier).removeOptimistic(invite.id);
    state = InviteResponseState(successMessage: 'You declined the invite to ${invite.albumName}.');
    unawaited(_doDecline(invite));
  }

  Future<void> _doDecline(AlbumInvite invite) async {
    try {
      await ref.read(albumRepositoryProvider).declineInvite(invite.id);
    } catch (e) {
      try {
        ref.read(pendingInvitesNotifierProvider.notifier).addOptimistic(invite);
      } catch (_) {}
      try {
        ref.read(albumMutationErrorProvider.notifier).setError("Couldn't decline the invite. Try again.");
      } catch (_) {}
    }
  }
}

// ── Unique people count ───────────────────────────────────────────────────

/// Distinct users across all albums the current user belongs to, excluding self.
/// Re-evaluates whenever albumListProvider is invalidated (join, leave, invite, remove).
final uniquePeopleCountProvider = FutureProvider.autoDispose<int>((ref) {
  final profile = ref.watch(currentUserProfileProvider);
  if (profile == null) return 0;

  ref.watch(albumListNotifierProvider);

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
    state = const LeaveAlbumState(left: true);
    unawaited(
      ref.read(albumListNotifierProvider.notifier).leaveAlbum(albumId: albumId),
    );
  }
}

class _AlbumMutationErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setError(String message) => state = message;
  void clear() => state = null;
}

// ── Stub notifier implementations (full bodies added in subsequent tasks) ─────

class AlbumListNotifier extends AsyncNotifier<List<Album>> {
  @override
  Future<List<Album>> build() {
    final profile = ref.watch(currentUserProfileProvider);
    if (profile == null) return Future.value(const []);
    return ref.watch(albumRepositoryProvider).fetchMyAlbums();
  }

  // ── Optimistic create ─────────────────────────────────────────────────────
  Future<void> createAlbum({required String name, String? description}) async {
    final tempId = 'temp-${DateTime.now().millisecondsSinceEpoch}';
    final temp = Album.optimistic(id: tempId, name: name, description: description);
    _addToFront(temp);

    try {
      final real = await ref.read(albumRepositoryProvider).createAlbum(
            name: name,
            description: description,
          );
      _replace(tempId, real);
    } catch (e) {
      _remove(tempId);
      _setError("Couldn't create album. Try again.");
    }
  }

  // ── Optimistic rename ─────────────────────────────────────────────────────
  Future<void> renameAlbum({
    required String albumId,
    required String name,
  }) async {
    final original = _findById(albumId);
    if (original == null) return;
    state = AsyncData((state.value ?? const [])
        .map((a) => a.id == albumId ? a.copyWith(name: name) : a)
        .toList());

    try {
      await ref
          .read(albumRepositoryProvider)
          .renameAlbum(albumId: albumId, name: name);
    } catch (e) {
      state = AsyncData((state.value ?? const [])
          .map((a) => a.id == albumId ? original : a)
          .toList());
      _setError("Couldn't save changes.");
    }
  }

  // ── Optimistic archive ────────────────────────────────────────────────────
  Future<void> archiveAlbum({required String albumId}) async {
    final original = _findById(albumId);
    final index = _indexOfId(albumId);
    if (original == null) return;
    assert(index >= 0, 'archiveAlbum: album found by ID but indexOfId returned -1');
    _removeAt(index);

    try {
      await ref
          .read(albumRepositoryProvider)
          .archiveAlbum(albumId: albumId);
      ref.invalidate(archivedAlbumsNotifierProvider);
    } catch (e) {
      _reinsertAt(index, original);
      _setError("Couldn't archive the space. Try again.");
    }
  }

  // ── Optimistic unarchive ──────────────────────────────────────────────────
  Future<void> unarchiveAlbum({
    required String albumId,
    required Album album,
  }) async {
    assert(albumId == album.id, 'unarchiveAlbum: albumId and album.id do not match');
    _addToFront(album);

    try {
      await ref
          .read(albumRepositoryProvider)
          .unarchiveAlbum(albumId: albumId);
      ref.invalidate(archivedAlbumsNotifierProvider);
    } catch (e) {
      _remove(albumId);
      _setError("Couldn't restore the space. Try again.");
    }
  }

  // ── Optimistic leave ──────────────────────────────────────────────────────
  Future<void> leaveAlbum({required String albumId}) async {
    final original = _findById(albumId);
    final index = _indexOfId(albumId);
    if (original == null) return;
    assert(index >= 0, 'leaveAlbum: album found by ID but indexOfId returned -1');
    _removeAt(index);

    try {
      await ref.read(albumRepositoryProvider).leaveAlbum(albumId: albumId);
    } catch (e) {
      _reinsertAt(index, original);
      _setError("Couldn't leave the space. Try again.");
    }
  }

  // ── Optimistic join from invite ───────────────────────────────────────────
  void addOptimisticAlbum(AlbumInvite invite) {
    final current = state.value ?? const [];
    if (current.any((a) => a.id == invite.albumId)) return;
    final temp = Album.optimistic(
      id: invite.albumId,
      name: invite.albumName,
      role: invite.roleLabel,
    );
    state = AsyncData([...current, temp]);
  }

  void removeOptimisticAlbum(String albumId) => _remove(albumId);

  // ── Private helpers ───────────────────────────────────────────────────────

  void _addToFront(Album album) {
    state = AsyncData([album, ...(state.value ?? const [])]);
  }

  void _remove(String id) {
    state = AsyncData(
        (state.value ?? const []).where((a) => a.id != id).toList());
  }

  void _removeAt(int index) {
    if (index < 0) return;
    final list = <Album>[...(state.value ?? const <Album>[])];
    if (index >= list.length) return;
    list.removeAt(index);
    state = AsyncData(list);
  }

  void _replace(String tempId, Album real) {
    state = AsyncData((state.value ?? const [])
        .map((a) => a.id == tempId ? real : a)
        .toList());
  }

  void _reinsertAt(int index, Album album) {
    final list = <Album>[...(state.value ?? const <Album>[])];
    list.insert(index.clamp(0, list.length), album);
    state = AsyncData(list);
  }

  Album? _findById(String id) =>
      (state.value ?? const <Album>[]).firstWhereOrNull((a) => a.id == id);

  int _indexOfId(String id) =>
      (state.value ?? const []).indexWhere((a) => a.id == id);

  void _setError(String message) {
    ref.read(albumMutationErrorProvider.notifier).setError(message);
  }
}

class ArchivedAlbumsNotifier extends AsyncNotifier<List<Album>> {
  @override
  Future<List<Album>> build() {
    final profile = ref.watch(currentUserProfileProvider);
    if (profile == null) return Future.value(const []);
    return ref.watch(albumRepositoryProvider).fetchArchivedAlbums();
  }

  void addAlbum(Album album) {
    final current = state.value ?? const <Album>[];
    if (current.any((a) => a.id == album.id)) return;
    state = AsyncData(<Album>[album, ...current]);
  }

  void removeAlbum(String albumId) {
    state = AsyncData(
      (state.value ?? const <Album>[]).where((a) => a.id != albumId).toList(),
    );
  }
}

class PendingInvitesNotifier extends AsyncNotifier<List<AlbumInvite>> {
  @override
  Future<List<AlbumInvite>> build() {
    final profile = ref.watch(currentUserProfileProvider);
    if (profile == null) return Future.value(const <AlbumInvite>[]);
    return ref.watch(albumRepositoryProvider).fetchPendingInvites();
  }

  void removeOptimistic(String inviteId) {
    state = AsyncData(
      (state.value ?? const <AlbumInvite>[])
          .where((i) => i.id != inviteId)
          .toList(),
    );
  }

  void addOptimistic(AlbumInvite invite) {
    final current = state.value ?? const <AlbumInvite>[];
    if (current.any((i) => i.id == invite.id)) return;
    state = AsyncData(<AlbumInvite>[...current, invite]);
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
