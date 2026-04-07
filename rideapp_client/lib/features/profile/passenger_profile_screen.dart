import 'package:flutter/material.dart';
import 'package:rideapp_client/features/rating/rating_widget.dart';
import 'package:rideapp_client/features/history/trip_history_screen.dart';

class PassengerProfileScreen extends StatelessWidget {
  const PassengerProfileScreen({super.key});

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
            _buildStatsSection(),
            const SizedBox(height: 12),
            _buildTextActionButton(
              "Ver historial completo", 
              Icons.history_rounded,
              onTap: () => Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const TripHistoryScreen(userId: 'maria-gonzalez-123'))
              )
            ),
            const SizedBox(height: 24),
            _buildPaymentMethodsSection(),
            const SizedBox(height: 24),
            _buildAddressesSection(),
            const SizedBox(height: 24),
            _buildPassengerRatingSection(),
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
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFFF6B00).withOpacity(0.1),
            border: Border.all(color: const Color(0xFFFF6B00), width: 3),
            boxShadow: [
              BoxShadow(color: const Color(0xFFFF6B00).withOpacity(0.1), blurRadius: 15, spreadRadius: 2),
            ],
          ),
          child: const Center(
            child: Text(
              "MG",
              style: TextStyle(color: Color(0xFFFF6B00), fontSize: 40, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Nombre
        const Text(
          "María González López",
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        // Contacto
        Text(
          "maria@gmail.com • +52 918 123 4567",
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14),
        ),
        const SizedBox(height: 6),
        Text(
          "Miembro desde Octubre 2023",
          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStatsSection() {
    return _buildSectionLayout(
      title: "Mis Estadísticas",
      icon: Icons.bar_chart_rounded,
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
        children: [
          _buildStatCard("Viajes", "43", Icons.directions_car),
          _buildStatCard("Km", "312", Icons.map),
          _buildStatCard("Gasto Total", "\$3,655", Icons.monetization_on),
          _buildStatCard("Cond. Fav", "Carlos M.", Icons.stars_rounded),
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
          Icon(icon, color: const Color(0xFFFF6B00), size: 18),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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

  Widget _buildPaymentMethodsSection() {
    return _buildSectionLayout(
      title: "Método de Pago",
      icon: Icons.payment_rounded,
      child: Column(
        children: [
          _buildPaymentTile("Efectivo", Icons.account_balance_wallet_outlined, true),
          const SizedBox(height: 12),
          _buildPaymentTile("Tarjeta **** 4412", Icons.credit_card_rounded, false),
          const SizedBox(height: 12),
          _buildTextActionButton("Agregar método de pago", Icons.add_circle_outline),
        ],
      ),
    );
  }

  Widget _buildPaymentTile(String label, IconData icon, bool verified) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const Spacer(),
          if (verified)
            const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
        ],
      ),
    );
  }

  Widget _buildAddressesSection() {
    return _buildSectionLayout(
      title: "Direcciones Guardadas",
      icon: Icons.bookmark_outline_rounded,
      child: Column(
        children: [
          _buildAddressTile("Casa", "Calle Gardenia #12, Macuspana", Icons.home_rounded),
          const SizedBox(height: 12),
          _buildAddressTile("Trabajo", "Av. Carlos Pellicer #45, Macuspana", Icons.work_rounded),
          const SizedBox(height: 12),
          _buildTextActionButton("Agregar dirección", Icons.add_location_alt_outlined),
        ],
      ),
    );
  }

  Widget _buildAddressTile(String label, String address, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B00).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFFFF6B00), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  address,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPassengerRatingSection() {
    return _buildSectionLayout(
      title: "Tu Reputación",
      icon: Icons.stars_outlined,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "4.8",
                      style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const RatingWidget(rating: 4.8, size: 18),
                    const SizedBox(height: 6),
                    Text(
                      "De 43 viajes calificados",
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF6B00).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFF6B00).withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.workspace_premium_rounded, color: Color(0xFFFF6B00), size: 18),
                      SizedBox(width: 8),
                      Text(
                        "Pasajero VIP",
                        style: TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextActionButton(String label, IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFFF6B00), size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(color: Color(0xFFFF6B00), fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ],
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
