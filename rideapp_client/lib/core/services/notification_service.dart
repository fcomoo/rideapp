import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Configuración Android
    const AndroidInitializationSettings initializationSettingsAndroid = 
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Configuración iOS
    final DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Aquí se podría navegar a la pantalla del viaje o chat si es necesario
        print("Notificación tocada: ${details.payload}");
      },
    );

    // Crear Canal de Alta Importancia para Android (Nuevos Viajes)
    if (Platform.isAndroid) {
      const AndroidNotificationChannel highImportanceChannel = AndroidNotificationChannel(
        'rideapp_high_importance',
        'Notificaciones Críticas de Viaje',
        description: 'Canal para nuevas solicitudes de viaje con alta visibilidad y vibración.',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(highImportanceChannel);

      // Canal por defecto
      const AndroidNotificationChannel defaultChannel = AndroidNotificationChannel(
        'rideapp_default',
        'Notificaciones Generales',
        description: 'Canal para actualizaciones de estado y mensajes de chat.',
        importance: Importance.defaultImportance,
        enableVibration: true,
        playSound: true,
      );

      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(defaultChannel);
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    bool isUrgent = false,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      isUrgent ? 'rideapp_high_importance' : 'rideapp_default',
      isUrgent ? 'Urgente' : 'General',
      channelDescription: 'Canal para RideApp en Macuspana',
      importance: isUrgent ? Importance.max : Importance.defaultImportance,
      priority: isUrgent ? Priority.high : Priority.defaultPriority,
      ticker: 'ticker',
      playSound: true,
      enableVibration: true,
      fullScreenIntent: isUrgent, // Útil para que aparezca en pantalla de bloqueo
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      id, 
      title, 
      body, 
      notificationDetails, 
      payload: payload
    );
  }

  /// Método especializado para despachar eventos de Antigravity
  Future<void> dispatchTripEvent(String type, Map<String, dynamic> data) async {
    String title = "Actualización de Viaje";
    String body = "Hay cambios en tu servicio.";
    bool urgent = false;
    int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    switch (type) {
      case 'trip.requested':
        title = "🔔 Nueva solicitud de viaje";
        body = "Pasajero a ${data['distance'] ?? '1.2'}km • \$${data['price'] ?? '85.00'}";
        urgent = true;
        break;
      case 'trip.accepted':
        title = "🚗 Conductor en camino";
        body = "${data['driverName'] ?? 'Tu conductor'} ha aceptado el viaje.";
        break;
      case 'trip.arrived':
        title = "📍 Tu conductor llegó";
        body = "${data['driverName'] ?? 'Tu conductor'} te espera en el punto.";
        urgent = true;
        break;
      case 'trip.completed':
        title = "✅ Viaje completado";
        body = "¡Esperamos que hayas tenido un buen viaje! Califica tu experiencia.";
        break;
      case 'chat.message':
        final msg = data['text'] as String? ?? "";
        title = "💬 Nuevo mensaje";
        body = msg.length > 50 ? "${msg.substring(0, 47)}..." : msg;
        break;
    }

    await showNotification(
      id: notificationId,
      title: title,
      body: body,
      isUrgent: urgent,
      payload: type,
    );
  }
}
