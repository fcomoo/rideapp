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
  bool _isOnline = false;
  Coordinates? _currentPosition;
  
  late DriverSubscription _driverSubscription;
  final LocationBroadcastProtocol _broadcastProtocol = LocationBroadcastProtocol();
  StreamSubscription<Position>? _positionStream;
  
  late AnimationController _bannerController;
  late Animation<Offset> _bannerOffset;
  int _lastNearbyCount = 0;

  @override
  void initState() {
    super.initState();
    _driverSubscription = DriverSubscription(widget.driverId);
    
    _bannerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _bannerOffset = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _bannerController, curve: Curves.easeOut));

    _driverSubscription.nearbyTripsStream.listen((trips) {
      if (trips.length > _lastNearbyCount) {
        _showNewTripBanner();
      }
      _lastNearbyCount = trips.length;
    });
  }

  @override
  void dispose() {
    _stopBroadcasting();
    _driverSubscription.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _toggleOnline(bool value) async {
    if (value) {
      final hasPermission = await _handlePermissions();
      if (!hasPermission) return;
      _startBroadcasting();
      setState(() => _isOnline = true);
    } else {
      _stopBroadcasting();
      setState(() => _isOnline = false);
    }
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
    Geolocator.getCurrentPosition().then((pos) {
      final coords = Coordinates(pos.latitude, pos.longitude);
      _driverSubscription.initTripListener(coords);
      setState(() => _currentPosition = coords);
    });

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((Position position) {
      final newCoords = Coordinates(position.latitude, position.longitude);
      if (_driverSubscription.validateLocationSecurity(newCoords)) {
        _broadcastProtocol.startBroadcasting(
          driverId: widget.driverId,
          getLatestLocation: () => newCoords,
          interval: AntigravityProfile.gpsInterval,
        );
        setState(() => _currentPosition = newCoords);
      }
    });
  }

  void _stopBroadcasting() {
    _positionStream?.cancel();
    _broadcastProtocol.stop();
  }

  void _showNewTripBanner() {
    _bannerController.forward().then((_) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _bannerController.reverse();
      });
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          _buildMapContent(),
          SlideTransition(position: _bannerOffset, child: _buildNotificationBanner()),
          SafeArea(child: Padding(padding: const EdgeInsets.all(16.0), child: _buildStateToggle())),
          Align(alignment: Alignment.bottomCenter, child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: _buildBottomUI())),
        ],
      ),
    );
  }

  Widget _buildMapContent() {
    final activeTrip = GravityStore().currentTrips.values.where((t) => 
      t.driverId == widget.driverId && (t.status == TripStatus.accepted || t.status == TripStatus.inProgress)
    ).firstOrNull;
    if (activeTrip != null) return MapTrackerWidget(tripId: activeTrip.id);
    return Container(color: const Color(0xFF1C1C1C), child: const Center(child: Icon(Icons.map, color: Colors.white24, size: 60)));
  }

  Widget _buildStateToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1C), borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)]),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_isOnline ? "CONECTADO" : "DESCONECTADO", style: TextStyle(color: _isOnline ? const Color(0xFFFF6B00) : Colors.white60, fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Switch(value: _isOnline, onChanged: _toggleOnline, activeColor: const Color(0xFFFF6B00)),
        ],
      ),
    );
  }

  Widget _buildBottomUI() {
    return StreamBuilder<Map<String, Trip>>(
      stream: GravityStore().tripsStream,
      builder: (context, snapshot) {
        final trips = snapshot.data ?? GravityStore().currentTrips;
        final inProgressTrip = trips.values.where((t) => t.driverId == widget.driverId && (t.status == TripStatus.accepted || t.status == TripStatus.inProgress)).firstOrNull;
        if (inProgressTrip != null) return _buildInProgressSection(inProgressTrip);
        if (_isOnline) return _buildRadarSection();
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildRadarSection() {
    return StreamBuilder<List<Trip>>(
      stream: _driverSubscription.nearbyTripsStream,
      builder: (context, snapshot) {
        final nearbyTrips = snapshot.data ?? [];
        if (nearbyTrips.isEmpty) return _buildInfoPanel("Buscando viajes cercanos...");
        return Container(height: 250, padding: const EdgeInsets.symmetric(vertical: 20), child: PageView.builder(itemCount: nearbyTrips.length, controller: PageController(viewportFraction: 0.9), itemBuilder: (context, index) => _buildTripCard(nearbyTrips[index])));
      },
    );
  }

  Widget _buildTripCard(Trip trip) {
    final distance = _currentPosition != null && trip.route.isNotEmpty ? (GeoUtils.calculateDistance(_currentPosition!, trip.route.first) / 1000).toStringAsFixed(1) : "?";
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1C1C1C), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Nuevo Viaje - $distance km", style: const TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold)), const Text("\$25.0", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))]),
          const Divider(color: Colors.white10, height: 20),
          const Text("Origen: Av. Arce #243", style: TextStyle(color: Colors.white70)),
          const Text("Destino: Sopocachi, Plaza Avaroa", style: TextStyle(color: Colors.white70)),
          const Spacer(),
          SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00)), onPressed: () => TripAcceptProtocol.acceptTrip(trip: trip, driverId: widget.driverId, etaInMinutes: 5), child: const Text("ACEPTAR")))
        ],
      ),
    );
  }

  Widget _buildInProgressSection(Trip trip) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(color: Color(0xFF1C1C1C), borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(trip.status == TripStatus.accepted ? "YENDO POR PASAJERO" : "VIAJE EN CURSO", style: const TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: trip.status == TripStatus.accepted ? const Color(0xFFFF6B00) : Colors.green, minimumSize: const Size(double.infinity, 54)),
            onPressed: () {
              if (trip.status == TripStatus.accepted) {
                Antigravity.mutateTrip(currentTrip: trip, nextTrip: trip.copyWith(status: TripStatus.inProgress), onCommit: (t) => Antigravity.emit('trip.in_progress', {'t.id': t.id}), onRollback: (_) => _showErrorSnackBar("Error"));
              } else {
                Antigravity.mutateTrip(currentTrip: trip, nextTrip: trip.copyWith(status: TripStatus.completed), onCommit: (t) => Antigravity.emit('trip.completed', {'t.id': t.id}), onRollback: (_) => _showErrorSnackBar("Error"));
              }
            },
            child: Text(trip.status == TripStatus.accepted ? "RECOGER PASAJERO" : "FINALIZAR VIAJE"),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationBanner() {
    return SafeArea(child: Material(color: Colors.transparent, child: Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFFF6B00), borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)]), child: const Row(children: [Icon(Icons.bolt, color: Colors.white), SizedBox(width: 12), Text("¡NUEVO VIAJE DISPONIBLE!", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]))));
  }

  Widget _buildInfoPanel(String text) {
    return Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.symmetric(vertical: 20), color: Colors.transparent, child: Center(child: Text(text, style: const TextStyle(color: Colors.white38))));
  }
}
