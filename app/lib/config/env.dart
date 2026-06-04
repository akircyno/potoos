import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appEnvProvider = Provider<AppEnv>((ref) {
  throw UnimplementedError('AppEnv must be overridden in ProviderScope.');
});

class AppEnv {
  const AppEnv({
    required this.appEnv,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.googleWebClientId,
    required this.googleIosClientId,
    this.sentryDsn = '',
  });

  final String appEnv;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String googleWebClientId;
  final String googleIosClientId;
  final String sentryDsn;

  bool get hasSupabaseConfig {
    return supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
  }

  bool get hasSentryConfig {
    return sentryDsn.trim().isNotEmpty;
  }

  static Future<AppEnv> load() async {
    // Note: GitHub Pages does not serve files whose names begin with a dot,
    // so the web runtime config is shipped as a non-hidden `env.properties`
    // asset instead of `.env`. The CI workflow writes this file from secrets.
    await dotenv.load(fileName: 'env.properties', isOptional: true);

    return AppEnv(
      appEnv: dotenv.maybeGet('APP_ENV', fallback: 'development') ?? 'development',
      supabaseUrl: dotenv.maybeGet('SUPABASE_URL', fallback: '') ?? '',
      supabaseAnonKey: dotenv.maybeGet('SUPABASE_ANON_KEY', fallback: '') ?? '',
      googleWebClientId: dotenv.maybeGet('GOOGLE_WEB_CLIENT_ID', fallback: '') ?? '',
      googleIosClientId: dotenv.maybeGet('GOOGLE_IOS_CLIENT_ID', fallback: '') ?? '',
      sentryDsn: (dotenv.maybeGet('SENTRY_DSN', fallback: '') ?? '').trim(),
    );
  }
}
