import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong2.dart' as ll;
import 'package:rideapp_client/core/antigravity/gravity_store.dart';
import 'package:rideapp_client/core/subscriptions/trip_subscription.dart';
import 'package:rideapp_client/domain/entities/trip.dart';
import 'package:rideapp_client/domain/value_objects/coordinates.dart';

class MapTrackerWidget extends StatefulWidget {
  final String tripId;

  const MapTrackerWidget({super.key, required this.tripId});

  @override
  State<MapTrackerWidget> createState() => _MapTrackerWidgetState();
}

class _MapTrackerWidgetState extends State<MapTrackerWidget> {
  late PassengerSubscription _subscription;
  final MapController _mapController = MapController();
  
  DateTime? _lastEmitTime;
  Trip? _initialState;

  @override
  void initState() {
    super.initState();
    _subscription = PassengerSubscription(widget.tripId);
    _subscription.subscribe();
    
    _initialState = GravityStore().currentTrips[widget.tripId];
  }

  @override
  void dispose() {
    _subscription.dispose();
    super.dispose();
  }

  /// Conversión UI-only a LatLng de latlong2
  ll.LatLng _toLatLng(Coordinates coords) {
    return ll.LatLng(coords.latitude, coords.longitude);
  }

  Stream<Trip?> _getThrottledStream() {
    return _subscription.tripStream.where((trip) {
      if (trip == null) return false;
      final now = DateTime.now();
      if (_lastEmitTime == null || now.difference(_lastEmitTime!) >= const Duration(milliseconds: 1000)) {
        _lastEmitTime = now;
        return true;
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Trip?>(
      stream: _getThrottledStream(),
      initialData: _initialState,
      builder: (context, snapshot) {
        final trip = snapshot.data;
        final List<ll.LatLng> polyPoints = trip?.route.map(_toLatLng).toList() ?? [];
        final lastPoint = polyPoints.isNotEmpty ? polyPoints.last : ll.LatLng(0, 0);

        // Actualizar centro del mapa automáticamente en cada actualización throttled
        if (trip != null && polyPoints.isNotEmpty) {
           WidgetsBinding.instance.addPostFrameCallback((_) {
             _mapController.move(lastPoint, 15);
           });
        }

        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: lastPoint,
            initialZoom: 15,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.rideapp.client',
            ),
            if (polyPoints.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: polyPoints,
                    strokeWidth: 4,
                    color: const Color(0xFFFF6B00),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                if (polyPoints.isNotEmpty)
                  Marker(
                    point: lastPoint,
                    width: 40,
                    height: 40,
                    child: const Icon(Icons.drive_eta, color: Color(0xFFFF6B00), size: 30),
                  ),
                if (polyPoints.isNotEmpty)
                   Marker(
                     point: polyPoints.first,
                     width: 40,
                     height: 40,
                     child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 30),
                   ),
              ],
            ),
          ],
        );
      },
    );
  }
}
