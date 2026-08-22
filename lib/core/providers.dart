import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth/google_auth_service.dart';
import 'native/native_bridge.dart';
import 'network/api_client.dart';
import 'session/session_expired_notifier.dart';
import 'storage/secure_storage_service.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/state/auth_controller.dart';
import '../features/auth/state/auth_state.dart';
import '../features/history/data/conversation_repository.dart';
import '../features/preferences/data/preferences_repository.dart';

/// Root dependency-injection graph. Kept intentionally flat and explicit
/// (no code generation) so every wire-up is easy to trace by hand.
final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final apiClientProvider = Provider<ApiClient>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return ApiClient(
    storage,
    onSessionExpired: () {
      // The interceptor detected an unrecoverable 401 (refresh failed).
      // ApiClient can't reach AuthController directly without creating a
      // dependency cycle (AuthController depends on ApiClient via
      // authRepositoryProvider), so it just signals through a neutral
      // event bus. authControllerProvider below listens for this and
      // forces local auth state back to signed-out, which sends the
      // router to the login screen.
      ref.read(sessionExpiredProvider.notifier).notify();
    },
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider), ref.watch(secureStorageProvider));
});

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository(ref.watch(apiClientProvider));
});

final preferencesRepositoryProvider = Provider<PreferencesRepository>((ref) {
  return PreferencesRepository(ref.watch(apiClientProvider));
});

final nativeBridgeProvider = Provider<NativeBridge>((ref) => NativeBridge());

final googleAuthServiceProvider = Provider<GoogleAuthService>((ref) => GoogleAuthService());

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  final controller = AuthController(ref.watch(authRepositoryProvider), ref.watch(secureStorageProvider));
  // React to ApiClient's session-expired signal (see apiClientProvider above)
  // without ever depending on apiClientProvider directly.
  ref.listen(sessionExpiredProvider, (_, __) => controller.forceSignOut());
  return controller;
});
