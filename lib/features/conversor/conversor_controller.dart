// Lógica y estado del conversor. La pantalla solo dibuja lo que este
// controlador expone y le avisa de lo que hace el usuario.
import 'package:flutter/widgets.dart';

import '../../core/formato.dart';
import '../../core/hora_venezuela.dart';
import '../tasas/oficial.dart';
import '../tasas/tasas_repositorio.dart';

enum Fuente { usd, eur }

enum Comparar {
  usd('USD'),
  eur('EUR'),
  otra('Otra');

  const Comparar(this.nombre);
  final String nombre;
}

/// Resultado de comparar la misma cantidad a dos tasas distintas.
class Diferencial {
  const Diferencial({
    required this.simA,
    required this.simB,
    required this.monto,
    required this.rA,
    required this.rB,
    required this.bsA,
    required this.bsB,
    required this.diff,
    required this.pct,
    required this.mismaMoneda,
    this.equivalente,
  });

  final String simA; // moneda de la conversión actual
  final String simB; // moneda de la tasa comparada
  final double monto; // cantidad (el mismo número) en ambas monedas
  final double rA, rB;
  final double bsA; // monto × tasa A
  final double bsB; // monto × tasa B
  final double diff; // bsB − bsA
  final double pct; // rB / rA − 1
  final bool mismaMoneda;
  final double? equivalente; // distinta moneda: bsA / rB (mismos Bs en la otra moneda)
}

class ConversorController extends ChangeNotifier {
  ConversorController(this._repo) {
    RelojVzla.instancia.addListener(_porReloj);
    _iniciar();
  }

  final TasasRepositorio _repo;

  // Los controladores de texto viven aquí para poder recalcular un campo
  // cuando el usuario edita el otro.
  final tasaCtrl = TextEditingController();
  final bsCtrl = TextEditingController();
  final divisaCtrl = TextEditingController();
  final compararCtrl = TextEditingController();

  Oficial? oficial;
  Oficial? proxima; // tasa ya publicada que rige desde un día futuro
  Fuente fuente = Fuente.usd;
  bool cargando = false;
  String? aviso;
  String? detalle;

  double? _custom; // tasa escrita por el usuario; null = usar la oficial
  bool _editadoBs = true; // último campo de monto que tocó el usuario
  bool _disposed = false;
  Comparar comparar = Comparar.eur;
  double? _compararCustom;

  double? get oficialActual => fuente == Fuente.usd ? oficial?.usd : oficial?.eur;
  double? get tasa => _custom ?? oficialActual;
  String get simbolo => fuente == Fuente.usd ? 'USD' : 'EUR';
  bool get esPersonalizada => _custom != null;

  // ---- Diferencial --------------------------------------------------------
  /// No se compara la tasa oficial de la misma moneda consigo misma.
  List<Comparar> get opcionesComparar {
    final excluida = esPersonalizada ? null : (fuente == Fuente.usd ? Comparar.usd : Comparar.eur);
    return Comparar.values.where((x) => x != excluida).toList();
  }

  Comparar get compararEfectivo {
    final op = opcionesComparar;
    return op.contains(comparar) ? comparar : op.first;
  }

  void cambiarComparar(Comparar x) {
    comparar = x;
    _notificar();
  }

  void compararEscrita(String texto) {
    final v = parsear(texto);
    _compararCustom = (v != null && v > 0) ? v : null;
    _notificar();
  }

  Diferencial? get diferencial {
    final rA = tasa;
    if (rA == null || rA <= 0) return null;
    final (simB, rB) = switch (compararEfectivo) {
      Comparar.usd => ('USD', oficial?.usd),
      Comparar.eur => ('EUR', oficial?.eur),
      Comparar.otra => (simbolo, _compararCustom),
    };
    if (rB == null || rB <= 0) return null;
    final monto = parsear(divisaCtrl.text) ?? 1;
    final bsA = monto * rA;
    final bsB = monto * rB;
    final misma = simB == simbolo;
    return Diferencial(
      simA: simbolo,
      simB: simB,
      monto: monto,
      rA: rA,
      rB: rB,
      bsA: bsA,
      bsB: bsB,
      diff: bsB - bsA,
      pct: rB / rA - 1,
      mismaMoneda: misma,
      equivalente: misma ? null : bsA / rB,
    );
  }

  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  /// Medianoche en Venezuela (o volver a la app): toma la tasa que ya rige.
  void _porReloj() => actualizar();

  Future<void> _iniciar() async {
    final guardada = await _repo.leerGuardada();
    if (guardada != null) {
      oficial = guardada;
      proxima = await _repo.proxima();
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
      proxima = await _repo.proxima();
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
      divisaCtrl.text = bs == null ? '' : paraCampo(bs / t);
    } else {
      final d = parsear(divisaCtrl.text);
      bsCtrl.text = d == null ? '' : paraCampo(d * t);
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

  /// Intercambia lo escrito en los dos campos (por si pusiste los bolívares en
  /// el campo de dólares o al revés) y recalcula el otro.
  void intercambiarMontos() {
    final a = bsCtrl.text;
    bsCtrl.text = divisaCtrl.text;
    divisaCtrl.text = a;
    _editadoBs = !_editadoBs; // el texto que escribiste ahora está en el otro campo
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
    RelojVzla.instancia.removeListener(_porReloj);
    tasaCtrl.dispose();
    bsCtrl.dispose();
    divisaCtrl.dispose();
    compararCtrl.dispose();
    super.dispose();
  }
}
