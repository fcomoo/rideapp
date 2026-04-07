import 'package:rideapp_client/domain/value_objects/coordinates.dart';

class UserLocation {
  final String entityId; // UUID
  final Coordinates coords;
  final double heading;
  final double speed;
  final int timestamp; // Milliseconds since epoch

  UserLocation({
    required this.entityId,
    required this.coords,
    required this.heading,
    required this.speed,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'entity_id': entityId,
    'coords': {
      'latitude': coords.latitude,
      'longitude': coords.longitude,
    },
    'heading': heading,
    'speed': speed,
    'timestamp': timestamp,
  };

  factory UserLocation.fromJson(Map<String, dynamic> json) => UserLocation(
    entityId: json['entity_id'],
    coords: Coordinates(json['coords']['latitude'], json['coords']['longitude']),
    heading: json['heading'].toDouble(),
    speed: json['speed'].toDouble(),
    timestamp: json['timestamp'],
  );
}
