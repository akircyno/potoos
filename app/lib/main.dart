import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final env = await AppEnv.load();
  if (env.hasSupabaseConfig) {
    await Supabase.initialize(
      url: env.supabaseUrl,
      anonKey: env.supabaseAnonKey,
    );
  }

  if (env.hasSentryConfig) {
    await SentryFlutter.init(
      (options) {
        options.dsn = env.sentryDsn;
        options.environment = env.appEnv;
        options.tracesSampleRate = 0.20;
      },
      appRunner: () => _runPotoosApp(env),
    );
  } else {
    _runPotoosApp(env);
  }
}

void _runPotoosApp(AppEnv env) {
  runApp(
    ProviderScope(
      overrides: [
        appEnvProvider.overrideWithValue(env),
      ],
      child: const PotoosApp(),
    ),
  );
}
