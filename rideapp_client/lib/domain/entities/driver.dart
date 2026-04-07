import 'package:rideapp_client/domain/value_objects/coordinates.dart';

class Driver {
  final String id; // UUID
  final Map<String, dynamic> vehicleDetails; // JSON
  final Coordinates currentLocation; // Point
  final double rating;
  final bool isOnline;
  final int nearbyCount;
  final double dailyEarnings;

  Driver({
    required this.id,
    required this.vehicleDetails,
    required this.currentLocation,
    required this.rating,
    this.isOnline = false,
    this.nearbyCount = 0,
    this.dailyEarnings = 0.0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'vehicle_details': vehicleDetails,
    'current_location': {
      'latitude': currentLocation.latitude,
      'longitude': currentLocation.longitude,
    },
    'rating': rating,
    'is_online': isOnline,
    'nearby_count': nearbyCount,
    'daily_earnings': dailyEarnings,
  };

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
    id: json['id'],
    vehicleDetails: Map<String, dynamic>.from(json['vehicle_details']),
    currentLocation: Coordinates(
      json['current_location']['latitude'],
      json['current_location']['longitude'],
    ),
    rating: json['rating'].toDouble(),
    isOnline: json['is_online'] ?? false,
    nearbyCount: json['nearby_count'] ?? 0,
    dailyEarnings: json['daily_earnings']?.toDouble() ?? 0.0,
  );

  Driver copyWith({
    String? id,
    Map<String, dynamic>? vehicleDetails,
    Coordinates? currentLocation,
    double? rating,
    bool? isOnline,
    int? nearbyCount,
    double? dailyEarnings,
  }) {
    return Driver(
      id: id ?? this.id,
      vehicleDetails: vehicleDetails ?? this.vehicleDetails,
      currentLocation: currentLocation ?? this.currentLocation,
      rating: rating ?? this.rating,
      isOnline: isOnline ?? this.isOnline,
      nearbyCount: nearbyCount ?? this.nearbyCount,
      dailyEarnings: dailyEarnings ?? this.dailyEarnings,
    );
  }
}
