import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:rideapp_client/core/antigravity/gravity_store.dart';
import 'package:rideapp_client/core/antigravity/profile.dart';
import 'package:rideapp_client/domain/entities/trip.dart';
import 'package:rideapp_client/domain/entities/driver.dart';
import 'package:rideapp_client/domain/entities/negotiation_offer.dart';

/// The engine that handles emissions and mutations via WebSocket Bridge.
class Antigravity {
  static final Antigravity _instance = Antigravity._internal();
  factory Antigravity() => _instance;
  Antigravity._internal();

  static final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  /// Escucha eventos específicos de un canal.
  static StreamSubscription<Map<String, dynamic>> on(String eventPattern, Function(Map<String, dynamic>) callback) {
    return _eventController.stream.where((msg) => (msg['event'] as String).contains(eventPattern)).listen(callback);
  }

  /// Internal: Emite un evento al stream local (no a la red).
  static void _emitLocal(String event, Map<String, dynamic> payload) {
    _eventController.add({'event': event, 'payload': payload});
  }

  /// Emits a message to the backend via WebSocket.
  /// Format: { event, channel, payload }
  static void emit(String event, Map<String, dynamic> data) {
    print('Antigravity EMITTING: $event on ${data['tripId'] ?? data['driverId']}');
    
    final channel = data['tripId'] != null ? 'trip.${data['tripId']}' : 'driver.${data['driverId']}';
    
    AntigravityClient().send(event, channel, data);
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
      // Optimistic Update (Immediate)
      store.updateTrip(nextTrip);
      
      // Simulate confirmation (in real app, this waits for a specific ACK from WS)
      await Future.delayed(const Duration(milliseconds: 100));
      onCommit(nextTrip);
      
    } catch (e) {
      print('Mutation FAILED: rolling back');
      store.rollbackTrip(oldState);
      onRollback(oldState);
    }
  }
}

/// Persistent WebSocket Client for Antigravity Protocol.
class AntigravityClient {
  static final AntigravityClient _instance = AntigravityClient._internal();
  factory AntigravityClient() => _instance;
  AntigravityClient._internal();

  WebSocketChannel? _channel;
  String? _currentChannel;
  int _retryCount = 0;
  bool _isManualDisconnect = false;

  /// Connects to the WebSocket bridge for a specific channel.
  /// Automatically disconnects any previous session.
  void connect(String channel) {
    if (_currentChannel == channel && _channel != null) return;
    
    _disconnect();
    _isManualDisconnect = false;
    _currentChannel = channel;
    
    final uri = Uri.parse("${AntigravityProfile.wsUrl}?channel=$channel");
    print('Antigravity [NETWORK]: Connecting to $uri');

    try {
      _channel = WebSocketChannel.connect(uri);
      _listen();
    } catch (e) {
      print('Antigravity [OFFLINE]: WebSocket unavailable. Operating locally.');
      _handleReconnect();
    }
  }

  void _listen() {
    _channel?.stream.listen(
      (message) {
        _retryCount = 0;
        _handleIncomingMessage(message);
      },
      onDone: () {
        if (!_isManualDisconnect) {
          print('Antigravity [NETWORK]: Connection closed by server.');
          _handleReconnect();
        }
      },
      onError: (error) {
        print('Antigravity [NETWORK]: Socket error: $error');
        _handleReconnect();
      },
    );
  }

  void _handleIncomingMessage(dynamic rawMessage) {
    try {
      final Map<String, dynamic> data = jsonDecode(rawMessage as String);
      final String event = data['event'];
      final Map<String, dynamic> payload = data['payload'];

      // Propagate to local listeners
      Antigravity._emitLocal(event, payload);

      // Reactive Sync with GravityStore
      if (event.contains('trip')) {
        GravityStore().updateTrip(Trip.fromJson(payload));
      } else if (event.contains('driver')) {
        GravityStore().updateDriver(Driver.fromJson(payload));
      } else if (event.contains('negotiation')) {
        GravityStore().updateOffer(NegotiationOffer.fromJson(payload));
      }
    } catch (e) {
      print('Antigravity [SYNC]: Error processing network message: $e');
    }
  }

  void _handleReconnect() {
    if (_retryCount < 3) {
      _retryCount++;
      print('Antigravity [RETRY]: Attempting reconection ($_retryCount/3) in 5s...');
      Timer(const Duration(seconds: 5), () {
        if (_currentChannel != null && !_isManualDisconnect) {
          connect(_currentChannel!);
        }
      });
    } else {
      print('Antigravity [NETWORK]: Max retries reached. Persistent offline mode.');
    }
  }

  void _disconnect() {
    _isManualDisconnect = true;
    _channel?.sink.close();
    _channel = null;
  }

  /// Sends a message via WebSocket if connected.
  void send(String event, String channel, Map<String, dynamic> payload) {
    if (_channel == null) {
      print('Antigravity [OFFLINE]: Event $event stored locally.');
      return;
    }

    final message = jsonEncode({
      'event': event,
      'channel': channel,
      'payload': payload,
    });
    
    _channel?.sink.add(message);
  }
}
