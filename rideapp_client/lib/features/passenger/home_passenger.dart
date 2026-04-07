import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rideapp_client/core/antigravity/client.dart';
import 'package:rideapp_client/core/antigravity/gravity_store.dart';
import 'package:rideapp_client/core/antigravity/profile.dart';
import 'package:rideapp_client/core/protocols/trip_protocol.dart';
import 'package:rideapp_client/domain/entities/trip.dart';
import 'package:rideapp_client/domain/entities/driver.dart';
import 'package:rideapp_client/domain/value_objects/coordinates.dart';
import 'package:rideapp_client/features/map/map_tracker_widget.dart';

class HomePassenger extends StatelessWidget {
  final String currentUserId;

  const HomePassenger({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: StreamBuilder<Map<String, Trip>>(
        stream: GravityStore().tripsStream,
        builder: (context, snapshot) {
          final trips = snapshot.data ?? GravityStore().currentTrips;
          
          // Buscar viaje activo para este pasajero
          final activeTrip = trips.values.where((t) => 
            t.clientId == currentUserId && 
            t.status != TripStatus.completed &&
            t.status != TripStatus.cancelled
          ).firstOrNull;

          return Stack(
            children: [
              // Fondo: Mapa o Placeholder
              _buildMainContent(activeTrip),

              // Panel Inferior con Transiciones
              Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
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
    if (activeTrip != null && activeTrip.status == TripStatus.inProgress) {
      return MapTrackerWidget(tripId: activeTrip.id);
    }
    
    // Vista por defecto (Mapa idle o imagen)
    return Container(
      color: const Color(0xFF1C1C1C),
      child: const Center(
        child: Icon(Icons.map_outlined, color: Colors.white24, size: 80),
      ),
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

  // 1. Estado IDLE: Solicitar Viaje
  Widget _buildIdleView(BuildContext context) {
    return Container(
      key: const ValueKey('idle'),
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSearchInput('¿A dónde vamos?'),
          const SizedBox(height: 16),
          _buildActionButton(
            label: 'SOLICITAR RIDE',
            onPressed: () => _handleRequestTrip(context),
          ),
        ],
      ),
    );
  }

  // 2. Estado SEARCHING: KilSwitch Countdown
  Widget _buildSearchingView(BuildContext context, Trip trip) {
    return Container(
      key: const ValueKey('searching'),
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFFFF6B00)),
          const SizedBox(height: 16),
          const Text(
            'Buscando conductor cercano...',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TweenAnimationBuilder<Duration>(
            duration: AntigravityProfile.searchTimeout,
            tween: Tween(begin: AntigravityProfile.searchTimeout, end: Duration.zero),
            builder: (context, value, child) {
              final seconds = value.inSeconds;
              return Text(
                'Tiempo restante: ${seconds}s',
                style: const TextStyle(color: Colors.white70),
              );
            },
          ),
        ],
      ),
    );
  }

  // 3. Estado ACCEPTED: Info del Conductor
  Widget _buildAcceptedView(BuildContext context, Trip trip) {
    // En una app real, buscaríamos el objeto Driver en el GravityStore usando trip.driverId
    final driver = GravityStore().currentDrivers[trip.driverId];

    return Container(
      key: const ValueKey('accepted'),
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const CircleAvatar(backgroundColor: Color(0xFFFF6B00), child: Icon(Icons.person)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver?.vehicleDetails['driver_name'] ?? 'Conductor asignado',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      driver?.vehicleDetails['license_plate'] ?? 'Placa pendiente',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  Text(driver?.rating.toString() ?? '5.0', style: const TextStyle(color: Colors.white)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildActionButton(
            label: 'CANCELAR VIAJE',
            color: Colors.redAccent,
            onPressed: () => _handleCancelTrip(trip),
          ),
        ],
      ),
    );
  }

  // 4. Estado IN_PROGRESS: Mapa Full + SOS
  Widget _buildInProgressView(BuildContext context, Trip trip) {
    return Container(
      key: const ValueKey('in_progress'),
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('VIAJE EN CURSO', style: TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold)),
                Text('Llegada en 5-8 min', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => _handleSOS(trip),
            child: const Text('SOS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Helpers de UI
  BoxDecoration _panelDecoration() {
    return const BoxDecoration(
      color: Color(0xFF1C1C1C),
      borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, -2))],
    );
  }

  Widget _buildSearchInput(String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(12)),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Colors.white24), border: InputBorder.none),
      ),
    );
  }

  Widget _buildActionButton({required String label, required VoidCallback onPressed, Color? color}) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color ?? const Color(0xFFFF6B00),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
      ),
    );
  }

  // Manejo de Lógica de Protocolos
  void _handleRequestTrip(BuildContext context) {
    // Demo data for request
    final newTrip = Trip(
      id: 'trip-${DateTime.now().millisecondsSinceEpoch}',
      clientId: currentUserId,
      status: TripStatus.requested,
      route: [const Coordinates(-16.5, -68.1)], // Dummy origin
    );

    TripRequestProtocol.requestTrip(
      trip: newTrip,
      origin: const Coordinates(-16.5, -68.1),
      destination: const Coordinates(-16.51, -68.12),
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
      onRollback: (_) => print('Cancelación fallida localmente'),
    );
  }

  void _handleSOS(Trip trip) {
    // Mutación irreversible sin rollback
    Antigravity.emit('security.sos', {
      'tripId': trip.id,
      'userId': currentUserId,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    print('EMERGENCIA SOS ACTIVADA para viaje ${trip.id}');
  }
}
