import 'dart:async';
import 'package:rideapp_client/core/antigravity/client.dart';
import 'package:rideapp_client/core/antigravity/profile.dart';
import 'package:rideapp_client/domain/entities/trip.dart';

/// Kill Switch: cancela la búsqueda si transcurre el tiempo límite sin conductor.
class KillSwitch {
  // El valor se ajusta desde AntigravityProfile
  static final int _timeoutSeconds = AntigravityProfile.searchTimeout.inSeconds;
  
  Timer? _timer;

  /// Inicia el cronómetro de búsqueda. Si ya existe uno para esta instancia, se cancela.
  void startSearchTimeout({
    required Trip trip, 
    required Function() onTimeout,
  }) {
    // 5. El timer debe cancelarse automáticamente si se llama startSearchTimeout de nuevo
    _timer?.cancel();
    
    _timer = Timer(Duration(seconds: _timeoutSeconds), () {
      // 3. Al activarse el timeout:
      
      // Imprimir log del evento
      print('KillSwitch ACTIVATED: no driver found in ${_timeoutSeconds}s for trip ${trip.id}');
      
      // Llamar a Antigravity.emit para cancelar en backend
      Antigravity.emit('cancel_search', {'tripId': trip.id});
      
      // Ejecutar callback para limpiar la UI
      onTimeout();
      
      _timer = null;
    });
  }

  /// 4. Detiene el timer (ej. si el conductor acepta antes de los 60s)
  void cancel() {
    if (_timer != null) {
      print('KillSwitch CANCELLED: search resolved before timeout.');
      _timer?.cancel();
      _timer = null;
    }
  }
}
