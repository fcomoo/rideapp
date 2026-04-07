import 'dart:async';
import 'package:rideapp_client/core/antigravity/client.dart';
import 'package:rideapp_client/domain/entities/trip.dart';
import 'package:rideapp_client/domain/value_objects/coordinates.dart';

/// 1. TripRequestProtocol: Emission of new trip requests with optimistic state.
class TripRequestProtocol {
  static void requestTrip({
    required Trip trip,
    required Coordinates origin,
    required Coordinates destination,
    required double offeredPrice,
    Function(String message)? onError,
  }) {
    // Optimistic mutation with rollback support
    Antigravity.mutateTrip(
      currentTrip: trip,
      nextTrip: trip.copyWith(status: TripStatus.requested),
      onCommit: (newTrip) {
        // Broadcast to backend upon successful local commit
        Antigravity.emit('trip.requested', {
          'tripId': newTrip.id,
          'origin': {'lat': origin.latitude, 'lng': origin.longitude},
          'destination': {'lat': destination.latitude, 'lng': destination.longitude},
          'offeredPrice': offeredPrice,
        });
      },
      onRollback: (oldState) {
        print('TripRequestProtocol: Rollback to requested status failed.');
        onError?.call('No se pudo solicitar el viaje. Intenta de nuevo.');
      },
    );
  }
}

/// 2. TripAcceptProtocol: Atomic transition to ACCEPTED status by a driver.
class TripAcceptProtocol {
  static void acceptTrip({
    required Trip trip,
    required String driverId,
    required int etaInMinutes,
  }) {
    final nextState = trip.copyWith(
      status: TripStatus.accepted,
      driverId: driverId,
    );

    Antigravity.mutateTrip(
      currentTrip: trip,
      nextTrip: nextState,
      onCommit: (acceptedTrip) {
        Antigravity.emit('trip.accepted', {
          'tripId': acceptedTrip.id,
          'driverId': driverId,
          'eta': etaInMinutes,
        });
      },
      onRollback: (oldState) {
        print('TripAcceptProtocol: Atomic acceptance failed, driverId reverted.');
      },
    );
  }
}

/// 3. LocationBroadcastProtocol: Periodic driver location updates.
class LocationBroadcastProtocol {
  Timer? _timer;

  void startBroadcasting({
    required String driverId,
    required Coordinates Function() getLatestLocation,
    required Duration interval,
  }) {
    _timer?.cancel();

    _timer = Timer.periodic(interval, (timer) {
      final location = getLatestLocation();
      
      Antigravity.emit('driver.location', {
        'driverId': driverId,
        'coords': {
          'lat': location.latitude,
          'lng': location.longitude,
        },
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
