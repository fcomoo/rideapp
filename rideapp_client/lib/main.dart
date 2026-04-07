import 'package:flutter/material.dart';
import 'package:rideapp_client/core/services/auth_service.dart';
import 'package:rideapp_client/core/services/notification_service.dart';
import 'package:rideapp_client/features/auth/login_screen.dart';
import 'package:rideapp_client/features/passenger/home_passenger.dart';
import 'package:rideapp_client/features/driver/home_driver.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  
  final authService = AuthService();
  await authService.init();

  runApp(RideApp(authService: authService));
}

class RideApp extends StatelessWidget {
  final AuthService authService;
  const RideApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    Widget home;
    if (authService.isLoggedIn() && authService.currentUser != null) {
      final user = authService.currentUser!;
      if (user['role'] == 'driver') {
        home = HomeDriver(driverId: user['id']);
      } else {
        home = HomePassenger(currentUserId: user['id']);
      }
    } else {
      home = const LoginScreen();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFFFF6B00),
      ),
      home: home,
    );
  }
}

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.directions_car, size: 80, color: Color(0xFFFF6B00)),
              const SizedBox(height: 32),
              const Text(
                'BIENVENIDO A RIDEAPP',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(height: 48),
              _buildRoleButton(
                context, 
                label: 'PASAJERO', 
                icon: Icons.person,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomePassenger(currentUserId: 'test-passenger-123'))),
              ),
              const SizedBox(height: 16),
              _buildRoleButton(
                context, 
                label: 'CONDUCTOR', 
                icon: Icons.drive_eta,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HomeDriver(driverId: 'test-driver-456'))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleButton(BuildContext context, {required String label, required IconData icon, required VoidCallback onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1C1C1C),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
        ),
        onPressed: onTap,
        icon: Icon(icon, color: const Color(0xFFFF6B00)),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
