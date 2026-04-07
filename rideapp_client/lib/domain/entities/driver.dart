import 'package:rideapp_client/domain/value_objects/coordinates.dart';

class Driver {
  final String id; // UUID
  final Map<String, dynamic> vehicleDetails; // JSON
  final Coordinates currentLocation; // Point
  final double rating;

  Driver({
    required this.id,
    required this.vehicleDetails,
    required this.currentLocation,
    required this.rating,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicle_details': vehicleDetails,
    'current_location': {
      'latitude': currentLocation.latitude,
      'longitude': currentLocation.longitude,
    },
    'rating': rating,
  };

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
    id: json['id'],
    vehicleDetails: Map<String, dynamic>.from(json['vehicle_details']),
    currentLocation: Coordinates(
      json['current_location']['latitude'],
      json['current_location']['longitude'],
    ),
    rating: json['rating'].toDouble(),
  );
}
