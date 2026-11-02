// Lógica de las finanzas: cuentas, tasas, totales, metas, cierres, importar y exportar.
import 'package:flutter/foundation.dart';

import '../../core/errores.dart';
import '../../core/csv.dart';
import '../../core/formato.dart';
import '../../core/hora_venezuela.dart';
import '../tasas/tasas_repositorio.dart';
import 'finanzas_repositorio.dart';
import '../movimientos/importador_mov.dart';
import '../movimientos/movimiento.dart';
import 'importador.dart';
import 'modelos.dart';

class FinanzasController extends ChangeNotifier {
  FinanzasController(this._repo, this._tasas) {
    RelojVzla.instancia.addListener(_porReloj);
    _iniciar();
  }

  final FinanzasRepositorio _repo;
  final TasasRepositorio _tasas;

  List<Cuenta> cuentas = [];
  List<Meta> metas = [];
  List<Cierre> cierres = []; // siempre ordenados del más antiguo al más reciente
  List<Movimiento> movimientos = []; // ídem
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

  double? get totalBcv => bcv == null ? null : dolares + bolivares / bcv!;
  double? get totalParalelo => paralelo == null ? null : dolares + bolivares / paralelo!;

  /// Cuánto vale una cuenta en dólares a tasa BCV.
  double? valorEnDolares(Cuenta c) =>
      c.moneda.esDolar ? c.saldo : (bcv == null ? null : c.saldo / bcv!);

  /// Etiquetas usadas antes (las recientes primero) más algunas de ejemplo.
  List<String> get etiquetasSugeridas {
    final r = <String>[];
    for (final x in cierres.reversed) {
      final e = x.etiqueta;
      if (e != null && e.isNotEmpty && !r.contains(e)) r.add(e);
    }
    for (final e in ['Gastos personales', 'Compras', 'Salida con amigos']) {
      if (!r.contains(e)) r.add(e);
    }
    return r.take(8).toList();
  }

  // ---- Inicio -------------------------------------------------------------
  void _notificar() {
    if (!_disposed) notifyListeners();
  }

  String _id() => '${DateTime.now().microsecondsSinceEpoch}_${_n++}';

  void _ordenar() => cierres.sort((x, y) => x.momento.compareTo(y.momento));

  void _ordenarMov() => movimientos.sort((x, y) => x.momento.compareTo(y.momento));

  String nuevoId() => _id();

  /// Medianoche en Venezuela (o volver a la app): toma la tasa que ya rige.
  Future<void> _porReloj() async {
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
    final p = await _tasas.paralelo();
    if (p != null) {
      paralelo = p;
      _cambio();
    }
  }

  Future<void> _iniciar() async {
    final d = await _repo.leer();
    cuentas = d.cuentas;
    metas = d.metas;
    cierres = d.cierres;
    _ordenar();
    movimientos = d.movimientos;
    _ordenarMov();
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

  void agregarMeta(String nombre, double monto) {
    metas.add(Meta(id: _id(), nombre: nombre.trim(), monto: monto));
    _cambio();
  }

  void eliminarMeta(Meta m) {
    metas.remove(m);
    _cambio();
  }

  /// Guarda una foto de este momento (una fila de tu Excel). Puedes guardar
  /// varias en el mismo día. Devuelve un mensaje de error, o null si salió bien.
  String? guardarCierre({String? etiqueta}) {
    final b = bcv, p = paralelo;
    if (cuentas.isEmpty) return 'Agrega al menos una cuenta.';
    if (b == null) return 'Aún no hay tasa BCV.';
    if (p == null) return 'Escribe la tasa paralelo para guardar el cierre.';
    final e = etiqueta?.trim();
    cierres.add(Cierre(
      id: _id(),
      momento: DateTime.now(),
      bcv: b,
      paralelo: p,
      totalBcv: totalBcv!,
      totalParalelo: totalParalelo!,
      saldos: {for (final c in cuentas) c.nombre: c.saldo},
      etiqueta: (e == null || e.isEmpty) ? null : e,
    ));
    _ordenar();
    _cambio();
    return null;
  }

  void editarEtiqueta(Cierre c, String? etiqueta) {
    final e = etiqueta?.trim();
    c.etiqueta = (e == null || e.isEmpty) ? null : e;
    _cambio();
  }

  void eliminarCierre(Cierre c) {
    cierres.remove(c);
    _cambio();
  }

  // ---- Movimientos --------------------------------------------------------
  Cuenta? _cuentaPorId(String id) {
    for (final c in cuentas) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Aplica (o revierte) el efecto de un movimiento sobre el saldo de su cuenta.
  void _efecto(Movimiento m, {required bool aplicar}) {
    if (!m.ajustoSaldo) return;
    final cu = _cuentaPorId(m.cuentaId);
    if (cu == null) return;
    final signo = (m.tipo.esGasto ? -1 : 1) * (aplicar ? 1 : -1);
    cu.saldo += signo * m.monto;
  }

  /// Guarda un movimiento nuevo, o reemplaza `anterior` si se está editando.
  void guardarMovimiento(Movimiento m, {Movimiento? anterior}) {
    if (anterior != null) {
      _efecto(anterior, aplicar: false);
      movimientos.removeWhere((x) => x.id == anterior.id);
    }
    movimientos.add(m);
    _efecto(m, aplicar: true);
    _ordenarMov();
    _cambio();
  }

  void eliminarMovimiento(Movimiento m) {
    _efecto(m, aplicar: false);
    movimientos.removeWhere((x) => x.id == m.id);
    _cambio();
  }

  List<String> get etiquetasSugeridasMov {
    final r = <String>[];
    for (final m in movimientos.reversed) {
      final e = m.etiqueta;
      if (e != null && e.isNotEmpty && !r.contains(e)) r.add(e);
    }
    for (final e in ['Comida', 'Transporte', 'Salida con amigos', 'Juegos', 'Servicios', 'Compras', 'Sueldo']) {
      if (!r.contains(e)) r.add(e);
    }
    return r.take(10).toList();
  }

  /// Movimientos como filas (para CSV).
  List<List<String>> filasMovimientos() {
    String n(double v, [int dec = 2]) => paraInput(v, dec);
    return [
      [
        'Fecha', 'Hora', 'Tipo', 'Etiqueta', 'Cuenta', 'Moneda', 'Monto',
        'Tasa BCV', 'Tasa paralelo', 'USD (BCV)', 'USD (paralelo)', 'Nota',
      ],
      for (final m in movimientos)
        [
          fechaCorta(m.momento),
          horaCorta(m.momento),
          m.tipo.nombre,
          m.etiqueta ?? '',
          m.cuentaNombre,
          m.moneda.etiqueta,
          n(m.monto),
          m.bcv > 0 ? n(m.bcv, 4) : '',
          m.paralelo == null ? '' : n(m.paralelo!, 4),
          n(m.valorUsd(false)),
          n(m.valorUsd(true)),
          m.nota ?? '',
        ],
    ];
  }

  String csvMovimientos() => escribirCsv(filasMovimientos());

  // ---- Importar / exportar -----------------------------------------------
  /// Agrega los cierres importados (omite los que ya existen en ese mismo momento)
  /// y crea las cuentas nuevas. Devuelve cuántos cierres se agregaron.
  int importar(ResultadoImport r) {
    final existentes = cierres.map((x) => x.momento.millisecondsSinceEpoch).toSet();
    var n = 0;
    for (final x in r.cierres) {
      if (existentes.add(x.momento.millisecondsSinceEpoch)) {
        cierres.add(x);
        n++;
      }
    }
    _ordenar();
    for (final cu in r.cuentas) {
      if (!cuentas.any((e) => e.nombre == cu.nombre)) cuentas.add(cu);
    }
    _cambio();
    return n;
  }

  /// Historial de cierres como filas (para CSV). Cada cuenta lleva su moneda: "Provincial (Bs)".
  List<List<String>> filasHistorial() {
    final nombres = <String>{for (final x in cierres) ...x.saldos.keys}.toList();
    final monedas = {for (final cu in cuentas) cu.nombre: cu.moneda.etiqueta};
    String n(double v, [int dec = 2]) => paraInput(v, dec);
    String encabezado(String nom) => monedas.containsKey(nom) ? '$nom (${monedas[nom]})' : nom;
    return [
      [
        'Fecha', 'Hora', 'Etiqueta', 'Tasa BCV', 'Tasa paralelo',
        for (final nom in nombres) encabezado(nom),
        'Total BCV', 'Total paralelo',
      ],
      for (final x in cierres)
        [
          fechaCorta(x.momento),
          horaCorta(x.momento),
          x.etiqueta ?? '',
          n(x.bcv, 4),
          n(x.paralelo, 4),
          for (final nom in nombres) x.saldos.containsKey(nom) ? n(x.saldos[nom]!) : '',
          n(x.totalBcv),
          n(x.totalParalelo),
        ],
    ];
  }

  String csvHistorial() => escribirCsv(filasHistorial());

  /// Agrega los movimientos importados (omite los repetidos) y crea las cuentas nuevas.
  /// Devuelve cuántos movimientos se agregaron.
  int importarMovimientos(ResultadoMov r) {
    for (final cu in r.cuentasNuevas) {
      if (!cuentas.any((e) => e.nombre.toLowerCase() == cu.nombre.toLowerCase())) cuentas.add(cu);
    }
    bool igual(Movimiento a, Movimiento b) =>
        a.momento == b.momento &&
        a.monto == b.monto &&
        a.tipo == b.tipo &&
        a.cuentaNombre.toLowerCase() == b.cuentaNombre.toLowerCase();
    var n = 0;
    for (final m in r.movimientos) {
      if (!movimientos.any((x) => igual(x, m))) {
        movimientos.add(m);
        n++;
      }
    }
    _ordenarMov();
    _cambio();
    return n;
  }

  String exportarJson() => FinanzasRepositorio.codificar(FinanzasDatos(
        cuentas: cuentas,
        metas: metas,
        cierres: cierres,
        movimientos: movimientos,
        paralelo: paralelo,
      ));

  /// Reemplaza todos los datos por los de una copia de seguridad.
  /// Devuelve un mensaje de error, o null si salió bien.
  String? restaurarJson(String texto) {
    try {
      final d = FinanzasRepositorio.decodificar(texto);
      cuentas = d.cuentas;
      metas = d.metas;
      cierres = d.cierres;
      _ordenar();
      movimientos = d.movimientos;
      _ordenarMov();
      paralelo = d.paralelo ?? paralelo;
      _cambio();
      return null;
    } catch (e, st) {
      RegistroErrores.instancia.registrar('Restaurar copia', e, st);
      return 'El texto no es una copia de seguridad válida.';
    }
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
      movimientos: movimientos,
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
    RelojVzla.instancia.removeListener(_porReloj);
    super.dispose();
  }
}
