// Registro central de errores: cualquier capa puede anotar un error aquí y la
// interfaz lo muestra con "Ver detalles" (y se puede copiar).
import 'package:flutter/foundation.dart';

class ErrorApp {
  ErrorApp(this.origen, this.mensaje, this.pila) : hora = DateTime.now();

  final DateTime hora;
  final String origen;
  final String mensaje;
  final String? pila;

  @override
  String toString() =>
      '[${hora.toIso8601String()}] $origen\n$mensaje${pila == null ? '' : '\n$pila'}';
}

class RegistroErrores extends ChangeNotifier {
  RegistroErrores._();
  static final instancia = RegistroErrores._();

  final List<ErrorApp> _lista = [];

  List<ErrorApp> get todos => List.unmodifiable(_lista);

  void registrar(String origen, Object error, [StackTrace? pila]) {
    final corta = pila?.toString().split('\n').take(12).join('\n');
    _lista.add(ErrorApp(origen, error.toString(), corta));
    if (_lista.length > 30) _lista.removeAt(0);
    notifyListeners();
  }

  /// Todo el registro, el más reciente primero, listo para copiar.
  String get texto =>
      _lista.isEmpty ? 'No hay detalles registrados.' : _lista.reversed.join('\n\n---\n\n');

  void limpiar() {
    _lista.clear();
    notifyListeners();
  }
}
