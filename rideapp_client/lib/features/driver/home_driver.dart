import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rideapp_client/core/antigravity/client.dart';
import 'package:rideapp_client/core/antigravity/gravity_store.dart';
import 'package:rideapp_client/core/config/app_config.dart';
import 'package:rideapp_client/core/services/driver_location_service.dart';
import 'package:rideapp_client/domain/entities/trip.dart';
import 'package:rideapp_client/domain/entities/driver.dart';
import 'package:rideapp_client/domain/value_objects/coordinates.dart';
import 'package:rideapp_client/features/negotiation/driver_offer_screen.dart';
import 'package:rideapp_client/features/rating/rating_screen.dart';
import 'package:rideapp_client/features/profile/driver_profile_screen.dart';
import 'package:rideapp_client/core/services/auth_service.dart';

class HomeDriver extends StatefulWidget {
  final String driverId;
  const HomeDriver({super.key, required this.driverId});

  @override
  State<HomeDriver> createState() => _HomeDriverState();
}

class _HomeDriverState extends State<HomeDriver> {
  final MapController _mapController = MapController();
  bool _isOnline = false;
  StreamSubscription? _statusSub;
  LatLng _lastKnownCenter = AppConfig.macuspanaCenter;

  @override
  void initState() {
    super.initState();
    _listenToRequests();
    
    // Inicializar estado local en el GravityStore si no existe
    if (GravityStore().currentDrivers[widget.driverId] == null) {
      GravityStore().updateDriver(Driver(
        id: widget.driverId,
        vehicleDetails: {'model': 'Tesla Model 3', 'plate': 'AG-2026'},
        currentLocation: Coordinates(AppConfig.macuspanaCenter.latitude, AppConfig.macuspanaCenter.longitude),
        rating: 4.9,
      ));
    }
    
    // Conectar al canal de solicitudes globales al entrar
    AntigravityClient().connect('trips.requests');
  }

  void _listenToRequests() {
    // Escuchar solicitudes de viaje vía Antigravity
    Antigravity.on('trip.requested', (data) {
      if (!_isOnline) return;
      try {
        final tripData = data['payload'] ?? data;
        print('Driver received trip request: $tripData');
        
        // El payload de la red es mínimo, construimos el Trip manualmente
        final trip = Trip(
          id: (tripData['tripId'] ?? tripData['id'] ?? 'trip-unknown').toString(),
          clientId: (tripData['clientId'] ?? 'client-unknown').toString(),
          driverId: null,
          status: TripStatus.requested,
          route: [],
        );
        
        // Extraer el precio ofrecido
        final offeredPrice = (tripData['offeredPrice'] as num?)?.toDouble() ?? 25.0;

        if (!mounted) return;
        _showRequestBottomSheet(trip, offeredPrice);
      } catch (e) {
        print('Error parsing trip request: $e');
        print('Raw data received: $data');
      }
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

  void _showRequestBottomSheet(Trip trip, double offeredPrice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DriverOfferScreen(
        trip: trip, 
        driverId: widget.driverId,
        suggestedPrice: offeredPrice,
      ),
    );
  }

  void _showRatingScreen(Trip trip) {
    if (!mounted) return;
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
    _mapController.dispose();
    
    // Al salir del panel de conductor, volver al canal de ubicaciones general
    AntigravityClient().connect('drivers.locations');
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // 1. MAPA PRINCIPAL
          StreamBuilder<Position>(
            stream: Geolocator.getPositionStream(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 5,
              ),
            ),
            builder: (context, snapshot) {
              final pos = snapshot.hasData 
                  ? LatLng(snapshot.data!.latitude, snapshot.data!.longitude)
                  : _lastKnownCenter;
              
              _lastKnownCenter = pos;

              return FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: pos,
                  initialZoom: 15.0,
                  backgroundColor: const Color(0xFF121212),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.rideapp.client',
                    tileBuilder: (context, tileWidget, tile) {
                      return ColorFiltered(
                        colorFilter: const ColorFilter.matrix([
                          -1, 0, 0, 0, 255,
                          0, -1, 0, 0, 255,
                          0, 0, -1, 0, 255,
                          0, 0, 0, 1, 0,
                        ]),
                        child: tileWidget,
                      );
                    },
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: pos,
                        width: 60,
                        height: 60,
                        child: _buildDriverMarker(),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),

          // 2. OVERLAY SUPERIOR (AppBar)
          _buildTopOverlay(),

          // 3. OVERLAY INFERIOR (Estado)
          _buildBottomOverlay(),
        ],
      ),
    );
  }

  Widget _buildDriverMarker() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFF6B00),
            borderRadius: BorderRadius.circular(8),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
          child: const Text('TÚ', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        const Icon(Icons.directions_car, color: Color(0xFFFF6B00), size: 40),
      ],
    );
  }

  Widget _buildTopOverlay() {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 20, right: 20, bottom: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('PANEL CONDUCTOR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 18)),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.person_rounded, color: Color(0xFFFF6B00), size: 24),
                      onPressed: () {
                        final user = AuthService().currentUser;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DriverProfileScreen(
                              userId: user?['id'] ?? widget.driverId,
                              name: user?['name'],
                              email: user?['email'],
                              phone: user?['phone'],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: _isOnline ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: (_isOnline ? Colors.green : Colors.red).withOpacity(0.5), blurRadius: 4, spreadRadius: 2)
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isOnline ? 'EN LÍNEA' : 'FUERA DE LÍNEA',
                      style: TextStyle(color: _isOnline ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
            Switch(
              value: _isOnline,
              onChanged: (val) async {
                setState(() => _isOnline = val);
                if (val) {
                  // Conectar al canal global de solicitudes
                  AntigravityClient().connect('trips.requests');
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
      ),
    );
  }

  Widget _buildBottomOverlay() {
    return Positioned(
      bottom: 40, left: 20, right: 20,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 10))],
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  _isOnline ? Icons.radar : Icons.power_settings_new,
                  color: _isOnline ? const Color(0xFFFF6B00) : Colors.white24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isOnline ? 'ESPERANDO SOLICITUDES...' : 'MODO DESCONECTADO',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isOnline ? 'Buscando pasajeros en Macuspana' : 'Activa el switch para recibir viajes',
                        style: const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (_isOnline)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B00))),
              ],
            ),
            if (_isOnline) ...[
              const Divider(color: Colors.white10, height: 32),
              StreamBuilder<Position>(
                stream: Geolocator.getPositionStream(),
                builder: (context, snapshot) {
                  final lat = snapshot.data?.latitude.toStringAsFixed(6) ?? '--';
                  final lng = snapshot.data?.longitude.toStringAsFixed(6) ?? '--';
                  return Text(
                    'GPS: $lat, $lng',
                    style: const TextStyle(color: Colors.white24, fontSize: 10, fontFamily: 'monospace'),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
