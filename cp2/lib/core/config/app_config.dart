abstract final class AppConfig {
  static const apiMode = String.fromEnvironment(
    'HEREWEGO_API_MODE',
    defaultValue: 'mock',
  );

  static const apiBaseUrl = String.fromEnvironment(
    'HEREWEGO_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static bool get usesRemoteApi => apiMode.toLowerCase() == 'remote';
}
