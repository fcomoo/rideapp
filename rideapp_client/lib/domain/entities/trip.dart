import 'package:rideapp_client/domain/value_objects/coordinates.dart';

enum TripStatus { requested, accepted, inProgress, completed, cancelled }

class Trip {
  final String id; // UUID
  final String clientId; // FK
  final String? driverId; // FK (null when searching)
  final TripStatus status;
  final List<Coordinates> route; // Geometry

  Trip({
    required this.id,
    required this.clientId,
    this.driverId,
    required this.status,
    required this.route,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'client_id': clientId,
    'driver_id': driverId,
    'status': status.name,
    'route': route.map((Coordinates e) => {
      'lat': e.latitude,
      'lng': e.longitude,
    }).toList(),
  };

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
    id: json['id'],
    clientId: json['client_id'],
    driverId: json['driver_id'],
    status: TripStatus.values.byName(json['status']),
    route: (json['route'] as List).map((e) => Coordinates(e['lat'], e['lng'])).toList(),
  );

  Trip copyWith({
    String? id,
    String? clientId,
    String? driverId,
    TripStatus? status,
    List<Coordinates>? route,
  }) => Trip(
    id: id ?? this.id,
    clientId: clientId ?? this.clientId,
    driverId: driverId ?? this.driverId,
    status: status ?? this.status,
    route: route ?? this.route,
  );
}
