import 'dart:async';
import 'package:rideapp_client/core/antigravity/client.dart';
import 'package:rideapp_client/core/antigravity/gravity_store.dart';
import 'package:rideapp_client/core/antigravity/kill_switch.dart';
import 'package:rideapp_client/core/utils/geo_utils.dart';
import 'package:rideapp_client/domain/entities/trip.dart';
import 'package:rideapp_client/domain/value_objects/coordinates.dart';

/// 1. PassengerSubscription: Reactividad para el pasajero.
class PassengerSubscription {
  final String tripId;
  final GravityStore _store = GravityStore();
  final KillSwitch _killSwitch = KillSwitch();
  StreamSubscription? _subscription;
  
  // Stream de estado del viaje con soporte offline-first (Map en memoria)
  Stream<Trip?> get tripStream => _store.tripsStream
      .map((trips) => trips[tripId])
      .distinct();

  PassengerSubscription(this.tripId);

  /// Inicia la escucha y activa el KillSwitch si el viaje está en búsqueda.
  void subscribe() {
    // Estado inicial de la memoria (Offline-first)
    final trip = _store.currentTrips[tripId];
    
    if (trip != null && trip.status == TripStatus.requested) {
      _activateKillSwitch(trip);
    }

    // Escuchar cambios futuros
    _subscription = _store.tripsStream.listen((trips) {
      final updatedTrip = trips[tripId];
      if (updatedTrip != null) {
        if (updatedTrip.status == TripStatus.accepted) {
          print('PassengerSubscription: Trip ACCEPTED. Cancelling kill switch.');
          _killSwitch.cancel();
        }
      }
    });
  }

  void _activateKillSwitch(Trip trip) {
    _killSwitch.startSearchTimeout(
      trip: trip,
      onTimeout: () {
        print('PassengerSubscription: Tiempo de espera agotado (60s).');
      },
    );
  }

  /// Limpieza de suscripciones para evitar memory leaks.
  void dispose() {
    print('PassengerSubscription: Disposing resources for trip $tripId.');
    _subscription?.cancel();
    _killSwitch.cancel();
  }
}

/// 2. DriverSubscription: Reactividad y Seguridad para el conductor.
class DriverSubscription {
  final String driverId;
  final GravityStore _store = GravityStore();
  
  // Controlador para emitir viajes cercanos filtrados
  final _nearbyTripsController = StreamController<List<Trip>>.broadcast();
  
  // Tracking interno para anti-spoofing
  Coordinates? _lastLocation;
  int? _lastTimestamp;

  DriverSubscription(this.driverId);

  Stream<List<Trip>> get nearbyTripsStream => _nearbyTripsController.stream;

  /// Inicia la escucha de viajes REQUESTED en radio de 5km.
  void initTripListener(Coordinates driverLocation) {
    _store.tripsStream.listen((trips) {
      final nearby = trips.values.where((trip) {
        if (trip.status != TripStatus.requested) return false;
        
        // Asumiendo que el primer punto de la ruta es el origen
        if (trip.route.isEmpty) return false;
        
        // Uso de GeoUtils nativo (Haversine)
        final distance = GeoUtils.calculateDistance(
          driverLocation, 
          trip.route.first,
        );
        
        return distance <= 5000; // Radio de 5km
      }).toList();
      
      _nearbyTripsController.add(nearby);
    });
  }

  /// Procesa actualizaciones de ubicación con Anti-spoofing nativo.
  bool validateLocationSecurity(Coordinates newLocation) {
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_lastLocation != null && _lastTimestamp != null) {
      // Uso de GeoUtils para determinar velocidad
      final double speedKmh = GeoUtils.calculateSpeedKmh(
        oldLocation: _lastLocation!,
        oldTimestamp: _lastTimestamp!,
        newLocation: newLocation,
        newTimestamp: now,
      );

      // Anti-spoofing: máximo 200km/h
      if (speedKmh > 200) {
        print('SECURITY ALERT: Anti-spoofing detectado ($speedKmh km/h).');
        
        Antigravity.emit('security.spoofing_detected', {
          'driverId': driverId,
          'detectedSpeed': speedKmh,
          'timestamp': now,
        });
        
        return false; // Descartar actualización
      }
    }

    // Actualización válida
    _lastLocation = newLocation;
    _lastTimestamp = now;
    return true;
  }

  void dispose() {
    _nearbyTripsController.close();
  }
}
