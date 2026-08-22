import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

/// Wraps flutter_secure_storage (Android Keystore / iOS Keychain backed)
/// for the only two things that must never live in plain SharedPreferences:
/// the access token and refresh token.
class SecureStorageService {
  SecureStorageService()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  final FlutterSecureStorage _storage;

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: AppConstants.keyAccessToken, value: accessToken);
    await _storage.write(key: AppConstants.keyRefreshToken, value: refreshToken);
  }

  Future<String?> getAccessToken() => _storage.read(key: AppConstants.keyAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: AppConstants.keyRefreshToken);

  Future<void> clearTokens() async {
    await _storage.delete(key: AppConstants.keyAccessToken);
    await _storage.delete(key: AppConstants.keyRefreshToken);
  }

  Future<bool> hasSession() async {
    final refresh = await getRefreshToken();
    return refresh != null && refresh.isNotEmpty;
  }
}
