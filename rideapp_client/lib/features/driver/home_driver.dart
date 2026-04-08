import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rideapp_client/core/antigravity/client.dart';
import 'package:rideapp_client/core/antigravity/gravity_store.dart';
import 'package:rideapp_client/domain/entities/trip.dart';
import 'package:rideapp_client/domain/entities/driver.dart';
import 'package:rideapp_client/domain/value_objects/coordinates.dart';
import 'package:rideapp_client/features/negotiation/driver_offer_screen.dart';
import 'package:rideapp_client/core/services/driver_location_service.dart';
import 'package:rideapp_client/features/rating/rating_screen.dart';

class HomeDriver extends StatefulWidget {
  final String driverId;
  const HomeDriver({super.key, required this.driverId});

  @override
  State<HomeDriver> createState() => _HomeDriverState();
}

class _HomeDriverState extends State<HomeDriver> {
  bool _isOnline = false;
  StreamSubscription? _statusSub;

  @override
  void initState() {
    super.initState();
    _listenToRequests();
    
    // Inicializar estado local en el GravityStore
    if (GravityStore().currentDrivers[widget.driverId] == null) {
      GravityStore().updateDriver(Driver(
        id: widget.driverId,
        vehicleDetails: {'model': 'Tesla Model 3', 'plate': 'AG-2026'},
        currentLocation: Coordinates(17.7600, -92.5950),
        rating: 4.9,
      ));
    }
  }

  void _listenToRequests() {
    // Escuchar el canal de solicitudes del conductor
    Antigravity.on('driver.${widget.driverId}.request', (data) {
      if (!_isOnline) return;
      final trip = Trip.fromJson(data['trip']);
      _showRequestBottomSheet(trip);
    });

    // Escuchar cambios en viajes completados para calificar
    _statusSub = GravityStore().tripsStream.listen((trips) {
      final completedTrip = trips.values.where((t) => 
        t.driverId == widget.driverId && 
        t.status == TripStatus.completed
      ).firstOrNull;

      if (completedTrip != null) {
        _showRatingScreen(completedTrip);
      }
    });
  }

  void _showRequestBottomSheet(Trip trip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverOfferScreen(
          trip: trip, 
          driverId: widget.driverId,
          suggestedPrice: (trip as dynamic).offeredPrice ?? 35.0,
        ),
      ),
    );
  }

  void _showRatingScreen(Trip trip) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RatingScreen(
          tripId: trip.id,
          ratedUserId: trip.clientId,
          ratedUserName: "Pasajero",
          ratedBy: 'driver',
        ),
      ),
    ).then((_) => GravityStore().removeTrip(trip.id));
  }

  @override
  void dispose() {
    DriverLocationService().stopTracking();
    _statusSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('PANEL CONDUCTOR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Switch(
            value: _isOnline,
            onChanged: (val) async {
              setState(() => _isOnline = val);
              if (val) {
                await DriverLocationService().startTracking(widget.driverId);
                Antigravity.emit('driver.online', {'driverId': widget.driverId});
              } else {
                DriverLocationService().stopTracking();
                Antigravity.emit('driver.offline', {'driverId': widget.driverId});
              }
            },
            activeColor: const Color(0xFFFF6B00),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isOnline ? Icons.online_prediction : Icons.offline_bolt,
              size: 100,
              color: _isOnline ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 24),
            Text(
              _isOnline ? 'ESTÁS EN LÍNEA' : 'ESTÁS FUERA DE LÍNEA',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              _isOnline ? 'Esperando solicitudes de viaje...' : 'Conéctate para recibir viajes',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
            if (_isOnline) ...[
              const SizedBox(height: 48),
              const Text(
                'COMPARTIENDO UBICACIÓN EN TIEMPO REAL',
                style: TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1),
              ),
              const SizedBox(height: 16),
              StreamBuilder<Position>(
                stream: Geolocator.getPositionStream(
                  locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10)
                ),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        'LAT: ${snapshot.data!.latitude.toStringAsFixed(6)} | LNG: ${snapshot.data!.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(color: Colors.white60, fontSize: 12, fontFamily: 'monospace'),
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
