import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:rideapp_client/domain/value_objects/coordinates.dart';

class SearchResult {
  final String name;
  final Coordinates coordinates;

  SearchResult(this.name, this.coordinates);
}

class GeocodingService {
  static const String _nominatimUrl = 'https://nominatim.openstreetmap.org/search';
  static DateTime? _lastCallTime;

  static Future<List<SearchResult>> search(String query) async {
    // Implementar el rate limit de Nominatim (mínimo 1 segundo entre llamadas)
    if (_lastCallTime != null) {
      final diff = DateTime.now().difference(_lastCallTime!);
      if (diff < const Duration(seconds: 1)) {
        await Future.delayed(const Duration(seconds: 1) - diff);
      }
    }

    _lastCallTime = DateTime.now();

    final url = Uri.parse('$_nominatimUrl?q=$query&format=json&limit=5');
    
    try {
      final response = await http.get(
        url, 
        headers: {
          'User-Agent': 'RideApp/1.0',
          'Accept-Language': 'es',
        }
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((item) {
          final lat = double.parse(item['lat']);
          final lon = double.parse(item['lon']);
          return SearchResult(
            item['display_name'].split(',')[0], // Nombre corto
            Coordinates(lat, lon),
          );
        }).toList();
      }
      throw Exception('Nominatim Error');
    } catch (e) {
      print('GeocodingService Error: $e');
      return [];
    }
  }
}
