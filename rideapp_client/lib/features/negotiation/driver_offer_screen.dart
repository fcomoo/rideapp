import 'package:flutter/material.dart';
import 'package:rideapp_client/core/protocols/negotiation_protocol.dart';
import 'package:rideapp_client/domain/entities/negotiation_offer.dart';

class DriverOfferScreen extends StatefulWidget {
  final String tripId;
  final String driverId;
  final double passengerOfferedPrice;
  final Map<String, double> origin;
  final Map<String, double> destination;

  const DriverOfferScreen({
    super.key,
    required this.tripId,
    required this.driverId,
    required this.passengerOfferedPrice,
    required this.origin,
    required this.destination,
  });

  @override
  State<DriverOfferScreen> createState() => _DriverOfferScreenState();
}

class _DriverOfferScreenState extends State<DriverOfferScreen> {
  final TextEditingController _counterController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _counterController.text = (widget.passengerOfferedPrice + 15).toString(); // Sugerencia de +15
  }

  Future<void> _acceptDirectly() async {
    setState(() => _isSending = true);
    await NegotiationProtocol.counterOffer(
      tripId: widget.tripId,
      driverId: widget.driverId,
      counterPrice: widget.passengerOfferedPrice,
      offeredPrice: widget.passengerOfferedPrice,
    );
    Navigator.pop(context);
  }

  Future<void> _sendCounter() async {
    final price = double.tryParse(_counterController.text);
    if (price == null) return;
    
    setState(() => _isSending = true);
    await NegotiationProtocol.counterOffer(
      tripId: widget.tripId,
      driverId: widget.driverId,
      counterPrice: price,
      offeredPrice: widget.passengerOfferedPrice,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          const Text('NUEVA SOLICITUD DE VIAJE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white30, letterSpacing: 2)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('OFERTA DEL PASAJERO', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  Text('\$85.00', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFFF6B00).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Text('2.4 KM', style: TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildActionButtons(),
          const SizedBox(height: 16),
          _buildCounterSection(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: _isSending ? null : _acceptDirectly,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ACEPTAR PRECIO', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildCounterSection() {
    return Column(
      children: [
        const Divider(color: Colors.white10, height: 32),
        const Text('O PROPÓN UN MEJOR PRECIO:', style: TextStyle(color: Colors.white30, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _counterController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  prefixText: '\$',
                  filled: true,
                  fillColor: Colors.black26,
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSending ? null : _sendCounter,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B00), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Icon(Icons.send),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
