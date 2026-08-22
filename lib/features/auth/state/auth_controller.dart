import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../data/auth_repository.dart';
import 'auth_state.dart';

/// Single source of truth for "is anyone logged in, and who". The
/// router listens to this to decide whether to show auth screens or
/// the main app, and the ApiClient can force it back to signed-out
/// when a refresh token is irrecoverably invalid.
class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository, this._secureStorage) : super(const AuthState()) {
    _bootstrap();
  }

  final AuthRepository _repository;
  final SecureStorageService _secureStorage;

  Future<void> _bootstrap() async {
    final hasSession = await _secureStorage.hasSession();
    if (!hasSession) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await _repository.fetchCurrentUser();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      await _secureStorage.clearTokens();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String email, String password) => _run(() => _repository.login(email: email, password: password));

  Future<bool> register(String name, String email, String password) =>
      _run(() => _repository.register(name: name, email: email, password: password));

  Future<bool> loginWithGoogle(String idToken) => _run(() => _repository.loginWithGoogle(idToken));

  Future<bool> _run(Future<dynamic> Function() action) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await action();
      state = state.copyWith(status: AuthStatus.authenticated, user: user, isLoading: false);
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.message);
      return false;
    } catch (_) {
      state = state.copyWith(isLoading: false, errorMessage: 'Something went wrong. Please try again.');
      return false;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> logoutAllDevices() async {
    await _repository.logoutAllDevices();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Called by the ApiClient when the refresh token is rejected server
  /// side - clears state without another network round-trip.
  void forceSignOut() {
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void clearError() => state = state.copyWith(clearError: true);
}
