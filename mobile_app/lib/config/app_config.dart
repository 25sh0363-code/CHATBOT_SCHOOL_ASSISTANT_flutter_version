class AppConfig {
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://school-assistant-backend.onrender.com',
  );

  static const String vectorZipUrl = String.fromEnvironment(
    'VECTOR_ZIP_URL',
    defaultValue: '',
  );

  static const String leaderboardAppsScriptUrl = String.fromEnvironment(
    'LEADERBOARD_APPS_SCRIPT_URL',
    defaultValue:
        'https://script.google.com/macros/s/AKfycbx-w9wMDnkRIWyM3F91wG_mm0mxaHNP4UuITLGQXQcPMuFz85AkIuG0k_qlCENOccXTMA/exec',
  );
}
