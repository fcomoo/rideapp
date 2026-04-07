import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rideapp_client/domain/value_objects/simple_latlng.dart';
import 'package:rideapp_client/domain/value_objects/coordinates.dart';

class RoutingService {
  static const String _osrmUrl = 'https://router.project-osrm.org/route/v1/driving';

  /// Obtiene la ruta entre dos puntos usando SimpleLatLng (clase nativa)
  static Future<List<Coordinates>> getRoute(SimpleLatLng origin, SimpleLatLng destination) async {
    final url = Uri.parse(
      '$_osrmUrl/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=geojson',
    );

    try {
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final geometry = data['routes'][0]['geometry']['coordinates'] as List;
        
        return geometry.map((point) => Coordinates(point[1].toDouble(), point[0].toDouble())).toList();
      }
      throw Exception('OSRM Error');
    } catch (e) {
      print('RoutingService Error: $e. Returning straight line fallback.');
      return [
        Coordinates(origin.latitude, origin.longitude), 
        Coordinates(destination.latitude, destination.longitude)
      ];
    }
  }
}
