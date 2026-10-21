// Lógica y estado del conversor. La pantalla solo dibuja lo que este
// controlador expone y le avisa de lo que hace el usuario.
import 'package:flutter/widgets.dart';

import '../../core/formato.dart';
import '../tasas/oficial.dart';
import '../tasas/tasas_repositorio.dart';

enum Fuente { usd, eur }

class ConversorController extends ChangeNotifier {
  ConversorController(this._repo) {
    _iniciar();
  }

  final TasasRepositorio _repo;

  // Los controladores de texto viven aquí para poder recalcular un campo
  // cuando el usuario edita el otro.
  final tasaCtrl = TextEditingController();
  final bsCtrl = TextEditingController();
  final divisaCtrl = TextEditingController();

  Oficial? oficial;
  Fuente fuente = Fuente.usd;
  bool cargando = false;
  String? aviso;
  String? detalle;

  double? _custom; // tasa escrita por el usuario; null = usar la oficial
  bool _editadoBs = true; // último campo de monto que tocó el usuario
  bool _disposed = false;

  double? get oficialActual => fuente == Fuente.usd ? oficial?.usd : oficial?.eur;
  double? get tasa => _custom ?? oficialActual;
  String get simbolo => fuente == Fuente.usd ? 'USD' : 'EUR';
  bool get esPersonalizada => _custom != null;

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _iniciar() async {
    final guardada = await _repo.leerGuardada();
    if (guardada != null) {
      oficial = guardada;
      _notificar();
    }
    await actualizar();
  }

  Future<void> actualizar() async {
    if (cargando) return;
    cargando = true;
    aviso = null;
    detalle = null;
    _notificar();
    try {
      oficial = await _repo.actualizar();
      _recalcular();
    } catch (e) {
      aviso = oficial == null
          ? 'No se pudo obtener la tasa.'
          : 'Sin conexión: mostrando la última tasa guardada.';
      detalle = e.toString();
    } finally {
      cargando = false;
      _notificar();
    }
  }

  // Recalcula el campo de monto que NO editó el usuario.
  void _recalcular() {
    final t = tasa;
    if (t == null || t <= 0) return;
    if (_editadoBs) {
      final bs = parsear(bsCtrl.text);
      divisaCtrl.text = bs == null ? '' : paraInput(bs / t);
    } else {
      final d = parsear(divisaCtrl.text);
      bsCtrl.text = d == null ? '' : paraInput(d * t);
    }
  }

  void cambiarFuente(Fuente f) {
    fuente = f;
    usarOficial();
  }

  void tasaEscrita(String texto) {
    final v = parsear(texto);
    _custom = (v != null && v > 0) ? v : null;
    _recalcular();
    _notificar();
  }

  void usarOficial() {
    _custom = null;
    tasaCtrl.clear();
    _recalcular();
    _notificar();
  }

  void montoEscrito({required bool esBs}) {
    _editadoBs = esBs;
    _recalcular();
    _notificar();
  }

  void limpiarMontos() {
    bsCtrl.clear();
    divisaCtrl.clear();
    _notificar();
  }

  @override
  void dispose() {
    _disposed = true;
    tasaCtrl.dispose();
    bsCtrl.dispose();
    divisaCtrl.dispose();
    super.dispose();
  }
}
