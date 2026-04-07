class AppConfig {
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://localhost:3000',
  );
  static const String wsUrl = String.fromEnvironment(
    'WS_URL', 
    defaultValue: 'ws://localhost:3000',
  );
}
