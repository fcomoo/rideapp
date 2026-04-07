import 'dart:async';
import 'package:rideapp_client/core/antigravity/gravity_store.dart';
import 'package:rideapp_client/domain/entities/trip.dart';

/// The engine that handles emissions and mutations.
class Antigravity {
  static final Antigravity _instance = Antigravity._internal();
  factory Antigravity() => _instance;
  Antigravity._internal();

  /// Emits a message to the backend (Redis Pub/Sub).
  /// In this mock implementation, we handle trip searches and locations.
  static void emit(String event, Map<String, dynamic> data) async {
    print('Antigravity EMITTING: $event, payload: $data');
    // Integration with Redis Pub/Sub through a WebSocket bridge or similar.
  }

  /// High-performance mutation with mandatory onRollback block.
  /// Used for optimistic UI updates.
  static void mutateTrip({
    required Trip currentTrip,
    required Trip nextTrip,
    required Function(Trip trip) onCommit,
    required Function(Trip oldState) onRollback,
  }) async {
    final oldState = currentTrip;
    final store = GravityStore();

    try {
      // Optimistic Update
      store.updateTrip(nextTrip);
      
      // Simulate backend response
      bool success = await _fakeBackendCommit(nextTrip);
      
      if (success) {
        onCommit(nextTrip);
      } else {
        throw Exception('Commit failed');
      }
    } catch (e) {
      print('Mutation FAILED: rolling back');
      store.rollbackTrip(oldState);
      onRollback(oldState);
    }
  }

  static Future<bool> _fakeBackendCommit(Trip trip) async {
    // Simulate latency
    await Future.delayed(Duration(milliseconds: 300));
    return true; // Assume success for demo
  }
}
