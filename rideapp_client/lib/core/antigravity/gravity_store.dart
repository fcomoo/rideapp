import 'dart:async';
import 'package:rideapp_client/domain/entities/trip.dart';
import 'package:rideapp_client/domain/entities/driver.dart';
import 'package:rideapp_client/domain/entities/negotiation_offer.dart';
import 'package:rideapp_client/domain/entities/chat_message.dart';

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
  final _messageController = StreamController<Map<String, List<ChatMessage>>>.broadcast();
  final _unreadController = StreamController<Map<String, int>>.broadcast();
  
  final Map<String, Trip> _trips = {};
  final Map<String, Driver> _drivers = {};
  final Map<String, NegotiationOffer> _offers = {};
  final Map<String, List<ChatMessage>> _messages = {}; // tripId -> messages
  final Map<String, int> _unreadCounts = {}; // tripId -> count

  Stream<Map<String, Trip>> get tripsStream => _tripController.stream;
  Stream<Map<String, Driver>> get driversStream => _driverController.stream;
  Stream<Map<String, NegotiationOffer>> get offersStream => _offerController.stream;
  Stream<Map<String, List<ChatMessage>>> get messagesStream => _messageController.stream;
  Stream<Map<String, int>> get unreadStream => _unreadController.stream;
  
  Map<String, Trip> get currentTrips => Map.unmodifiable(_trips);
  Map<String, Driver> get currentDrivers => Map.unmodifiable(_drivers);
  Map<String, NegotiationOffer> get currentOffers => Map.unmodifiable(_offers);
  Map<String, List<ChatMessage>> get currentMessages => Map.unmodifiable(_messages);
  Map<String, int> get unreadCounts => Map.unmodifiable(_unreadCounts);

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

  void addMessage(ChatMessage message) {
    if (!_messages.containsKey(message.tripId)) {
      _messages[message.tripId] = [];
    }
    _messages[message.tripId]!.add(message);
    _messageController.add(_messages);

    // Incrementar no leídos si no estamos en el chat (la UI lo reseteará)
    _unreadCounts[message.tripId] = (_unreadCounts[message.tripId] ?? 0) + 1;
    _unreadController.add(_unreadCounts);
  }

  void resetUnread(String tripId) {
    _unreadCounts[tripId] = 0;
    _unreadController.add(_unreadCounts);
  }

  // To be used by rollback mechanisms
  void rollbackTrip(Trip oldState) {
    _trips[oldState.id] = oldState;
    _tripController.add(_trips);
  }
}
