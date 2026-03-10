class AppConfig {
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'https://school-assistant-backend.onrender.com',
  );

  static const String vectorZipUrl = String.fromEnvironment(
    'VECTOR_ZIP_URL',
    defaultValue: '',
  );
}
