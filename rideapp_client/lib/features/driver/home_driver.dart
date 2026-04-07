import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rideapp_client/core/antigravity/client.dart';
import 'package:rideapp_client/core/antigravity/gravity_store.dart';
import 'package:rideapp_client/core/antigravity/profile.dart';
import 'package:rideapp_client/core/protocols/trip_protocol.dart';
import 'package:rideapp_client/core/subscriptions/trip_subscription.dart';
import 'package:rideapp_client/domain/entities/trip.dart';
import 'package:rideapp_client/domain/entities/driver.dart';
import 'package:rideapp_client/domain/value_objects/coordinates.dart';
import 'package:rideapp_client/features/map/map_tracker_widget.dart';
import 'package:rideapp_client/core/utils/geo_utils.dart';

class HomeDriver extends StatefulWidget {
  final String driverId;

  const HomeDriver({super.key, required this.driverId});

  @override
  State<HomeDriver> createState() => _HomeDriverState();
}

class _HomeDriverState extends State<HomeDriver> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  late DriverSubscription _driverSubscription;
  final LocationBroadcastProtocol _broadcastProtocol = LocationBroadcastProtocol();
  StreamSubscription<Position>? _positionStream;
  Timer? _simulationTimer;
  double _currentHeading = 0.0;
  
  // Mock Passengers (Macuspana area)
  final List<Coordinates> _mockPassengers = [
    Coordinates(17.7628, -92.5900),
    Coordinates(17.7580, -92.5850),
    Coordinates(17.7650, -92.6000),
  ];

  @override
  void initState() {
    super.initState();
    _driverSubscription = DriverSubscription(widget.driverId);
    
    // Listen for requests on driver.{driverId}
    Antigravity.on('driver.${widget.driverId}.request', (data) {
      final trip = Trip.fromJson(data['trip']);
      _showRequestBottomSheet(trip);
    });

    // Initial state setup in GravityStore if not present
    if (GravityStore().currentDrivers[widget.driverId] == null) {
      GravityStore().updateDriver(Driver(
        id: widget.driverId,
        vehicleDetails: {'model': 'Tesla Model 3', 'plate': 'AG-2026'},
        currentLocation: Coordinates(17.7600, -92.5950),
        rating: 4.9,
      ));
    }
  }

  @override
  void dispose() {
    _stopBroadcasting();
    _driverSubscription.dispose();
    super.dispose();
  }

  Future<void> _toggleOnline(bool value) async {
    final store = GravityStore();
    final currentDriver = store.currentDrivers[widget.driverId]!;
    
    if (value) {
      final hasPermission = await _handlePermissions();
      if (!hasPermission) return;
      _startBroadcasting();
      
      // Notify backend
      Antigravity.emit('driver.status', {
        'driverId': widget.driverId,
        'status': 'online',
        'location': currentDriver.currentLocation.toJson(),
      });
      
      store.updateDriver(currentDriver.copyWith(isOnline: true));
      _startMovementSimulation();
    } else {
      _stopBroadcasting();
      _stopMovementSimulation();
      
      Antigravity.emit('driver.status', {
        'driverId': widget.driverId,
        'status': 'offline',
      });
      
      store.updateDriver(currentDriver.copyWith(isOnline: false));
    }
  }

  void _startMovementSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      final store = GravityStore();
      final currentDriver = store.currentDrivers[widget.driverId];
      if (currentDriver == null || !currentDriver.isOnline) {
        timer.cancel();
        return;
      }

      // Variación controlada de coordenadas (±0.0005 para realismo en 3s)
      final double latMove = (DateTime.now().millisecond % 10 - 5) * 0.0001;
      final double lngMove = (DateTime.now().second % 10 - 5) * 0.0001;
      
      final newCoords = Coordinates(
        currentDriver.currentLocation.latitude + latMove,
        currentDriver.currentLocation.longitude + lngMove,
      );

      // Calcular dirección (Heading)
      _currentHeading = GeoUtils.calculateBearing(
        currentDriver.currentLocation,
        newCoords,
      );

      // Emitir al canal global drivers.locations
      Antigravity.emit('driver.location', {
        'driverId': widget.driverId,
        'lat': newCoords.latitude,
        'lng': newCoords.longitude,
        'heading': _currentHeading,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Actualizar estado local
      store.updateDriver(currentDriver.copyWith(currentLocation: newCoords));
      _mapController.move(LatLng(newCoords.latitude, newCoords.longitude), _mapController.camera.zoom);
    });
  }

  void _stopMovementSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
  }

  Future<bool> _handlePermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showErrorSnackBar('Permiso de ubicación denegado.');
        return false;
      }
    }
    return true;
  }

  void _startBroadcasting() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position position) {
      final newCoords = Coordinates(position.latitude, position.longitude);
      final store = GravityStore();
      final currentDriver = store.currentDrivers[widget.driverId]!;

      // Anti-spoofing validation
      final speedKmh = GeoUtils.calculateSpeedKmh(
        oldLocation: currentDriver.currentLocation,
        oldTimestamp: DateTime.now().subtract(const Duration(seconds: 5)).millisecondsSinceEpoch,
        newLocation: newCoords,
        newTimestamp: DateTime.now().millisecondsSinceEpoch,
      );

      if (speedKmh <= 200.0) {
        _broadcastProtocol.startBroadcasting(
          driverId: widget.driverId,
          getLatestLocation: () => newCoords,
          interval: AntigravityProfile.gpsInterval,
        );
        store.updateDriver(currentDriver.copyWith(currentLocation: newCoords));
        _mapController.move(LatLng(newCoords.latitude, newCoords.longitude), 14);
      } else {
        _showErrorSnackBar("Velocidad inusual detectada. Ubicación ignorada.");
      }
    });
  }

  void _stopBroadcasting() {
    _positionStream?.cancel();
    _broadcastProtocol.stop();
  }

  void _showRequestBottomSheet(Trip trip) {
    int countdown = 30;
    Timer? timer;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: const Color(0xFF1C1C1C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (countdown > 0) {
                setModalState(() => countdown--);
              } else {
                t.cancel();
                Navigator.pop(context);
                Antigravity.emit('driver.timeout', {'tripId': trip.id, 'driverId': widget.driverId});
              }
            });

            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("NUEVA SOLICITUD", style: TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 18)),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFFF6B00).withOpacity(0.2), shape: BoxShape.circle),
                        child: Text("$countdown", style: const TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildRequestInfo(Icons.my_location, "Origen", "Av. Reforma #123"),
                  const SizedBox(height: 12),
                  _buildRequestInfo(Icons.location_on, "Destino", "Polanco, Calle Horacio"),
                  const Divider(color: Colors.white10, height: 32),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: () { timer?.cancel(); Navigator.pop(context); }, style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24), padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text("RECHAZAR", style: TextStyle(color: Colors.white70)))),
                      const SizedBox(width: 12),
                      Expanded(child: ElevatedButton(onPressed: () { timer?.cancel(); Navigator.pop(context); TripAcceptProtocol.acceptTrip(trip: trip, driverId: widget.driverId, etaInMinutes: 5); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00), padding: const EdgeInsets.symmetric(vertical: 16)), child: const Text("ACEPTAR"))),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRequestInfo(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 20),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)), Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))]),
      ],
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, Driver>>(
      stream: GravityStore().driversStream,
      builder: (context, snapshot) {
        final driver = snapshot.data?[widget.driverId] ?? GravityStore().currentDrivers[widget.driverId]!;
        final activeTrip = GravityStore().currentTrips.values.where((t) => 
          t.driverId == widget.driverId && (t.status == TripStatus.accepted || t.status == TripStatus.inProgress)
        ).firstOrNull;

        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          body: Stack(
            children: [
              activeTrip != null 
                ? MapTrackerWidget(tripId: activeTrip.id)
                : _buildRadarMap(driver),
              _buildTopPanel(driver),
              Align(alignment: Alignment.bottomCenter, child: _buildBottomPanel(driver, activeTrip)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRadarMap(Driver driver) {
    final List<Marker> markers = [];
    
    // Driver marker
    markers.add(Marker(
      point: LatLng(driver.currentLocation.latitude, driver.currentLocation.longitude),
      width: 60,
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2196F3).withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: driver.isOnline ? Colors.green : Colors.grey, width: 3),
            ),
          ),
          Transform.rotate(
            angle: _currentHeading * (3.14159 / 180),
            child: const Icon(Icons.drive_eta, color: Colors.blue, size: 28),
          ),
        ],
      ),
    ));

    // Mock Passengers (only if Online)
    if (driver.isOnline) {
      for (var p in _mockPassengers) {
        final distance = GeoUtils.calculateDistance(driver.currentLocation, p);
        if (distance <= 5000) { // Radio de 5km
          markers.add(Marker(
            point: LatLng(p.latitude, p.longitude),
            width: 40,
            height: 40,
            child: const Icon(Icons.person_pin_circle, color: Color(0xFFFF6B00), size: 32),
          ));
        }
      }
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: const LatLng(17.7600, -92.5950),
        initialZoom: 14.0,
        backgroundColor: const Color(0xFF121212),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.rideapp.client',
          maxZoom: 18,
        ),
        MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildTopPanel(Driver driver) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFF1C1C1C), borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)]),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: driver.isOnline ? Colors.green : Colors.grey, shape: BoxShape.circle)),
                  const SizedBox(width: 12),
                  Text(driver.isOnline ? "CONECTADO" : "DESCONECTADO", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(width: 12),
                  Switch(value: driver.isOnline, onChanged: _toggleOnline, activeColor: const Color(0xFFFF6B00)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel(Driver driver, Trip? activeTrip) {
    if (activeTrip != null) return _buildActiveTripPanel(activeTrip);
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Color(0xFF1C1C1C), borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStat("Solicitudes", "${driver.nearbyCount}", Icons.radar),
          _buildStat("Ganancias", "\$${driver.dailyEarnings.toStringAsFixed(2)}", Icons.account_balance_wallet),
          _buildStat("Puntuación", "${driver.rating}", Icons.star),
        ],
      ),
    );
  }

  Widget _buildStat(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFFFF6B00), size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      ],
    );
  }

  Widget _buildActiveTripPanel(Trip trip) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Color(0xFF1C1C1C), borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(trip.status == TripStatus.accepted ? "YENDO POR PASAJERO" : "VIAJE EN CURSO", style: const TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: trip.status == TripStatus.accepted ? const Color(0xFFFF6B00) : Colors.green, minimumSize: const Size(double.infinity, 54), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () {
              if (trip.status == TripStatus.accepted) {
                Antigravity.mutateTrip(currentTrip: trip, nextTrip: trip.copyWith(status: TripStatus.inProgress), onCommit: (t) => Antigravity.emit('trip.in_progress', {'t.id': t.id}), onRollback: (_) => _showErrorSnackBar("Error"));
              } else {
                Antigravity.mutateTrip(currentTrip: trip, nextTrip: trip.copyWith(status: TripStatus.completed), onCommit: (t) => Antigravity.emit('trip.completed', {'t.id': t.id}), onRollback: (_) => _showErrorSnackBar("Error"));
              }
            },
            child: Text(trip.status == TripStatus.accepted ? "RECOGER PASAJERO" : "FINALIZAR VIAJE", style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
