import 'package:rideapp_client/core/config/app_config.dart';

class AntigravityProfile {
  // URLs de infraestructura
  static const String baseUrl = AppConfig.apiUrl;
  static const String wsUrl = "${AppConfig.wsUrl}/ws";

  // Intervalos y timeouts
  static const Duration gpsInterval = Duration(seconds: 5);
  static const Duration searchTimeout = Duration(seconds: 60);
  static const Duration negotiationTimeout = Duration(seconds: 120);
  
  static const double minDistanceFilter = 10.0; // metros
}
