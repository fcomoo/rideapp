import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:rideapp_client/core/antigravity/client.dart';

class SOSButton extends StatefulWidget {
  final String userId;
  final String? tripId;

  const SOSButton({super.key, required this.userId, this.tripId});

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _triggerSOS();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _triggerSOS() async {
    setState(() => _isHolding = false);
    _controller.reset();

    // Haptic feedback
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(duration: 1000);
    }

    // Get GPS
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Emit event
    final payload = {
      'userId': widget.userId,
      'tripId': widget.tripId,
      'lat': position.latitude,
      'lng': position.longitude,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'message': "ALERTA SOS - Usuario necesita ayuda",
    };

    // Emit to emergency channel
    AntigravityClient().send('sos.alert', 'emergency.${widget.userId}', payload);

    if (mounted) {
      _showSOSDialog();
    }
  }

  void _showSOSDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        title: const Text("🚨 Alerta SOS enviada", 
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: const Text(
          "Tu ubicación ha sido compartida con las autoridades y el equipo de RideApp.\n\n¿Deseas llamar al 911?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () {
              AntigravityClient().send('sos.cancelled', 'emergency.${widget.userId}', {
                'userId': widget.userId,
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              });
              Navigator.pop(context);
            },
            child: const Text("Cancelar alerta", style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () => launchUrl(Uri.parse("tel:911")),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Llamar 911"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) {
        setState(() => _isHolding = true);
        _controller.forward();
      },
      onLongPressEnd: (_) {
        setState(() => _isHolding = false);
        _controller.reset();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_isHolding)
            SizedBox(
              width: 80,
              height: 80,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return CircularProgressIndicator(
                    value: _controller.value,
                    strokeWidth: 6,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                  );
                },
              ),
            ),
          Container(
            width: 70,
            height: 70,
            decoration: const BoxDecoration(
              color: Color(0xFFFF0000),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black45, blurRadius: 10, spreadRadius: 2)
              ],
            ),
            child: const Center(
              child: Text(
                "SOS",
                style: TextStyle(
                  color: Colors.white, 
                  fontWeight: FontWeight.bold, 
                  fontSize: 18,
                  letterSpacing: 1.2
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
