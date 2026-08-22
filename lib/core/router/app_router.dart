import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/state/auth_state.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/main_shell.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/settings/presentation/assistant_settings_screen.dart';
import '../../features/settings/presentation/contacts_settings_screen.dart';
import '../../features/settings/presentation/privacy_settings_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final isAuthRoute = state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (authState.status == AuthStatus.unknown) return null; // stay on splash

      if (authState.status == AuthStatus.unauthenticated && !isAuthRoute) {
        return '/login';
      }
      if (authState.status == AuthStatus.authenticated &&
          (isAuthRoute || state.matchedLocation == '/')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(path: '/settings/assistant', builder: (context, state) => const AssistantSettingsScreen()),
      GoRoute(path: '/settings/contacts', builder: (context, state) => const ContactsSettingsScreen()),
      GoRoute(path: '/settings/privacy', builder: (context, state) => const PrivacySettingsScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (context, state) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/history', builder: (context, state) => const HistoryScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen())]),
        ],
      ),
    ],
  );
});

/// Bridges Riverpod's AuthController stream of state changes into
/// something GoRouter's refreshListenable can subscribe to, so
/// navigation redirects re-evaluate the moment auth status changes.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this.ref) {
    ref.listen(authControllerProvider, (_, __) => notifyListeners());
  }
  final Ref ref;
}
