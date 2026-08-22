import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import 'models/user_model.dart';

/// Owns every call to /auth/* and is the single place that writes tokens
/// to secure storage after a successful auth operation.
class AuthRepository {
  AuthRepository(this._api, this._secureStorage);

  final ApiClient _api;
  final SecureStorageService _secureStorage;

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final result = await _api.request(
      () => _api.raw.post(
        '/auth/register',
        data: {'name': name, 'email': email, 'password': password},
        options: Options(extra: {'noAuth': true}),
      ),
      (data) => data as Map<String, dynamic>,
    );
    await _persistTokens(result);
    return UserModel.fromJson(result['user']);
  }

  Future<UserModel> login({required String email, required String password}) async {
    final result = await _api.request(
      () => _api.raw.post(
        '/auth/login',
        data: {'email': email, 'password': password},
        options: Options(extra: {'noAuth': true}),
      ),
      (data) => data as Map<String, dynamic>,
    );
    await _persistTokens(result);
    return UserModel.fromJson(result['user']);
  }

  /// [idToken] is the Google ID token obtained on-device via
  /// google_sign_in. The backend re-verifies it server-side - the app
  /// never asserts identity on the backend's behalf.
  Future<UserModel> loginWithGoogle(String idToken) async {
    final result = await _api.request(
      () => _api.raw.post(
        '/auth/google',
        data: {'idToken': idToken},
        options: Options(extra: {'noAuth': true}),
      ),
      (data) => data as Map<String, dynamic>,
    );
    await _persistTokens(result);
    return UserModel.fromJson(result['user']);
  }

  Future<UserModel> fetchCurrentUser() async {
    final result = await _api.request(
      () => _api.raw.get('/auth/me'),
      (data) => data as Map<String, dynamic>,
    );
    return UserModel.fromJson(result);
  }

  Future<void> logout() async {
    final refreshToken = await _secureStorage.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _api.request(
          () => _api.raw.post('/auth/logout', data: {'refreshToken': refreshToken}),
          (data) => data,
        );
      } catch (_) {
        // Best-effort server-side revoke; clear local session regardless.
      }
    }
    await _secureStorage.clearTokens();
  }

  Future<void> logoutAllDevices() async {
    await _api.request(() => _api.raw.post('/auth/logout-all'), (data) => data);
    await _secureStorage.clearTokens();
  }

  Future<void> _persistTokens(Map<String, dynamic> result) => _secureStorage.saveTokens(
        accessToken: result['accessToken'] as String,
        refreshToken: result['refreshToken'] as String,
      );
}
