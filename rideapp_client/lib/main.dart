import 'package:flutter/material.dart';
import 'package:rideapp_client/core/services/auth_service.dart';
import 'package:rideapp_client/core/services/notification_service.dart';
import 'package:rideapp_client/features/splash/splash_screen.dart';

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
    // Forzamos el inicio desde SplashScreen para cada reinicio
    const home = SplashScreen();

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
