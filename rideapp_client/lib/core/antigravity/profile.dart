class AntigravityProfile {
  // URLs de infraestructura
  static const String wsUrl = "ws://localhost:3000/ws";

  // Intervalos definidos en Antigravity profile
  static const Duration gpsInterval = Duration(seconds: 5);
  static const Duration searchTimeout = Duration(seconds: 60);
  static const double minDistanceFilter = 10.0; // metros
}
