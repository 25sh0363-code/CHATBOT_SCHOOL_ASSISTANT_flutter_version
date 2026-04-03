class AppConfig {
  static const String _backendBaseUrlRaw = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://school-assistant-backend.onrender.com',
  );

  static String get backendBaseUrl => _resolveBackendBaseUrl(_backendBaseUrlRaw);

  static const String vectorZipUrl = String.fromEnvironment(
    'VECTOR_ZIP_URL',
    defaultValue: '',
  );

  static const String leaderboardAppsScriptUrl = String.fromEnvironment(
    'LEADERBOARD_APPS_SCRIPT_URL',
    defaultValue:
      'https://script.google.com/macros/s/AKfycbxwk1LtYhZ_VKlM5-TZkQCLbbGp1ivTTQszpkUjMURZXVYZiytMu5ky_KUpeZpbGiY1oQ/exec',
  );

  static String _resolveBackendBaseUrl(String configured) {
    final trimmed = configured.trim();
    final uri = Uri.tryParse(trimmed);
    final host = (uri?.host ?? '').toLowerCase();
    final compact = trimmed.toLowerCase();
    final isLocalHost =
        host == '127.0.0.1' ||
        host == 'localhost' ||
        host == '0.0.0.0' ||
        host == '10.0.2.2' ||
        compact.contains('127.0.0.1') ||
        compact.contains('localhost') ||
        compact.contains('0.0.0.0') ||
        compact.contains('10.0.2.2');

    if (isLocalHost) {
      return 'https://school-assistant-backend.onrender.com';
    }
    return trimmed;
  }
}
