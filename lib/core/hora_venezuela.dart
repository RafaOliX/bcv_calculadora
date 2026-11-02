// Hora de Venezuela (UTC−4 todo el año, sin horario de verano) y un "reloj" que
// avisa cuando cambia el día allá (medianoche) o cuando se vuelve a abrir la app.
import 'dart:async';

import 'package:flutter/foundation.dart';

/// La hora actual en Caracas, como fecha "sin zona" (solo sus campos importan).
DateTime ahoraVzla() {
  final u = DateTime.now().toUtc().subtract(const Duration(hours: 4));
  return DateTime(u.year, u.month, u.day, u.hour, u.minute, u.second);
}

/// El día de hoy en Venezuela (a las 00:00).
DateTime hoyVzla() {
  final n = ahoraVzla();
  return DateTime(n.year, n.month, n.day);
}

class RelojVzla extends ChangeNotifier {
  RelojVzla._();
  static final instancia = RelojVzla._();

  Timer? _timer;
  DateTime _dia = hoyVzla();
  DateTime? _ultimo;

  /// Programa el aviso de la próxima medianoche en Caracas.
  void iniciar() => _programar();

  void _programar() {
    _timer?.cancel();
    final n = ahoraVzla();
    final falta = const Duration(hours: 24) -
        Duration(hours: n.hour, minutes: n.minute, seconds: n.second);
    _timer = Timer(falta + const Duration(seconds: 3), _alMedianoche);
  }

  void _alMedianoche() {
    _dia = hoyVzla();
    _ultimo = DateTime.now();
    notifyListeners();
    _programar();
  }

  /// Al volver a la app: avisa si cambió el día o si pasaron más de 2 minutos.
  void alReanudar() {
    final h = hoyVzla();
    final ahora = DateTime.now();
    if (h != _dia || _ultimo == null || ahora.difference(_ultimo!) > const Duration(minutes: 2)) {
      _dia = h;
      _ultimo = ahora;
      notifyListeners();
    }
    _programar();
  }
}
