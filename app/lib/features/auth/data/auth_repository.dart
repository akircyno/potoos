import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_error.dart';
import '../../../core/services/edge_function_service.dart';
import '../../../core/services/supabase_service.dart';
import '../models/user_profile.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(supabaseServiceProvider),
    ref.watch(edgeFunctionServiceProvider),
  );
});

class AuthRepository {
  const AuthRepository(this.supabaseService, this.edgeFunctionService);

  final SupabaseService supabaseService;
  final EdgeFunctionService edgeFunctionService;

  bool get isConfigured => supabaseService.isConfigured;

  Session? get currentSession => supabaseService.currentSession;

  Stream<AuthState> get authStateChanges {
    if (!supabaseService.isConfigured) return const Stream.empty();
    return supabaseService.client.auth.onAuthStateChange;
  }

  Future<void> signInWithGoogle() async {
    if (!supabaseService.isConfigured) {
      throw const AppError('Add Supabase URL and anon key before signing in.');
    }

    await supabaseService.client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb
          ? webOAuthRedirectTo(Uri.base)
          : 'io.supabase.flutter://callback',
    );
  }

  Future<UserProfile> createUserProfile() {
    final user = supabaseService.client.auth.currentUser;

    return edgeFunctionService.call<UserProfile>(
      'create-user-profile',
      body: {
        'display_name': user?.userMetadata?['full_name'],
        'avatar_url': user?.userMetadata?['avatar_url'],
      },
      parser: (data) =>
          UserProfile.fromJson(Map<String, dynamic>.from(data as Map)),
    );
  }

  Future<void> signOut() async {
    if (!supabaseService.isConfigured) return;
    await supabaseService.client.auth.signOut();
  }
}

@visibleForTesting
String webOAuthRedirectTo(Uri currentUri) {
  return Uri(
    scheme: currentUri.scheme,
    userInfo: currentUri.userInfo,
    host: currentUri.host,
    port: currentUri.hasPort ? currentUri.port : null,
    path: currentUri.path.isEmpty ? '/' : currentUri.path,
  ).toString();
}
