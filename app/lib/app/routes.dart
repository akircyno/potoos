import 'package:flutter/material.dart';

import '../features/albums/screens/album_details_screen.dart';
import '../features/albums/screens/create_album_screen.dart';
import '../features/albums/screens/home_screen.dart';
import '../features/albums/screens/members_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/onboarding_screen.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/downloads/screens/file_preview_screen.dart';
import '../features/downloads/screens/save_all_screen.dart';
import '../features/uploads/screens/upload_progress_screen.dart';
import '../features/uploads/screens/upload_screen.dart';

class AppRoutes {
  const AppRoutes._();

  static const splash = '/';
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const home = '/home';
  static const createAlbum = '/create-album';
  static const albumDetails = '/album-details';
  static const upload = '/upload';
  static const uploadProgress = '/upload-progress';
  static const filePreview = '/file-preview';
  static const saveAll = '/save-all';
  static const members = '/members';
  static const profile = '/profile';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final Widget page;
    switch (settings.name) {
      case splash:
        page = const SplashScreen();
      case onboarding:
        page = const OnboardingScreen();
      case login:
        page = const LoginScreen();
      case home:
        page = const HomeScreen();
      case createAlbum:
        page = const CreateAlbumScreen();
      case albumDetails:
        page = const AlbumDetailsScreen();
      case upload:
        page = const UploadScreen();
      case uploadProgress:
        page = const UploadProgressScreen();
      case filePreview:
        page = const FilePreviewScreen();
      case saveAll:
        page = const SaveAllScreen();
      case members:
        page = const MembersScreen();
      case profile:
        page = const HomeScreen(initialIndex: 3);
      default:
        page = const SplashScreen();
    }

    return switch (settings.name) {
      splash || login || onboarding => _fadeRoute(page, settings),
      upload || saveAll || createAlbum => _slideUpRoute(page, settings),
      _ => _slideRightRoute(page, settings),
    };
  }

  static Route<dynamic> _fadeRoute(Widget page, RouteSettings settings) =>
      PageRouteBuilder(
        settings: settings,
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      );

  static Route<dynamic> _slideRightRoute(Widget page, RouteSettings settings) =>
      PageRouteBuilder(
        settings: settings,
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final push = Tween(begin: const Offset(1.0, 0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic))
              .animate(animation);
          final pop = Tween(begin: Offset.zero, end: const Offset(-0.25, 0))
              .chain(CurveTween(curve: Curves.easeInCubic))
              .animate(secondaryAnimation);
          return SlideTransition(
            position: pop,
            child: SlideTransition(position: push, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 260),
      );

  static Route<dynamic> _slideUpRoute(Widget page, RouteSettings settings) =>
      PageRouteBuilder(
        settings: settings,
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, animation, __, child) {
          final slide =
              Tween(begin: const Offset(0, 0.06), end: Offset.zero)
                  .chain(CurveTween(curve: Curves.easeOutCubic))
                  .animate(animation);
          final fade =
              CurvedAnimation(parent: animation, curve: Curves.easeOut);
          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: slide, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 250),
      );
}
