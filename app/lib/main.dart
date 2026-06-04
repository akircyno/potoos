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

  await SentryFlutter.init(
    (options) {
      options.dsn = env.sentryDsn;
      // Sample 100% of errors, 20% of performance traces
      options.tracesSampleRate = 0.20;
      // Only send events in production
      options.environment = env.appEnv;
    },
    appRunner: () => runApp(
      ProviderScope(
        overrides: [
          appEnvProvider.overrideWithValue(env),
        ],
        child: const PotoosApp(),
      ),
    ),
  );
}
