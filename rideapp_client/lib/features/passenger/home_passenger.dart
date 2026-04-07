import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:rideapp_client/core/antigravity/client.dart';
import 'package:rideapp_client/core/antigravity/gravity_store.dart';
import 'package:rideapp_client/core/antigravity/profile.dart';
import 'package:rideapp_client/core/protocols/trip_protocol.dart';
import 'package:rideapp_client/core/services/geocoding_service.dart';
import 'package:rideapp_client/core/services/routing_service.dart';
import 'package:rideapp_client/domain/value_objects/simple_latlng.dart';
import 'package:rideapp_client/domain/entities/trip.dart';
import 'package:rideapp_client/domain/entities/driver.dart';
import 'package:rideapp_client/domain/value_objects/coordinates.dart';
import 'package:rideapp_client/features/map/map_tracker_widget.dart';
import 'package:rideapp_client/core/utils/geo_utils.dart';
import 'package:rideapp_client/core/utils/mock_traffic.dart';

class HomePassenger extends StatefulWidget {
  final String currentUserId;

  const HomePassenger({super.key, required this.currentUserId});

  @override
  State<HomePassenger> createState() => _HomePassengerState();
}

class _HomePassengerState extends State<HomePassenger> {
  final TextEditingController _destinationController = TextEditingController();
  final StreamController<String> _searchDebounce = StreamController<String>();
  List<SearchResult> _suggestions = [];
  bool _isSearching = false;
  
  SearchResult? _selectedDestination;
  List<Coordinates> _previewRoute = [];
  bool _isCalculatingRoute = false;
  
  // Local Mock Traffic
  final List<Driver> _localMockDrivers = [];
  Timer? _mockTrafficTimer;
  int _tick = 0;

  @override
  void initState() {
    super.initState();
    _setupSearchDebounce();
    _initLocalMockDrivers();
    _startLocalMockTraffic();
    
    // Conectar al canal global de ubicaciones
    AntigravityClient().connect('drivers.locations');
  }

  void _initLocalMockDrivers() {
    _localMockDrivers.addAll([
      Driver(
        id: 'mock-driver-1',
        vehicleDetails: {'model': 'Toyota Corolla'},
        currentLocation: const Coordinates(17.7650, -92.5900),
        rating: 4.8,
      ),
      Driver(
        id: 'mock-driver-2',
        vehicleDetails: {'model': 'Nissan Versa'},
        currentLocation: const Coordinates(17.7580, -92.5850),
        rating: 4.9,
      ),
      Driver(
        id: 'mock-driver-3',
        vehicleDetails: {'model': 'VW Vento'},
        currentLocation: const Coordinates(17.7620, -92.5980),
        rating: 4.7,
      ),
    ]);
  }

  void _startLocalMockTraffic() {
    _mockTrafficTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      _tick++;
      
      setState(() {
        // Driver 1: Norte-Sur cada 2 seg
        if (_tick % 2 == 0) {
          final d1 = _localMockDrivers[0];
          final latOffset = (sin(_tick * 0.5) * 0.001);
          _localMockDrivers[0] = d1.copyWith(
            currentLocation: Coordinates(17.7650 + latOffset, -92.5900),
            heading: latOffset > 0 ? 0.0 : 180.0,
          );
        }

        // Driver 2: Este-Oeste cada 2 seg
        if (_tick % 2 == 0) {
          final d2 = _localMockDrivers[1];
          final lngOffset = (cos(_tick * 0.5) * 0.001);
          _localMockDrivers[1] = d2.copyWith(
            currentLocation: Coordinates(17.7580, -92.5850 + lngOffset),
            heading: lngOffset > 0 ? 90.0 : 270.0,
          );
        }

        // Driver 3: Diagonal cada 3 seg
        if (_tick % 3 == 0) {
          final d3 = _localMockDrivers[2];
          final offset = (sin(_tick * 0.3) * 0.001);
          _localMockDrivers[2] = d3.copyWith(
            currentLocation: Coordinates(17.7620 + offset, -92.5980 + offset),
            heading: 45.0,
          );
        }
      });
    });
  }

  void _setupSearchDebounce() {
    _searchDebounce.stream
        .distinct()
        .where((query) => query.length > 2)
        .listen((query) async {
      final results = await GeocodingService.search(query);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _isSearching = results.isNotEmpty;
        });
      }
    });
  }

  Future<void> _selectDestination(SearchResult result) async {
    setState(() {
      _selectedDestination = result;
      _destinationController.text = result.name;
      _isSearching = false;
      _isCalculatingRoute = true;
    });

    // Mock Origin (en una app real vendría del GPS)
    const origin = SimpleLatLng(17.7628, -92.5317); 
    
    final route = await RoutingService.getRoute(origin, result.coordinates);
    
    if (mounted) {
      setState(() {
        _previewRoute = route;
        _isCalculatingRoute = false;
      });
    }
  }

  @override
  void dispose() {
    _searchDebounce.close();
    _destinationController.dispose();
    _mockTrafficTimer?.cancel();
    MockTraffic.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: StreamBuilder<Map<String, Trip>>(
        stream: GravityStore().tripsStream,
        builder: (context, snapshot) {
          final trips = snapshot.data ?? GravityStore().currentTrips;
          
          final activeTrip = trips.values.where((t) => 
            t.clientId == widget.currentUserId && 
            t.status != TripStatus.completed &&
            t.status != TripStatus.cancelled
          ).firstOrNull;

          return Stack(
            children: [
              _buildMainContent(activeTrip),

              if (activeTrip == null) 
                Positioned(
                  top: 60,
                  left: 20,
                  right: 20,
                  child: _buildSearchContainer(),
                ),

              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _buildBottomPanel(context, activeTrip),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMainContent(Trip? activeTrip) {
    if (activeTrip != null) {
      return MapTrackerWidget(tripId: activeTrip.id);
    }
    
    return FlutterMap(
      options: MapOptions(
        initialCenter: const LatLng(17.7600, -92.5950),
        initialZoom: 15.0,
        backgroundColor: Colors.grey[200]!,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.rideapp.client',
          maxZoom: 18,
        ),
        if (_previewRoute.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _previewRoute.map((p) => LatLng(p.latitude, p.longitude)).toList(),
                color: const Color(0xFFFF6B00),
                strokeWidth: 4,
              ),
            ],
          ),
        if (_selectedDestination != null)
          MarkerLayer(
            markers: [
              Marker(
                point: LatLng(_selectedDestination!.coordinates.latitude, _selectedDestination!.coordinates.longitude),
                child: const Icon(Icons.location_on, color: Colors.red, size: 40),
              ),
            ],
          ),
        if (_isCalculatingRoute)
          const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00))),

        // Real-time Drivers Layers
        StreamBuilder<Map<String, Driver>>(
          stream: GravityStore().driversStream,
          builder: (context, snapshot) {
            final drivers = snapshot.data ?? GravityStore().currentDrivers;
            final nearbyDrivers = drivers.values.where((d) {
              final distance = GeoUtils.calculateDistance(
                const Coordinates(17.7600, -92.5950), // Centro Macuspana
                d.currentLocation,
              );
              return distance <= 5000; // 5km radius
            }).toList();

            return MarkerLayer(
              markers: nearbyDrivers.map((driver) {
                return Marker(
                  point: LatLng(driver.currentLocation.latitude, driver.currentLocation.longitude),
                  width: 50,
                  height: 50,
                  child: AnimatedDriverMarker(driver: driver),
                );
              }).toList(),
            );
          },
        ),

        // Local Mock Drivers Layer
        MarkerLayer(
          markers: _localMockDrivers.map((driver) {
            return Marker(
              point: LatLng(driver.currentLocation.latitude, driver.currentLocation.longitude),
              width: 50,
              height: 50,
              child: AnimatedDriverMarker(driver: driver, isMock: true),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchContainer() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1C),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
            border: Border.all(color: Colors.white10),
          ),
          child: TextField(
            controller: _destinationController,
            style: const TextStyle(color: Colors.white),
            onChanged: (val) => _searchDebounce.add(val),
            decoration: const InputDecoration(
              hintText: '¿A dónde vas?',
              hintStyle: TextStyle(color: Colors.white24),
              border: InputBorder.none,
              icon: Icon(Icons.search, color: Color(0xFFFF6B00)),
            ),
          ),
        ),
        if (_isSearching)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1C),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
              itemBuilder: (context, index) {
                final result = _suggestions[index];
                return ListTile(
                  title: Text(result.name, style: const TextStyle(color: Colors.white, fontSize: 14)),
                  onTap: () => _selectDestination(result),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildBottomPanel(BuildContext context, Trip? trip) {
    if (trip == null) return _buildIdleView(context);

    switch (trip.status) {
      case TripStatus.requested:
        return _buildSearchingView(context, trip);
      case TripStatus.accepted:
        return _buildAcceptedView(context, trip);
      case TripStatus.inProgress:
        return _buildInProgressView(context, trip);
      default:
        return _buildIdleView(context);
    }
  }

  Widget _buildIdleView(BuildContext context) {
    return Container(
      key: const ValueKey('idle'),
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: Colors.white24),
              const SizedBox(width: 12),
              const Text('Casa', style: TextStyle(color: Colors.white70)),
              const Spacer(),
              _buildRoundIcon(Icons.work_outline),
              const SizedBox(width: 8),
              _buildRoundIcon(Icons.add),
            ],
          ),
          const SizedBox(height: 24),
          _buildActionButton(
            label: _selectedDestination != null ? 'SOLICITAR RIDE A ${_selectedDestination!.name.toUpperCase()}' : 'SOLICITAR RIDE',
            onPressed: _selectedDestination != null ? () => _handleRequestTrip(context) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchingView(BuildContext context, Trip trip) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LinearProgressIndicator(color: Color(0xFFFF6B00), backgroundColor: Colors.white10),
          const SizedBox(height: 24),
          const Text('BUSCANDO CONDUCTOR...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          const Text('Esto tomará menos de 1 minuto', style: TextStyle(color: Colors.white30, fontSize: 12)),
          const SizedBox(height: 24),
          _buildActionButton(label: 'CANCELAR', color: Colors.white10, onPressed: () => _handleCancelTrip(trip)),
        ],
      ),
    );
  }

  Widget _buildAcceptedView(BuildContext context, Trip trip) {
    final driver = GravityStore().currentDrivers[trip.driverId];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const CircleAvatar(backgroundColor: Color(0xFFFF6B00), child: Icon(Icons.person, color: Colors.white)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driver?.vehicleDetails['driver_name'] ?? 'Tu Conductor', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(driver?.vehicleDetails['model'] ?? 'Confirmando vehículo...', style: const TextStyle(color: Colors.white30, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.star, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(driver?.rating.toString() ?? '4.9', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          _buildActionButton(label: 'CANCELAR VIAJE', color: Colors.red.withOpacity(0.1), onPressed: () => _handleCancelTrip(trip)),
        ],
      ),
    );
  }

  Widget _buildInProgressView(BuildContext context, Trip trip) {
     return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('EN TRAYECTO', style: TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold)),
                Text('Llegada estimada: 12:45', style: TextStyle(color: Colors.white30, fontSize: 12)),
              ],
            ),
          ),
          _buildSOSButton(trip),
        ],
      ),
    );
  }

  BoxDecoration _panelDecoration() {
    return const BoxDecoration(
      color: Color(0xFF1C1C1C),
      borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
      boxShadow: [BoxShadow(color: Colors.black87, blurRadius: 20)],
    );
  }

  Widget _buildRoundIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle),
      child: Icon(icon, color: Colors.white54, size: 20),
    );
  }

  Widget _buildSOSButton(Trip trip) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      onPressed: () => _handleSOS(trip),
      child: const Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionButton({required String label, required VoidCallback? onPressed, Color? color}) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? const Color(0xFFFF6B00),
          disabledBackgroundColor: Colors.white.withOpacity(0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white)),
      ),
    );
  }

  void _handleRequestTrip(BuildContext context) {
    if (_selectedDestination == null || _previewRoute.isEmpty) return;
    final newTrip = Trip(
      id: 'trip-${DateTime.now().millisecondsSinceEpoch}',
      clientId: widget.currentUserId,
      status: TripStatus.requested,
      route: _previewRoute,
    );
    TripRequestProtocol.requestTrip(
      trip: newTrip,
      origin: _previewRoute.first,
      destination: _previewRoute.last,
      offeredPrice: 25.0,
      onError: (msg) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
      },
    );
  }

  void _handleCancelTrip(Trip trip) {
    Antigravity.mutateTrip(
      currentTrip: trip,
      nextTrip: trip.copyWith(status: TripStatus.cancelled),
      onCommit: (t) => Antigravity.emit('trip.cancelled', {'tripId': t.id}),
      onRollback: (_) => print('Rollback'),
    );
  }

  void _handleSOS(Trip trip) {
    Antigravity.emit('security.sos', {
      'tripId': trip.id,
      'userId': widget.currentUserId,
    });
  }
}

class AnimatedDriverMarker extends StatefulWidget {
  final Driver driver;
  final bool isMock;
  const AnimatedDriverMarker({super.key, required this.driver, this.isMock = false});

  @override
  State<AnimatedDriverMarker> createState() => _AnimatedDriverMarkerState();
}

class _AnimatedDriverMarkerState extends State<AnimatedDriverMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Tween<double> _latTween;
  late Tween<double> _lngTween;
  late Tween<double> _angleTween;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _latTween = Tween(begin: widget.driver.currentLocation.latitude, end: widget.driver.currentLocation.latitude);
    _lngTween = Tween(begin: widget.driver.currentLocation.longitude, end: widget.driver.currentLocation.longitude);
    _angleTween = Tween(begin: widget.driver.heading, end: widget.driver.heading);
  }

  @override
  void didUpdateWidget(AnimatedDriverMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.driver.currentLocation != widget.driver.currentLocation ||
        oldWidget.driver.heading != widget.driver.heading) {
      
      _latTween = Tween(begin: _latTween.evaluate(_controller), end: widget.driver.currentLocation.latitude);
      _lngTween = Tween(begin: _lngTween.evaluate(_controller), end: widget.driver.currentLocation.longitude);
      
      // Manejar el salto de 360 a 0 grados para rotación suave
      double endAngle = widget.driver.heading;
      double startAngle = _angleTween.evaluate(_controller);
      if ((endAngle - startAngle).abs() > 180) {
        if (endAngle > startAngle) startAngle += 360; else endAngle += 360;
      }
      _angleTween = Tween(begin: startAngle, end: endAngle);

      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: _angleTween.evaluate(_controller) * (3.14159 / 180),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  widget.driver.id.substring(0, 4).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ),
              Icon(
                widget.isMock ? Icons.directions_car : Icons.drive_eta,
                color: const Color(0xFFFF6B00),
                size: widget.isMock ? 35 : 30,
              ),
            ],
          ),
        );
      },
    );
  }
}
