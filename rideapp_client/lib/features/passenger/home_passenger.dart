import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rideapp_client/core/antigravity/client.dart';
import 'package:rideapp_client/core/antigravity/gravity_store.dart';
import 'package:rideapp_client/core/protocols/trip_protocol.dart';
import 'package:rideapp_client/core/services/geocoding_service.dart';
import 'package:rideapp_client/core/services/routing_service.dart';
import 'package:rideapp_client/domain/value_objects/simple_latlng.dart';
import 'package:rideapp_client/domain/entities/trip.dart';
import 'package:rideapp_client/domain/entities/driver.dart';
import 'package:rideapp_client/domain/value_objects/coordinates.dart';
import 'package:rideapp_client/features/map/map_tracker_widget.dart';
import 'package:rideapp_client/features/negotiation/negotiation_screen.dart';
import 'package:rideapp_client/core/utils/geo_utils.dart';
import 'package:rideapp_client/core/utils/mock_traffic.dart';
import 'package:rideapp_client/features/chat/chat_screen.dart';
import 'package:rideapp_client/features/sos/sos_button.dart';
import 'package:rideapp_client/features/rating/rating_screen.dart';
import 'package:rideapp_client/features/profile/passenger_profile_screen.dart';
import 'package:rideapp_client/core/config/app_config.dart';

class HomePassenger extends StatefulWidget {
  final String currentUserId;

  const HomePassenger({super.key, required this.currentUserId});

  @override
  State<HomePassenger> createState() => _HomePassengerState();
}

class _HomePassengerState extends State<HomePassenger> {
  final TextEditingController _destinationController = TextEditingController();
  final MapController _mapController = MapController();
  final _searchDebounce = StreamController<String>();
  StreamSubscription? _tripSub;
  Timer? _mockTrafficTimer;
  Timer? _debounceTimer;
  List<SearchResult> _suggestions = [];
  bool _isSearching = false;
  
  SearchResult? _selectedDestination;
  List<Coordinates> _previewRoute = [];
  bool _isCalculatingRoute = false;
  
  // Local Mock Traffic
  final List<Driver> _localMockDrivers = [];
  int _tick = 0;

  // Persistencia de mapa
  LatLng _currentMapCenter = const LatLng(17.7600, -92.5950);

  @override
  void initState() {
    super.initState();
    _setupSearchDebounce();
    _initLocalMockDrivers();
    _startLocalMockTraffic();
    
    _tripSub = GravityStore().tripsStream.listen((trips) {
      final completedTrip = trips.values.where((t) => 
        t.clientId == widget.currentUserId && 
        t.status == TripStatus.completed
      ).firstOrNull;

      if (completedTrip != null) {
        _showRatingScreen(completedTrip);
      }
    });
    
    AntigravityClient().connect('drivers.locations');
  }

  void _showRatingScreen(Trip trip) {
    final driverId = trip.driverId;
    if (driverId == null) return;
    final driverName = GravityStore().currentDrivers[driverId]?.id ?? "Conductor";

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RatingScreen(
            tripId: trip.id,
            ratedUserId: driverId,
            ratedUserName: driverName,
            ratedBy: 'passenger',
          ),
        ),
      ).then((_) => GravityStore().removeTrip(trip.id));
    });
  }

  void _initLocalMockDrivers() {
    if (GravityStore().currentDrivers.isNotEmpty) return;
    _localMockDrivers.addAll([
      Driver(id: 'mock-driver-1', vehicleDetails: {'model': 'Toyota Corolla'}, currentLocation: const Coordinates(17.7650, -92.5900), rating: 4.8),
      Driver(id: 'mock-driver-2', vehicleDetails: {'model': 'Nissan Versa'}, currentLocation: const Coordinates(17.7580, -92.5850), rating: 4.9),
      Driver(id: 'mock-driver-3', vehicleDetails: {'model': 'VW Vento'}, currentLocation: const Coordinates(17.7620, -92.5980), rating: 4.7),
    ]);
  }

  void _startLocalMockTraffic() {
    _mockTrafficTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (GravityStore().currentDrivers.isNotEmpty) {
        if (_localMockDrivers.isNotEmpty) {
          setState(() => _localMockDrivers.clear());
        }
        return;
      }
      
      _tick++;
      setState(() {
        if (_tick % 2 == 0) {
          final d1 = _localMockDrivers[0];
          final latOffset = (sin(_tick * 0.5) * 0.001);
          _localMockDrivers[0] = d1.copyWith(currentLocation: Coordinates(17.7650 + latOffset, -92.5900), heading: latOffset > 0 ? 0.0 : 180.0);
          
          final d2 = _localMockDrivers[1];
          final lngOffset = (cos(_tick * 0.5) * 0.001);
          _localMockDrivers[1] = d2.copyWith(currentLocation: Coordinates(17.7580, -92.5850 + lngOffset), heading: lngOffset > 0 ? 90.0 : 270.0);
        }
        if (_tick % 3 == 0) {
          final d3 = _localMockDrivers[2];
          final offset = (sin(_tick * 0.3) * 0.001);
          _localMockDrivers[2] = d3.copyWith(currentLocation: Coordinates(17.7620 + offset, -92.5980 + offset), heading: 45.0);
        }
      });
    });
  }

  void _setupSearchDebounce() {
    _searchDebounce.stream.listen((query) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
        if (query.length > 2) {
          final results = await GeocodingService.search(query);
          if (mounted) setState(() { _suggestions = results; _isSearching = results.isNotEmpty; });
        }
      });
    });
  }

  Future<SimpleLatLng> _getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return SimpleLatLng(_currentMapCenter.latitude, _currentMapCenter.longitude);

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return SimpleLatLng(_currentMapCenter.latitude, _currentMapCenter.longitude);
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return SimpleLatLng(_currentMapCenter.latitude, _currentMapCenter.longitude);
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 3),
      );
      return SimpleLatLng(position.latitude, position.longitude);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usando ubicación del mapa (GPS lento)'), backgroundColor: Colors.orange)
        );
      }
      return SimpleLatLng(_currentMapCenter.latitude, _currentMapCenter.longitude);
    }
  }

  Future<void> _selectDestination(SearchResult result) async {
    setState(() {
      _selectedDestination = result;
      _destinationController.text = result.name;
      _isSearching = false;
      _isCalculatingRoute = true;
      _previewRoute = []; // Reset pre-calculo
    });
    
    _mapController.move(LatLng(result.coordinates.latitude, result.coordinates.longitude), 15);
    
    // Obtener la posición GPS real para el origen del cálculo
    SimpleLatLng origin = await _getCurrentPosition();
    
    // VALIDACIÓN: Si estamos fuera de México (ej. simulador en SF), forzar Macuspana
    if (!GeoUtils.isWithinMexico(origin.latitude, origin.longitude)) {
      origin = SimpleLatLng(AppConfig.macuspanaCenter.latitude, AppConfig.macuspanaCenter.longitude);
    }
    
    try {
      final route = await RoutingService.getRoute(origin, result.coordinates);
      if (mounted) {
        setState(() { 
          _previewRoute = route; 
          _isCalculatingRoute = false; 
        });
      }
    } catch (err) {
      if (mounted) {
        setState(() => _isCalculatingRoute = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo calcular la ruta desde tu posición'), backgroundColor: Colors.red)
        );
      }
    }
  }

  @override
  void dispose() {
    _tripSub?.cancel();
    _searchDebounce.close();
    _destinationController.dispose();
    _mockTrafficTimer?.cancel();
    _debounceTimer?.cancel();
    _mapController.dispose();
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
              if (activeTrip == null) Positioned(top: 60, left: 20, right: 20, child: _buildSearchContainer()),
              Align(alignment: Alignment.bottomCenter, child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: _buildBottomPanel(context, activeTrip))),
              if (activeTrip != null) Positioned(right: 20, bottom: 220, child: _buildChatButton(activeTrip)),
              Positioned(left: 20, bottom: activeTrip != null ? 300 : 120, child: SOSButton(userId: widget.currentUserId, tripId: activeTrip?.id)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMainContent(Trip? activeTrip) {
    if (activeTrip != null) return MapTrackerWidget(tripId: activeTrip.id, defaultCenter: AppConfig.macuspanaCenter);
    
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentMapCenter,
        initialZoom: 15.0,
        backgroundColor: Colors.grey[200]!,
        onPositionChanged: (position, hasGesture) {
          _currentMapCenter = position.center;
        },
      ),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.rideapp.client', maxZoom: 18),
        if (_previewRoute.isNotEmpty) PolylineLayer(polylines: [Polyline(points: _previewRoute.map((p) => LatLng(p.latitude, p.longitude)).toList(), color: const Color(0xFFFF6B00), strokeWidth: 4)]),
        if (_selectedDestination != null) MarkerLayer(markers: [Marker(point: LatLng(_selectedDestination!.coordinates.latitude, _selectedDestination!.coordinates.longitude), child: const Icon(Icons.location_on, color: Colors.blue, size: 40))]),
        if (_isCalculatingRoute) const Center(child: CircularProgressIndicator(color: Color(0xFFFF6B00))),
        
        StreamBuilder<Map<String, Driver>>(
          stream: GravityStore().driversStream,
          builder: (context, snapshot) {
            final drivers = snapshot.data ?? GravityStore().currentDrivers;
            final nearbyDrivers = drivers.values.where((d) => GeoUtils.calculateDistance(const Coordinates(17.7600, -92.5950), d.currentLocation) <= 5000).toList();
            return MarkerLayer(markers: nearbyDrivers.map((driver) => Marker(point: LatLng(driver.currentLocation.latitude, driver.currentLocation.longitude), width: 50, height: 50, child: AnimatedDriverMarker(driver: driver))).toList());
          },
        ),
        MarkerLayer(markers: _localMockDrivers.map((driver) => Marker(point: LatLng(driver.currentLocation.latitude, driver.currentLocation.longitude), width: 50, height: 50, child: AnimatedDriverMarker(driver: driver, isMock: true))).toList()),
      ],
    );
  }

  Widget _buildSearchContainer() {
    return Column(children: [
      Row(children: [
        Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: const Color(0xFF1C1C1C), borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)], border: Border.all(color: Colors.white10)), child: TextField(controller: _destinationController, style: const TextStyle(color: Colors.white), onChanged: (val) => _searchDebounce.add(val), decoration: const InputDecoration(hintText: '¿A dónde vas?', hintStyle: TextStyle(color: Colors.white24), border: InputBorder.none, icon: Icon(Icons.search, color: Color(0xFFFF6B00)))))),
        const SizedBox(width: 12),
        GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PassengerProfileScreen())), child: Container(width: 50, height: 50, decoration: BoxDecoration(color: const Color(0xFF1C1C1C), shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)], border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.3), width: 1.5)), child: const Icon(Icons.person_rounded, color: Color(0xFFFF6B00), size: 28))),
      ]),
      if (_isSearching) Container(margin: const EdgeInsets.only(top: 8), decoration: BoxDecoration(color: const Color(0xFF1C1C1C), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)), child: ListView.separated(shrinkWrap: true, padding: EdgeInsets.zero, itemCount: _suggestions.length, separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1), itemBuilder: (context, index) { final result = _suggestions[index]; return ListTile(title: Text(result.name, style: const TextStyle(color: Colors.white, fontSize: 14)), onTap: () => _selectDestination(result)); })),
    ]);
  }

  Widget _buildBottomPanel(BuildContext context, Trip? trip) {
    if (trip == null) return _buildIdleView(context);
    switch (trip.status) {
      case TripStatus.requested: return _buildSearchingView(context, trip);
      case TripStatus.accepted: return _buildAcceptedView(context, trip);
      case TripStatus.inProgress: return _buildInProgressView(context, trip);
      default: return _buildIdleView(context);
    }
  }

  Widget _buildIdleView(BuildContext context) {
    String label = 'SOLICITAR RIDE';
    bool isDisabled = _selectedDestination == null;
    bool showLoading = _isCalculatingRoute;

    if (_selectedDestination != null) {
      if (_isCalculatingRoute) {
        label = 'CALCULANDO RUTA...';
      } else {
        label = 'SOLICITAR RIDE A ${_selectedDestination!.name.toUpperCase()}';
      }
    }

    return Container(key: const ValueKey('idle'), padding: const EdgeInsets.all(24), decoration: _panelDecoration(), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const Icon(Icons.history, color: Colors.white24),
        const SizedBox(width: 12),
        const Text('Casa', style: TextStyle(color: Colors.white70)),
        const Spacer(),
        _buildRoundIcon(Icons.work_outline),
        const SizedBox(width: 8),
        _buildRoundIcon(Icons.add),
      ]),
      const SizedBox(height: 24),
      _buildActionButton(
        label: label, 
        onPressed: isDisabled ? null : () => _handleRequestTrip(context),
        isLoading: showLoading,
      ),
    ]));
  }

  Widget _buildSearchingView(BuildContext context, Trip trip) {
    return Container(padding: const EdgeInsets.all(24), decoration: _panelDecoration(), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const LinearProgressIndicator(color: Color(0xFFFF6B00), backgroundColor: Colors.white10),
      const SizedBox(height: 24),
      const Text('BUSCANDO CONDUCTOR...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      const SizedBox(height: 24),
      _buildActionButton(label: 'CANCELAR', color: Colors.white10, onPressed: () => _handleCancelTrip(trip)),
    ]));
  }

  Widget _buildAcceptedView(BuildContext context, Trip trip) {
    final driver = GravityStore().currentDrivers[trip.driverId];
    return Container(padding: const EdgeInsets.all(24), decoration: _panelDecoration(), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const CircleAvatar(backgroundColor: Color(0xFFFF6B00), child: Icon(Icons.person, color: Colors.white)),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(driver?.vehicleDetails['driver_name'] ?? 'Tu Conductor', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text(driver?.vehicleDetails['model'] ?? 'Confirmando vehículo...', style: const TextStyle(color: Colors.white30, fontSize: 12))])),
        const Icon(Icons.star, color: Colors.amber, size: 16),
        const SizedBox(width: 4),
        Text(driver?.rating.toString() ?? '4.9', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 24),
      _buildActionButton(label: 'CANCELAR VIAJE', color: Colors.red.withOpacity(0.1), onPressed: () => _handleCancelTrip(trip)),
    ]));
  }

  Widget _buildInProgressView(BuildContext context, Trip trip) {
    return Container(padding: const EdgeInsets.all(24), decoration: _panelDecoration(), child: Row(children: [
      const Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('EN TRAYECTO', style: TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold)), Text('Llegada estimada: 12:45', style: TextStyle(color: Colors.white30, fontSize: 12))])),
      _buildSOSButton(trip),
    ]));
  }

  BoxDecoration _panelDecoration() => const BoxDecoration(color: Color(0xFF1C1C1C), borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)), boxShadow: [BoxShadow(color: Colors.black87, blurRadius: 20)]);
  Widget _buildRoundIcon(IconData icon) => Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle), child: Icon(icon, color: Colors.white54, size: 20));
  Widget _buildSOSButton(Trip trip) => ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))), onPressed: () => _handleSOS(trip), child: const Text('SOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)));
  
  Widget _buildActionButton({required String label, required VoidCallback? onPressed, Color? color, bool isLoading = false}) => SizedBox(
    width: double.infinity, 
    height: 56, 
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? const Color(0xFFFF6B00), 
        disabledBackgroundColor: Colors.white.withOpacity(0.05), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
        elevation: 0
      ), 
      onPressed: isLoading ? null : onPressed, 
      child: isLoading 
        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : Text(label, style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.white))
    )
  );

  void _handleRequestTrip(BuildContext context) {
    if (_selectedDestination == null) return;
    
    if (_previewRoute.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esperando a que la ruta se calcule...'), backgroundColor: Colors.orange)
      );
      return;
    }

    // Asegurar que el origen del Trip sea válido en México (evitar SF)
    List<Coordinates> finalRoute = List.from(_previewRoute);
    if (!GeoUtils.isWithinMexico(finalRoute.first.latitude, finalRoute.first.longitude)) {
      finalRoute[0] = Coordinates(AppConfig.macuspanaCenter.latitude, AppConfig.macuspanaCenter.longitude);
    }

    final newTrip = Trip(
      id: 'trip-${DateTime.now().millisecondsSinceEpoch}', 
      clientId: widget.currentUserId, 
      status: TripStatus.requested, 
      route: finalRoute,
    );

    TripRequestProtocol.requestTrip(
      trip: newTrip, 
      origin: finalRoute.first, 
      destination: finalRoute.last, 
      offeredPrice: 25.0, 
      onError: (msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red)
      )
    );

    // Tras el requestTrip, navegamos a la pantalla de Negociación Activa
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => NegotiationScreen(
            tripId: newTrip.id,
            clientId: widget.currentUserId,
            origin: {'lat': finalRoute.first.latitude, 'lng': finalRoute.first.longitude},
            destination: {'lat': finalRoute.last.latitude, 'lng': finalRoute.last.longitude},
          ),
        ),
      );
    }
  }

  void _handleCancelTrip(Trip trip) => Antigravity.mutateTrip(currentTrip: trip, nextTrip: trip.copyWith(status: TripStatus.cancelled), onCommit: (t) => Antigravity.emit('trip.cancelled', {'tripId': t.id}), onRollback: (_) => print('Rollback'));
  void _handleSOS(Trip trip) => Antigravity.emit('security.sos', { 'tripId': trip.id, 'userId': widget.currentUserId });

  Widget _buildChatButton(Trip activeTrip) {
    final driver = GravityStore().currentDrivers[activeTrip.driverId];
    final driverName = driver?.vehicleDetails['driver_name'] ?? 'Conductor';
    return StreamBuilder<Map<String, int>>(stream: GravityStore().unreadStream, builder: (context, snapshot) {
      final unreadCount = (snapshot.data ?? GravityStore().unreadCounts)[activeTrip.id] ?? 0;
      return Stack(clipBehavior: Clip.none, children: [
        FloatingActionButton(backgroundColor: const Color(0xFF1C1C1C), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(trip: activeTrip, currentUserId: widget.currentUserId, otherUserName: driverName, senderRole: 'passenger'))), child: const Icon(Icons.chat_bubble_outline, color: Color(0xFFFF6B00))),
        if (unreadCount > 0) Positioned(right: -4, top: -4, child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), constraints: const BoxConstraints(minWidth: 20, minHeight: 20), child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), textAlign: TextAlign.center))),
      ]);
    });
  }
}

class AnimatedDriverMarker extends StatefulWidget {
  final Driver driver;
  final bool isMock;
  const AnimatedDriverMarker({super.key, required this.driver, this.isMock = false});
  @override State<AnimatedDriverMarker> createState() => _AnimatedDriverMarkerState();
}

class _AnimatedDriverMarkerState extends State<AnimatedDriverMarker> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Tween<double> _latTween;
  late Tween<double> _lngTween;
  late Tween<double> _angleTween;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _latTween = Tween(begin: widget.driver.currentLocation.latitude, end: widget.driver.currentLocation.latitude);
    _lngTween = Tween(begin: widget.driver.currentLocation.longitude, end: widget.driver.currentLocation.longitude);
    _angleTween = Tween(begin: widget.driver.heading, end: widget.driver.heading);
  }

  @override
  void didUpdateWidget(AnimatedDriverMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.driver.currentLocation != widget.driver.currentLocation || oldWidget.driver.heading != widget.driver.heading) {
      _latTween = Tween(begin: _latTween.evaluate(_controller), end: widget.driver.currentLocation.latitude);
      _lngTween = Tween(begin: _lngTween.evaluate(_controller), end: widget.driver.currentLocation.longitude);
      double endAngle = widget.driver.heading;
      double startAngle = _angleTween.evaluate(_controller);
      if ((endAngle - startAngle).abs() > 180) { if (endAngle > startAngle) startAngle += 360; else endAngle += 360; }
      _angleTween = Tween(begin: startAngle, end: endAngle);
      _controller.forward(from: 0);
    }
  }

  @override void dispose() { _controller.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _controller, builder: (context, child) {
      return Transform.rotate(angle: _angleTween.evaluate(_controller) * (3.14159 / 180), child: Column(children: [
        Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(4)), child: Text(widget.driver.id.substring(0, 4).toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
        Icon(widget.isMock ? Icons.directions_car : Icons.drive_eta, color: const Color(0xFFFF6B00), size: widget.isMock ? 35 : 30),
      ]));
    });
  }
}
