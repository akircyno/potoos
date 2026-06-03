import 'package:flutter/material.dart';

import 'routes.dart';
import 'theme.dart';

class PotoosApp extends StatelessWidget {
  const PotoosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Potoos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      onGenerateRoute: AppRoutes.generateRoute,
      onGenerateInitialRoutes: (_) => [
        AppRoutes.generateRoute(
          const RouteSettings(name: AppRoutes.splash),
        ),
      ],
      // On web, a hard refresh of a deep hash route (e.g. #/album-details)
      // would otherwise load that screen directly, but its in-memory
      // arguments are gone after a reload. Always start from the splash gate
      // so the session check runs and routes to Login or Home correctly.
      onUnknownRoute: (_) => AppRoutes.generateRoute(
        const RouteSettings(name: AppRoutes.splash),
      ),
    );
  }
}
