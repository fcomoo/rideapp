import 'dart:async';
import 'package:rideapp_client/domain/entities/trip.dart';
import 'package:rideapp_client/domain/entities/driver.dart';

/// Single source of truth for the application state.
/// All Trip changes propagate exclusively through this store.
class GravityStore {
  static final GravityStore _instance = GravityStore._internal();
  factory GravityStore() => _instance;
  GravityStore._internal();

  // State management using reactive streams
  final _tripController = StreamController<Map<String, Trip>>.broadcast();
  final _driverController = StreamController<Map<String, Driver>>.broadcast();
  
  final Map<String, Trip> _trips = {};
  final Map<String, Driver> _drivers = {};

  Stream<Map<String, Trip>> get tripsStream => _tripController.stream;
  Stream<Map<String, Driver>> get driversStream => _driverController.stream;
  
  Map<String, Trip> get currentTrips => Map.unmodifiable(_trips);
  Map<String, Driver> get currentDrivers => Map.unmodifiable(_drivers);

  void updateTrip(Trip trip) {
    _trips[trip.id] = trip;
    _tripController.add(_trips);
  }

  void updateDriver(Driver driver) {
    _drivers[driver.id] = driver;
    _driverController.add(_drivers);
  }

  void removeTrip(String tripId) {
    _trips.remove(tripId);
    _tripController.add(_trips);
  }

  // To be used by rollback mechanisms
  void rollbackTrip(Trip oldState) {
    _trips[oldState.id] = oldState;
    _tripController.add(_trips);
  }
}
