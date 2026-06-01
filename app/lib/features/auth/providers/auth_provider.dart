import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';
import '../models/user_profile.dart';

final currentUserProfileProvider =
    NotifierProvider<CurrentUserProfile, UserProfile?>(
  CurrentUserProfile.new,
);

final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(
  AuthController.new,
);

class AuthController extends Notifier<AsyncValue<void>> {
  bool _isLoadingProfile = false;

  @override
  AsyncValue<void> build() {
    final repository = ref.read(authRepositoryProvider);
    if (repository.isConfigured) {
      final subscription = repository.authStateChanges.listen(
        _handleAuthStateChange,
        onError: (error, stackTrace) {
          state = AsyncError(error, stackTrace);
        },
      );
      ref.onDispose(subscription.cancel);
    }

    return const AsyncData(null);
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();

    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
      await _loadProfileIfSessionExists();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> loadCurrentUserProfile() async {
    state = const AsyncLoading();

    try {
      await _loadProfileIfSessionExists();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> signOut() async {
    state = const AsyncLoading();

    try {
      await ref.read(authRepositoryProvider).signOut();
      ref.read(currentUserProfileProvider.notifier).clear();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> _loadProfileIfSessionExists() async {
    if (_isLoadingProfile) return;

    final repository = ref.read(authRepositoryProvider);
    if (repository.currentSession == null) return;

    _isLoadingProfile = true;

    try {
      final profile = await repository.createUserProfile();
      ref.read(currentUserProfileProvider.notifier).setProfile(profile);
    } finally {
      _isLoadingProfile = false;
    }
  }

  void _handleAuthStateChange(AuthState data) {
    if (data.event == AuthChangeEvent.signedOut) {
      ref.read(currentUserProfileProvider.notifier).clear();
      return;
    }

    if (data.session == null) return;

    if (data.event == AuthChangeEvent.initialSession ||
        data.event == AuthChangeEvent.signedIn ||
        data.event == AuthChangeEvent.tokenRefreshed ||
        data.event == AuthChangeEvent.userUpdated) {
      unawaited(_loadProfileAfterAuthChange());
    }
  }

  Future<void> _loadProfileAfterAuthChange() async {
    try {
      await _loadProfileIfSessionExists();
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

class CurrentUserProfile extends Notifier<UserProfile?> {
  @override
  UserProfile? build() => null;

  void setProfile(UserProfile profile) {
    state = profile;
  }

  void clear() {
    state = null;
  }
}
