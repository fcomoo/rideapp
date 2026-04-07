import 'dart:async';
import 'package:rideapp_client/domain/entities/trip.dart';
import 'package:rideapp_client/domain/entities/driver.dart';
import 'package:rideapp_client/domain/entities/negotiation_offer.dart';

/// Single source of truth for the application state.
/// All Trip changes propagate exclusively through this store.
class GravityStore {
  static final GravityStore _instance = GravityStore._internal();
  factory GravityStore() => _instance;
  GravityStore._internal();

  // State management using reactive streams
  final _tripController = StreamController<Map<String, Trip>>.broadcast();
  final _driverController = StreamController<Map<String, Driver>>.broadcast();
  final _offerController = StreamController<Map<String, NegotiationOffer>>.broadcast();
  
  final Map<String, Trip> _trips = {};
  final Map<String, Driver> _drivers = {};
  final Map<String, NegotiationOffer> _offers = {};

  Stream<Map<String, Trip>> get tripsStream => _tripController.stream;
  Stream<Map<String, Driver>> get driversStream => _driverController.stream;
  Stream<Map<String, NegotiationOffer>> get offersStream => _offerController.stream;
  
  Map<String, Trip> get currentTrips => Map.unmodifiable(_trips);
  Map<String, Driver> get currentDrivers => Map.unmodifiable(_drivers);
  Map<String, NegotiationOffer> get currentOffers => Map.unmodifiable(_offers);

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

  void updateOffer(NegotiationOffer offer) {
    _offers[offer.id] = offer;
    _offerController.add(_offers);
  }

  void clearOffers() {
    _offers.clear();
    _offerController.add(_offers);
  }

  // To be used by rollback mechanisms
  void rollbackTrip(Trip oldState) {
    _trips[oldState.id] = oldState;
    _tripController.add(_trips);
  }
}
