import 'package:latlong2/latlong.dart';

class AppConfig {
  static const String apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://practical-abundance-production-276a.up.railway.app',
  );
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'wss://practical-abundance-production-276a.up.railway.app',
  );

  static const LatLng macuspanaCenter = LatLng(17.7600, -92.5950);

  // Para desarrollo local, corre con:
  // flutter run --dart-define=API_URL=http://localhost:3000 --dart-define=WS_URL=ws://localhost:3000
}
