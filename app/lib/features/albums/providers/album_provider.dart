import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_error.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/album_repository.dart';
import '../models/album.dart';
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
      final member = await ref.read(albumRepositoryProvider).inviteAlbumMember(
            albumId: albumId,
            email: email,
            role: role,
          );

      ref.invalidate(albumMembersProvider(albumId));
      ref.invalidate(albumListProvider);
      state = InviteMemberState(
        successMessage: '${member.title} is now ${member.roleLabel}.',
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
