import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:http/http.dart' as http;
import 'package:rideapp_client/core/antigravity/profile.dart';

class RatingScreen extends StatefulWidget {
  final String tripId;
  final String ratedUserId;
  final String ratedUserName;
  final String? ratedUserInitials;
  final String? origin;
  final String? destination;
  final double? price;
  final String ratedBy; // 'passenger' | 'driver'

  const RatingScreen({
    super.key,
    required this.tripId,
    required this.ratedUserId,
    required this.ratedUserName,
    this.ratedUserInitials,
    this.origin,
    this.destination,
    this.price,
    required this.ratedBy,
  });

  @override
  State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> with SingleTickerProviderStateMixin {
  int _rating = 0;
  final TextEditingController _commentController = TextEditingController();
  late ConfettiController _confettiController;
  bool _isSubmitting = false;
  final List<String> _selectedFeedback = [];

  final List<String> _passengerFeedback = [
    "Conductor puntual ⏱️",
    "Buen manejo 🚗",
    "Muy amable 😊",
    "Auto limpio ✨",
  ];

  final List<String> _driverFeedback = [
    "Pasajero puntual ⏱️",
    "Muy respetuoso 🤝",
    "Buena charla 💬",
    "Excelente comunicación 📱",
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) return;

    setState(() => _isSubmitting = true);

    final comment = [
      ..._selectedFeedback,
      if (_commentController.text.isNotEmpty) _commentController.text,
    ].join(". ");

    try {
      final response = await http.post(
        Uri.parse("${AntigravityProfile.baseUrl}/api/trips/${widget.tripId}/rate"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "rating": _rating,
          "comment": comment,
          "ratedBy": widget.ratedBy,
          "ratedUserId": widget.ratedUserId,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 409) {
        _confettiController.play();
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Colors.green,
              content: Text("¡Gracias por tu calificación!", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        throw Exception("Failed to rate");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al enviar calificación")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedbackOptions = widget.ratedBy == 'passenger' ? _passengerFeedback : _driverFeedback;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        alignment: Alignment.center,
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFFFF6B00), size: 60),
                  const SizedBox(height: 16),
                  const Text(
                    "¡Llegamos!",
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tu viaje ha finalizado con éxito.\n¿Cómo calificarías a ${widget.ratedUserName}?",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  
                  // Resumen del viaje
                  if (widget.origin != null && widget.destination != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined, color: Colors.blue, size: 20),
                              const SizedBox(width: 12),
                              Expanded(child: Text(widget.origin!, style: const TextStyle(color: Colors.white70, fontSize: 13), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.only(left: 9.5),
                            child: SizedBox(height: 12, child: VerticalDivider(color: Colors.white10, thickness: 1)),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.location_on, color: Color(0xFFFF6B00), size: 20),
                              const SizedBox(width: 12),
                              Expanded(child: Text(widget.destination!, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                          if (widget.price != null) ...[
                             const Divider(color: Colors.white10, height: 24),
                             Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                 Text("Precio Total", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                                 Text("\$${widget.price!.toStringAsFixed(2)}", style: const TextStyle(color: Color(0xFFFF6B00), fontSize: 18, fontWeight: FontWeight.bold)),
                               ],
                             ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                  
                  // Avatar con inicial
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF6B00).withOpacity(0.1),
                      border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.3), width: 2),
                    ),
                    child: Center(
                      child: Text(
                        widget.ratedUserInitials ?? widget.ratedUserName[0].toUpperCase(),
                        style: const TextStyle(color: Color(0xFFFF6B00), fontSize: 48, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Sistema de Estrellas interactivo
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starIndex = index + 1;
                      final isFilled = _rating >= starIndex;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = starIndex),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 1.0, end: isFilled ? 1.2 : 1.0),
                            duration: const Duration(milliseconds: 200),
                            builder: (context, scale, child) {
                              return Transform.scale(
                                scale: scale,
                                child: Icon(
                                  isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                                  size: 56,
                                  color: isFilled ? const Color(0xFFFF6B00) : Colors.white24,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Feedback Rápido (Chips)
                  Wrap(
                    spacing: 8,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: feedbackOptions.map((f) {
                      final isSelected = _selectedFeedback.contains(f);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            isSelected ? _selectedFeedback.remove(f) : _selectedFeedback.add(f);
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFFF6B00) : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: isSelected ? const Color(0xFFFF6B00) : Colors.white12),
                          ),
                          child: Text(
                            f,
                            style: TextStyle(color: isSelected ? Colors.black : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Campo de comentario
                  TextField(
                    controller: _commentController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "¿Quieres añadir algo más?",
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.03),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(20),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Botón Enviar
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: _rating > 0 && !_isSubmitting ? _submitRating : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B00),
                        disabledBackgroundColor: Colors.white10,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      child: _isSubmitting 
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text("Enviar calificación", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Botón Omitir
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Omitir por ahora",
                      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [Color(0xFFFF6B00), Colors.white, Colors.orange, Colors.yellow],
          ),
        ],
      ),
    );
  }
}
