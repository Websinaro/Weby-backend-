/// Central place for values that used to be scattered as magic strings
/// throughout the app - endpoints, storage keys, durations.
class AppConstants {
  AppConstants._();

  /// Base URL of the Weby backend. Override at build time with:
  /// flutter run --dart-define=API_BASE_URL=https://your-deployed-api.example.com/api/v1
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000/api/v1', // Android emulator -> host localhost
  );

  static const String wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://10.0.2.2:3000',
  );

  // Secure storage keys
  static const String keyAccessToken = 'weby.accessToken';
  static const String keyRefreshToken = 'weby.refreshToken';

  // Shared preferences keys (non-sensitive)
  static const String keyThemeMode = 'weby.themeMode';
  static const String keyOnboardingComplete = 'weby.onboardingComplete';
}
