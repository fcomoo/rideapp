import 'dart:math';
import 'package:rideapp_client/domain/value_objects/coordinates.dart';

class GeoUtils {
  /// Radio de la Tierra en metros
  static const double _earthRadius = 6371000;

  /// Calcula la distancia entre dos coordenadas usando la fórmula Haversine.
  /// Retorna la distancia en metros.
  static double calculateDistance(Coordinates p1, Coordinates p2) {
    final double dLat = _toRadians(p2.latitude - p1.latitude);
    final double dLon = _toRadians(p2.longitude - p1.longitude);

    final double lat1 = _toRadians(p1.latitude);
    final double lat2 = _toRadians(p2.latitude);

    final double a = pow(sin(dLat / 2), 2) +
        pow(sin(dLon / 2), 2) * cos(lat1) * cos(lat2);
    
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return _earthRadius * c;
  }

  /// Calcula la velocidad entre dos estados de ubicación.
  /// Retorna la velocidad en km/h.
  static double calculateSpeedKmh({
    required Coordinates oldLocation,
    required int oldTimestamp,
    required Coordinates newLocation,
    required int newTimestamp,
  }) {
    final double distanceMeters = calculateDistance(oldLocation, newLocation);
    final double timeSeconds = (newTimestamp - oldTimestamp) / 1000.0;

    if (timeSeconds <= 0) return 0.0;

    return (distanceMeters / timeSeconds) * 3.6;
  }

  static double _toRadians(double degree) {
    return degree * pi / 180;
  }
}
