import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:rideapp_client/core/antigravity/client.dart';

class DriverLocationService {
  static final DriverLocationService _instance = DriverLocationService._internal();
  factory DriverLocationService() => _instance;
  DriverLocationService._internal();

  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;

  bool get isTracking => _isTracking;

  Future<void> startTracking(String driverId) async {
    if (_isTracking) return;

    // Verificar permisos
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    _isTracking = true;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Actualizar cada 10 metros
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      // Emitir ubicación real vía WebSocket al backend
      // Usamos el canal driver.{driverId} que ya maneja Antigravity.emit
      Antigravity.emit('driver.location', {
        'driverId': driverId,
        'lat': position.latitude,
        'lng': position.longitude,
        'heading': position.heading,
        'speed': position.speed,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _isTracking = false;
  }
}
