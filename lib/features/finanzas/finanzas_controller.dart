// Lógica de las finanzas: cuentas, tasas, totales, metas y cierres diarios.
import 'package:flutter/foundation.dart';

import '../tasas/tasas_repositorio.dart';
import 'finanzas_repositorio.dart';
import 'modelos.dart';

class FinanzasController extends ChangeNotifier {
  FinanzasController(this._repo, this._tasas) {
    _iniciar();
  }

  final FinanzasRepositorio _repo;
  final TasasRepositorio _tasas;

  List<Cuenta> cuentas = [];
  List<Meta> metas = [];
  List<Cierre> cierres = [];
  double p2p = 0; // dólares pendientes por P2P (se restan del total)
  double? bcv;
  double? paralelo;
  DateTime? fechaBcv;
  bool cargando = true;
  bool sinGuardado = false;

  bool _disposed = false;
  int _n = 0;

  // ---- Cálculos (equivalen a las fórmulas de tu Excel) --------------------
  /// USD + USDT + efectivo $
  double get dolares =>
      cuentas.where((c) => c.moneda.esDolar).fold(0.0, (s, c) => s + c.saldo);

  /// Suma de las cuentas en bolívares
  double get bolivares =>
      cuentas.where((c) => !c.moneda.esDolar).fold(0.0, (s, c) => s + c.saldo);

  double? get totalBcv => bcv == null ? null : dolares + bolivares / bcv! - p2p;
  double? get totalParalelo => paralelo == null ? null : dolares + bolivares / paralelo! - p2p;

  /// Cuánto vale una cuenta en dólares a tasa BCV.
  double? valorEnDolares(Cuenta c) =>
      c.moneda.esDolar ? c.saldo : (bcv == null ? null : c.saldo / bcv!);

  // ---- Inicio -------------------------------------------------------------
  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  String _id() => '${DateTime.now().microsecondsSinceEpoch}_${_n++}';

  Future<void> _iniciar() async {
    final d = await _repo.leer();
    cuentas = d.cuentas;
    metas = d.metas;
    cierres = d.cierres..sort((x, y) => x.fecha.compareTo(y.fecha));
    p2p = d.p2p;
    paralelo = d.paralelo;
    cargando = false;
    _notificar();

    final g = await _tasas.leerGuardada();
    if (g != null) {
      bcv = g.usd;
      fechaBcv = g.fecha;
      _notificar();
    }
    try {
      final o = await _tasas.actualizar();
      bcv = o.usd;
      fechaBcv = o.fecha;
      _notificar();
    } catch (_) {}

    // Paralelo automático si hay fuente; si no, queda el último valor guardado.
    final p = await _tasas.paralelo();
    if (p != null) {
      paralelo = p;
      _cambio();
    }
  }

  // ---- Acciones -----------------------------------------------------------
  void agregarCuenta(String nombre, Moneda m) {
    cuentas.add(Cuenta(id: _id(), nombre: nombre.trim(), moneda: m));
    _cambio();
  }

  void cargarEjemplo() {
    cuentas.addAll([
      Cuenta(id: _id(), nombre: 'Provincial', moneda: Moneda.bs),
      Cuenta(id: _id(), nombre: 'Bancamiga Bs', moneda: Moneda.bs),
      Cuenta(id: _id(), nombre: 'Bancamiga \$', moneda: Moneda.usd),
      Cuenta(id: _id(), nombre: 'Efectivo \$', moneda: Moneda.usd),
      Cuenta(id: _id(), nombre: 'Binance', moneda: Moneda.usdt),
    ]);
    _cambio();
  }

  void editarSaldo(Cuenta c, double v) {
    c.saldo = v;
    _cambio();
  }

  void eliminarCuenta(Cuenta c) {
    cuentas.remove(c);
    _cambio();
  }

  void setParalelo(double v) {
    paralelo = v;
    _cambio();
  }

  void setP2p(double v) {
    p2p = v;
    _cambio();
  }

  void agregarMeta(String nombre, double monto) {
    metas.add(Meta(id: _id(), nombre: nombre.trim(), monto: monto));
    _cambio();
  }

  void eliminarMeta(Meta m) {
    metas.remove(m);
    _cambio();
  }

  /// Guarda la foto de hoy (una fila de tu Excel). Si ya existe la de hoy, la reemplaza.
  /// Devuelve un mensaje de error, o null si todo salió bien.
  String? guardarCierre() {
    final b = bcv, p = paralelo;
    if (cuentas.isEmpty) return 'Agrega al menos una cuenta.';
    if (b == null) return 'Aún no hay tasa BCV.';
    if (p == null) return 'Escribe la tasa paralelo para guardar el cierre.';
    final h = DateTime.now();
    String dos(int n) => n.toString().padLeft(2, '0');
    final fecha = '${h.year}-${dos(h.month)}-${dos(h.day)}';
    final nuevo = Cierre(
      fecha: fecha,
      bcv: b,
      paralelo: p,
      p2p: p2p,
      totalBcv: totalBcv!,
      totalParalelo: totalParalelo!,
      saldos: {for (final c in cuentas) c.nombre: c.saldo},
    );
    cierres
      ..removeWhere((x) => x.fecha == fecha)
      ..add(nuevo)
      ..sort((x, y) => x.fecha.compareTo(y.fecha));
    _cambio();
    return null;
  }

  void eliminarCierre(Cierre c) {
    cierres.remove(c);
    _cambio();
  }

  // ---- Persistencia -------------------------------------------------------
  void _cambio() {
    _persistir();
    _notificar();
  }

  Future<void> _persistir() async {
    final ok = await _repo.guardar(FinanzasDatos(
      cuentas: cuentas,
      metas: metas,
      cierres: cierres,
      p2p: p2p,
      paralelo: paralelo,
    ));
    if (sinGuardado == ok) {
      sinGuardado = !ok;
      _notificar();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
