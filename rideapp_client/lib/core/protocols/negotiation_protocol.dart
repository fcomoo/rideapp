import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:rideapp_client/core/antigravity/profile.dart';

class NegotiationProtocol {
  static Future<void> startNegotiation({
    required String tripId,
    required String clientId,
    required Map<String, double> origin,
    required Map<String, double> destination,
    required double offeredPrice,
  }) async {
    final url = Uri.parse("${AntigravityProfile.baseUrl}/api/negotiate");
    await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'tripId': tripId,
        'clientId': clientId,
        'origin': origin,
        'destination': destination,
        'offeredPrice': offeredPrice,
      }),
    );
  }

  static Future<void> counterOffer({
    required String tripId,
    required String driverId,
    required double counterPrice,
    required double offeredPrice,
  }) async {
    final url = Uri.parse("${AntigravityProfile.baseUrl}/api/negotiate/counter");
    await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'tripId': tripId,
        'driverId': driverId,
        'counterPrice': counterPrice,
        'offeredPrice': offeredPrice,
      }),
    );
  }

  static Future<void> acceptOffer({
    required String tripId,
    required String driverId,
    required String clientId,
    required double finalPrice,
  }) async {
    final url = Uri.parse("${AntigravityProfile.baseUrl}/api/negotiate/accept");
    await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'tripId': tripId,
        'driverId': driverId,
        'clientId': clientId,
        'finalPrice': finalPrice,
      }),
    );
  }
}
