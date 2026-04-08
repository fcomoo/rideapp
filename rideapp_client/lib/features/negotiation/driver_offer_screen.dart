import 'package:flutter/material.dart';
import 'package:rideapp_client/core/protocols/negotiation_protocol.dart';
import 'package:rideapp_client/domain/entities/trip.dart';

class DriverOfferScreen extends StatefulWidget {
  final Trip trip;
  final String driverId;
  final double suggestedPrice;

  const DriverOfferScreen({
    super.key,
    required this.trip,
    required this.driverId,
    required this.suggestedPrice,
  });

  @override
  State<DriverOfferScreen> createState() => _DriverOfferScreenState();
}

class _DriverOfferScreenState extends State<DriverOfferScreen> {
  final TextEditingController _counterController = TextEditingController();
  double _priceBuffer = 0.0;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _priceBuffer = widget.suggestedPrice;
    _counterController.text = widget.suggestedPrice.toString();
  }

  Future<void> _acceptDirectly() async {
    setState(() => _isSending = true);
    await NegotiationProtocol.counterOffer(
      tripId: widget.trip.id,
      driverId: widget.driverId,
      counterPrice: widget.suggestedPrice,
      offeredPrice: widget.suggestedPrice,
    );
    if (mounted) Navigator.pop(context);
  }

  Future<void> _sendCounter() async {
    setState(() => _isSending = true);
    await NegotiationProtocol.counterOffer(
      tripId: widget.trip.id,
      driverId: widget.driverId,
      counterPrice: _priceBuffer,
      offeredPrice: widget.suggestedPrice,
    );
    if (mounted) Navigator.pop(context);
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('OFERTA DEL PASAJERO', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  Text('\$${widget.suggestedPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
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
        Slider(
          value: _priceBuffer,
          min: widget.suggestedPrice,
          max: widget.suggestedPrice + 100.0,
          activeColor: const Color(0xFFFF6B00),
          onChanged: (val) => setState(() => _priceBuffer = val),
        ),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(12)),
                child: Text('\$${_priceBuffer.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
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
