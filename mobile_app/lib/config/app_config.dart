class AppConfig {
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const String vectorZipUrl = String.fromEnvironment(
    'VECTOR_ZIP_URL',
    defaultValue: '',
  );
}
