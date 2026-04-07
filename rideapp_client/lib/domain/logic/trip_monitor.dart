import 'dart:async';
import 'package:rideapp_client/core/antigravity/client.dart';
import 'package:rideapp_client/core/antigravity/profile.dart';
import 'package:rideapp_client/domain/entities/trip.dart';

/// Monitoring service for Trip lifecycle events.
class TripMonitor {
  static final TripMonitor _instance = TripMonitor._internal();
  factory TripMonitor() => _instance;
  TripMonitor._internal();

  final Map<String, Timer> _activeKillSwitches = {};

  /// Start a 60s kill switch for a searching trip.
  void startSearchKillSwitch(Trip currentTrip) {
    // If already monitoring this trip, cancel existing timer
    _activeKillSwitches[currentTrip.id]?.cancel();

    print('Kill Switch INITIATED for Trip: ${currentTrip.id}');

    _activeKillSwitches[currentTrip.id] = Timer(
      AntigravityProfile.searchTimeout, 
      () {
        _executeKillSwitch(currentTrip);
      }
    );
  }

  void _executeKillSwitch(Trip currentTrip) {
    // Requirement implementation:
    // If trip status is searching (requested) and 60s elapsed
    if (currentTrip.status == TripStatus.requested) {
      print('Kill Switch TRIGGERED: 60s elapsed for Trip ${currentTrip.id}');
      
      Antigravity.emit('cancel_search', {
        'tripId': currentTrip.id,
        'reason': 'timeout_reached',
      });

      // Cleanup
      _activeKillSwitches.remove(currentTrip.id);
    }
  }

  void cancelKillSwitch(String tripId) {
    _activeKillSwitches[tripId]?.cancel();
    _activeKillSwitches.remove(tripId);
  }
}
