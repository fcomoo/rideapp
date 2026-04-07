import 'package:flutter/material.dart';
import 'package:rideapp_client/core/services/auth_service.dart';
import 'package:rideapp_client/features/passenger/home_passenger.dart';
import 'package:rideapp_client/features/driver/home_driver.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  
  String _selectedRole = 'client'; // passenger
  bool _isLoading = false;

  Future<void> _handleRegister() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showError('Por favor llena los campos obligatorios');
      return;
    }

    if (_selectedRole == 'driver' && _phoneController.text.isEmpty) {
      _showError('El teléfono es obligatorio para conductores');
      return;
    }

    setState(() => _isLoading = true);
    final success = await AuthService().register(
      name: _nameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: _selectedRole,
      phone: _phoneController.text.trim(),
    );
    setState(() => _isLoading = false);

    if (success) {
      final user = AuthService().currentUser!;
      if (user['role'] == 'driver') {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => HomeDriver(driverId: user['id'])), (route) => false);
      } else {
        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => HomePassenger(currentUserId: user['id'])), (route) => false);
      }
    } else {
      _showError('Error al registrar usuario. Email posiblemente en uso.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          children: [
            const Text(
              'CREAR CUENTA',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
            ),
            const SizedBox(height: 32),
            
            // Role Selector
            Row(
              children: [
                Expanded(child: _buildRoleCard('client', '🧑 Pasajero', 'Solicita viajes')),
                const SizedBox(width: 16),
                Expanded(child: _buildRoleCard('driver', '🚗 Conductor', 'Genera ingresos')),
              ],
            ),
            const SizedBox(height: 32),
            
            _buildTextField(controller: _nameController, label: 'Nombre Completo', icon: Icons.person_outline),
            const SizedBox(height: 16),
            _buildTextField(controller: _emailController, label: 'Correo Electrónico', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            _buildTextField(controller: _phoneController, label: _selectedRole == 'driver' ? 'Teléfono (Obligatorio)' : 'Teléfono (Opcional)', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            _buildTextField(controller: _passwordController, label: 'Contraseña', icon: Icons.lock_outline, isPassword: true),
            
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B00),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _handleRegister,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('REGISTRARME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(String role, String title, String subtitle) {
    bool isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6B00).withOpacity(0.1) : const Color(0xFF1C1C1C),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? const Color(0xFFFF6B00) : Colors.white10, width: 2),
        ),
        child: Column(
          children: [
            Text(title.split(' ')[0], style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 12),
            Text(title.split(' ')[1], style: TextStyle(color: isSelected ? const Color(0xFFFF6B00) : Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(color: Colors.white38, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: const Color(0xFFFF6B00)),
        filled: true,
        fillColor: const Color(0xFF1C1C1C),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF6B00))),
      ),
    );
  }
}
