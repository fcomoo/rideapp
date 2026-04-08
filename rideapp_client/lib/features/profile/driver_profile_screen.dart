import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rideapp_client/core/services/auth_service.dart';
import 'package:rideapp_client/features/auth/login_screen.dart';
import 'package:rideapp_client/core/config/app_config.dart';

class DriverProfileScreen extends StatefulWidget {
  final String userId;
  final String? name;
  final String? email;
  final String? phone;

  const DriverProfileScreen({
    super.key,
    required this.userId,
    this.name,
    this.email,
    this.phone,
  });

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  String? _avatarUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _avatarUrl = prefs.getString('avatar_url_${widget.userId}') ?? AuthService().currentUser?['avatarUrl'];
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 50);

    if (pickedFile != null) {
      _uploadImage(File(pickedFile.path));
    }
  }

  Future<void> _uploadImage(File imageFile) async {
    setState(() => _isUploading = true);
    try {
      final uri = Uri.parse('${AppConfig.apiUrl}/api/upload/avatar?userId=${widget.userId}');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      final response = await request.send();
      if (response.statusCode == 200) {
        final respStr = await response.stream.bytesToString();
        final data = jsonDecode(respStr);
        final newUrl = data['avatarUrl'];

        setState(() {
          _avatarUrl = newUrl;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('avatar_url_${widget.userId}', newUrl);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al subir la imagen')));
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1C),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFFF6B00)),
              title: const Text('Cámara', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFFFF6B00)),
              title: const Text('Galería', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _handleLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        title: const Text('CERRAR SESIÓN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('¿Estás seguro de que deseas salir?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            onPressed: () async {
              await AuthService().logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('CERRAR SESIÓN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Construir URL completa si es relativa
    final fullAvatarUrl = (_avatarUrl != null && _avatarUrl!.startsWith('/'))
        ? '${AppConfig.apiUrl}$_avatarUrl'
        : _avatarUrl;

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('PERFIL CONDUCTOR', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 60,
                  backgroundColor: const Color(0xFF1C1C1C),
                  backgroundImage: fullAvatarUrl != null ? NetworkImage(fullAvatarUrl) : null,
                  child: fullAvatarUrl == null 
                      ? const Icon(Icons.person, size: 80, color: Color(0xFFFF6B00))
                      : (_isUploading ? const CircularProgressIndicator(color: Color(0xFFFF6B00)) : null),
                ),
                GestureDetector(
                  onTap: _showPickerOptions,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Color(0xFFFF6B00), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              widget.name ?? 'Conductor',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              widget.email ?? '',
              style: const TextStyle(color: Colors.white38),
            ),
            if (widget.phone != null && widget.phone!.isNotEmpty)
              Text(
                widget.phone!,
                style: const TextStyle(color: Colors.white38),
              ),
            const SizedBox(height: 40),
            _buildInfoCard(context),
            const SizedBox(height: 60),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => _handleLogout(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('CERRAR SESIÓN', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          _buildInfoRow(Icons.directions_car, 'Vehículo', 'No configurado'),
          const Divider(color: Colors.white10, height: 32),
          _buildInfoRow(Icons.star, 'Calificación', '⭐ 5.0'),
          const Divider(color: Colors.white10, height: 32),
          _buildInfoRow(Icons.route, 'Viajes completados', '0'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF6B00), size: 24),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }
}
