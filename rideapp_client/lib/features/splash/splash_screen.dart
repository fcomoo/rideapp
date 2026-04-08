import 'package:flutter/material.dart';
import 'package:rideapp_client/core/services/auth_service.dart';
import 'package:rideapp_client/features/auth/login_screen.dart';
import 'package:rideapp_client/features/onboarding/onboarding_screen.dart';
import 'package:rideapp_client/features/passenger/home_passenger.dart';
import 'package:rideapp_client/features/driver/home_driver.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack)),
    );

    _controller.forward();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Inicializar servicios principales
    final authService = AuthService();
    await authService.init();
    
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

    // 2. Esperar al menos el tiempo de la animación
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // 3. Determinar destino
    Widget destination;
    
    if (!hasSeenOnboarding) {
      destination = const OnboardingScreen();
    } else if (authService.isLoggedIn() && authService.currentUser != null) {
      final user = authService.currentUser!;
      if (user['role'] == 'driver') {
        destination = HomeDriver(driverId: user['id']);
      } else {
        destination = HomePassenger(currentUserId: user['id']);
      }
    } else {
      destination = const LoginScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo animado
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B00).withOpacity(0.1),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF6B00).withOpacity(0.2),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_car,
                        size: 100,
                        color: Color(0xFFFF6B00),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const Text(
                      'RIDEAPP',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 8,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'MOVILIDAD PREMIUM',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 4,
                        color: Colors.white38,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 80),
                    const CircularProgressIndicator(
                      color: Color(0xFFFF6B00),
                      strokeWidth: 2,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
