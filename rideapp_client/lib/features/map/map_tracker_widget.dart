import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
  GoogleMapController? _mapController;
  
  // Tracking para el throttle manual de 1000ms
  DateTime? _lastEmitTime;
  
  // Marcadores reactivos (Google Maps LatLng)
  final Set<Marker> _markers = {};
  
  // Estado inicial offline-first desde el GravityStore
  Trip? _initialState;

  @override
  void initState() {
    super.initState();
    _subscription = PassengerSubscription(widget.tripId);
    _subscription.subscribe();
    
    // Recuperar estado inicial inmediatamente para renderizado instantáneo
    _initialState = GravityStore().currentTrips[widget.tripId];
    if (_initialState != null && _initialState!.route.isNotEmpty) {
      _updateDriverMarker(_initialState!.route.last);
    }
  }

  @override
  void dispose() {
    _subscription.dispose();
    super.dispose();
  }

  /// Convierte el Value Object de dominio a la clase de la UI (Google Maps)
  LatLng _toLatLng(Coordinates coords) {
    return LatLng(coords.latitude, coords.longitude);
  }

  /// Procesa el flujo de datos aplicando el throttle manual
  Stream<Trip?> _getThrottledStream() {
    return _subscription.tripStream.where((trip) {
      if (trip == null) return false;
      
      final now = DateTime.now();
      if (_lastEmitTime == null || 
          now.difference(_lastEmitTime!) >= const Duration(milliseconds: 1000)) {
        _lastEmitTime = now;
        return true;
      }
      return false;
    });
  }

  void _updateDriverMarker(Coordinates position) {
    final latLng = _toLatLng(position);
    
    setState(() {
      _markers.add(
        Marker(
          markerId: const MarkerId('driver_marker'),
          position: latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Tu Conductor'),
        ),
      );
    });

    // Animar cámara suavemente si el controlador está listo
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(latLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Trip?>(
      stream: _getThrottledStream(),
      initialData: _initialState,
      builder: (context, snapshot) {
        final trip = snapshot.data;
        
        if (trip != null && trip.route.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _updateDriverMarker(trip.route.last);
          });
        }

        return GoogleMap(
          initialCameraPosition: CameraPosition(
            target: trip != null && trip.route.isNotEmpty 
                ? _toLatLng(trip.route.last) 
                : const LatLng(0, 0),
            zoom: 15,
          ),
          markers: _markers,
          onMapCreated: (controller) => _mapController = controller,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        );
      },
    );
  }
}
