class AntigravityProfile {
  // URLs de infraestructura
  static const String baseUrl = "http://localhost:3000";
  static const String wsUrl = "ws://localhost:3000/ws";

  // Intervalos y timeouts
  static const Duration gpsInterval = Duration(seconds: 5);
  static const Duration searchTimeout = Duration(seconds: 60);
  static const Duration negotiationTimeout = Duration(seconds: 120);
  
  static const double minDistanceFilter = 10.0; // metros
}
