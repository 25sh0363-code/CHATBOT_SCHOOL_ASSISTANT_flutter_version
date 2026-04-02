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
        'https://script.google.com/macros/s/AKfycbzSOUytt01HIwm5-6QslfmFFhXRnFLfxUqD-e7iTVl_5DNtW9odhtrHUZjkESeYj6lG6g/exec',
  );
}
