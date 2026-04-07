import 'dart:async';
import 'package:latlong2/latlong.dart';
import 'package:rideapp_client/core/antigravity/client.dart';

class MockTraffic {
  static Timer? _timer;

  static void startMacuspanaSim() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // Driver 1: Av. Carlos Pellicer (Norte-Sur)
      // Latitudes entre 17.7700 y 17.7500
      final d1Lat = 17.7600 + (0.01 * (1 - (now % 60000) / 30000)).abs() - 0.005;
      Antigravity.emit('driver.location', {
        'driverId': 'driver-pellicer',
        'lat': d1Lat,
        'lng': -92.5950,
        'heading': 180.0,
        'timestamp': now,
      });

      // Driver 2: C. Lázaro Cárdenas (Este-Oeste)
      // Longitudes entre -92.6050 y -92.5850
      final d2Lng = -92.5950 + (0.01 * (1 - (now % 45000) / 22500)).abs() - 0.005;
      Antigravity.emit('driver.location', {
        'driverId': 'driver-lazaro',
        'lat': 17.7628,
        'lng': d2Lng,
        'heading': 90.0,
        'timestamp': now,
      });

      // Driver 3: Circunbalación (Circular)
      final angle = (now % 30000) / 30000 * 6.28;
      Antigravity.emit('driver.location', {
        'driverId': 'driver-circunvalacion',
        'lat': 17.7600 + 0.004 * (1 + (angle).toDouble()).remainder(1.0), // Simplified path
        'lng': -92.5950 + 0.004 * (0.5 + (angle).toDouble()).remainder(1.0),
        'heading': (angle * 57.29 + 90) % 360,
        'timestamp': now,
      });
    });
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
