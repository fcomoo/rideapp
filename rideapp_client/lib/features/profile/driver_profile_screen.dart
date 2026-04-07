import 'package:flutter/material.dart';
import 'package:rideapp_client/features/rating/rating_widget.dart';

class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {}, // Solo visualización en esta fase
            child: const Text(
              "Editar",
              style: TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            _buildVehicleSection(),
            const SizedBox(height: 24),
            _buildStatsSection(),
            const SizedBox(height: 24),
            _buildReviewsSection(),
            const SizedBox(height: 24),
            _buildDocumentsSection(),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Avatar grande
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFF6B00).withOpacity(0.1),
            border: Border.all(color: const Color(0xFFFF6B00), width: 3),
            boxShadow: [
              BoxShadow(color: const Color(0xFFFF6B00).withOpacity(0.2), blurRadius: 15, spreadRadius: 2),
            ],
          ),
          child: const Center(
            child: Text(
              "CM",
              style: TextStyle(color: Color(0xFFFF6B00), fontSize: 44, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Nombre y Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              "Carlos Méndez García",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.check_circle, color: Colors.blue, size: 22),
          ],
        ),
        const SizedBox(height: 8),
        // Rating
        const RatingWidget(rating: 4.9, count: 247, size: 18),
        const SizedBox(height: 6),
        Text(
          "Macuspana, Tabasco",
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _buildVehicleSection() {
    return _buildSectionLayout(
      title: "Mi Vehículo",
      icon: Icons.directions_car_rounded,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B00).withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.directions_car, color: Color(0xFFFF6B00), size: 36),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Nissan Versa 2022",
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Placa: TAB-2024-XYZ",
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Color: Blanco • Verificado",
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return _buildSectionLayout(
      title: "Estadísticas",
      icon: Icons.analytics_outlined,
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
        children: [
          _buildStatCard("Viajes Totales", "247", Icons.local_taxi),
          _buildStatCard("Ganancias Mes", "\$8,450", Icons.monetization_on),
          _buildStatCard("Aceptación", "94%", Icons.thumb_up),
          _buildStatCard("Tiempo Sem.", "38h", Icons.timer),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFFF6B00).withOpacity(0.6), size: 20),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsSection() {
    final reviews = [
      {"name": "Ana L.", "rating": 5.0, "comment": "Excelente servicio, muy puntual.", "date": "Hoy"},
      {"name": "Roberto M.", "rating": 4.0, "comment": "Auto muy limpio, recomendado.", "date": "Ayer"},
      {"name": "Elena P.", "rating": 5.0, "comment": "Muy amable durante el trayecto.", "date": "3 abr"},
    ];

    return _buildSectionLayout(
      title: "Reseñas Recientes",
      icon: Icons.star_outline_rounded,
      child: Column(
        children: reviews.map((r) => _buildReviewTile(r)).toList(),
      ),
    );
  }

  Widget _buildReviewTile(Map<String, dynamic> r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFFFF6B00).withOpacity(0.1),
                child: Text(
                  r["name"][0],
                  style: const TextStyle(fontSize: 11, color: Color(0xFFFF6B00), fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                r["name"],
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                r["date"],
                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          RatingWidget(rating: r["rating"], size: 14),
          const SizedBox(height: 6),
          Text(
            r["comment"],
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentsSection() {
    final docs = [
      {"title": "Licencia de Conducir", "status": true},
      {"title": "INE / Identificación", "status": true},
      {"title": "Seguro del Vehículo", "status": true},
      {"title": "Antecedentes Penales", "status": false},
    ];

    return _buildSectionLayout(
      title: "Documentos de Macuspana",
      icon: Icons.description_outlined,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: docs.map((d) {
            final isApproved = d["status"] as bool;
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              leading: Icon(
                isApproved ? Icons.verified_user : Icons.pending_actions,
                color: isApproved ? Colors.green : Colors.red,
                size: 20,
              ),
              title: Text(
                d["title"] as String,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white10, size: 14),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSectionLayout({required String title, required IconData icon, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFF6B00), size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
