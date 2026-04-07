import 'dart:async';
import 'package:flutter/material.dart';
import 'package:rideapp_client/core/antigravity/gravity_store.dart';
import 'package:rideapp_client/core/antigravity/profile.dart';
import 'package:rideapp_client/core/protocols/negotiation_protocol.dart';
import 'package:rideapp_client/domain/entities/negotiation_offer.dart';
import 'package:rideapp_client/core/antigravity/kill_switch.dart';

class NegotiationScreen extends StatefulWidget {
  final String tripId;
  final String clientId;
  final Map<String, double> origin;
  final Map<String, double> destination;

  const NegotiationScreen({
    super.key,
    required this.tripId,
    required this.clientId,
    required this.origin,
    required this.destination,
  });

  @override
  State<NegotiationScreen> createState() => _NegotiationScreenState();
}

class _NegotiationScreenState extends State<NegotiationScreen> {
  final TextEditingController _priceController = TextEditingController(text: '85');
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();
  final List<NegotiationOffer> _offers = [];
  
  late Timer _timer;
  int _secondsRemaining = AntigravityProfile.negotiationTimeout.inSeconds;
  bool _isNegotiating = false;

  @override
  void initState() {
    super.initState();
    _listenToOffers();
  }

  void _listenToOffers() {
    GravityStore().offersStream.listen((currentOffers) {
      final newOffers = currentOffers.values
          .where((o) => o.tripId == widget.tripId && !_offers.any((existing) => existing.id == o.id))
          .toList();

      for (var offer in newOffers) {
        _offers.insert(0, offer);
        _listKey.currentState?.insertItem(0, duration: const Duration(milliseconds: 500));
      }
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer.cancel();
        _handleTimeout();
      }
    });
  }

  void _handleTimeout() {
    KillSwitch.trigger();
    GravityStore().clearOffers();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tiempo agotado. Negociación cancelada.'), backgroundColor: Colors.red),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _submitInitialOffer() async {
    final price = double.tryParse(_priceController.text);
    if (price == null) return;

    setState(() {
      _isNegotiating = true;
    });

    await NegotiationProtocol.startNegotiation(
      tripId: widget.tripId,
      clientId: widget.clientId,
      origin: widget.origin,
      destination: widget.destination,
      offeredPrice: price,
    );

    _startTimer();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('NEGOCIACIÓN ACTIVA', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (!_isNegotiating) ...[
              _buildInitialForm(),
            ] else ...[
              _buildActiveNegotiation(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInitialForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.monetization_on, size: 80, color: Color(0xFFFF6B00)),
        const SizedBox(height: 32),
        const Text('¿CUÁNTO QUIERES OFRECER?', style: TextStyle(fontSize: 18, color: Colors.white70)),
        const SizedBox(height: 16),
        TextField(
          controller: _priceController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Color(0xFFFF6B00)),
          decoration: const InputDecoration(border: InputBorder.none, prefixText: '\$'),
        ),
        const SizedBox(height: 48),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton(
            onPressed: _submitInitialOffer,
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00), foregroundColor: Colors.white),
            child: const Text('BUSCAR CONDUCTORES', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildActiveNegotiation() {
    return Expanded(
      child: Column(
        children: [
          _buildTimerHeader(),
          const SizedBox(height: 24),
          const Text('CONTRAOFERTAS RECIBIDAS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white30, letterSpacing: 1)),
          const SizedBox(height: 16),
          Expanded(
            child: AnimatedList(
              key: _listKey,
              initialItemCount: _offers.length,
              itemBuilder: (context, index, animation) {
                return _buildOfferCard(_offers[index], animation);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('FINALIZA EN:', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
          Text(
            '${_secondsRemaining}s',
            style: const TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(NegotiationOffer offer, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: SizeTransition(
        sizeFactor: animation,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFF1C1C1C), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white10)),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: const Color(0xFFFF6B00).withOpacity(0.1), child: const Icon(Icons.person, color: Color(0xFFFF6B00))),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(offer.driverName ?? 'Conductor', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('⭐ ${offer.driverRating ?? 4.8}', style: const TextStyle(fontSize: 12, color: Colors.white54)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('\$${offer.counterPrice}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFF6B00))),
                  TextButton(
                    onPressed: () => _acceptOffer(offer),
                    child: const Text('ACEPTAR', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _acceptOffer(NegotiationOffer offer) {
    NegotiationProtocol.acceptOffer(
      tripId: widget.tripId,
      driverId: offer.driverId,
      clientId: widget.clientId,
      finalPrice: offer.counterPrice ?? offer.offeredPrice,
    );
    Navigator.pop(context); // Finaliza negociación
  }
}
