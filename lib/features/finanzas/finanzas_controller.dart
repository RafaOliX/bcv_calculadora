// Lógica de las finanzas: cuentas, tasas, totales, metas, cierres, importar y exportar.
import 'package:flutter/foundation.dart';

import '../../core/errores.dart';
import '../../core/formato.dart';
import '../tasas/tasas_repositorio.dart';
import 'finanzas_repositorio.dart';
import 'importador.dart';
import 'modelos.dart';

class FinanzasController extends ChangeNotifier {
  FinanzasController(this._repo, this._tasas) {
    _iniciar();
  }

  final FinanzasRepositorio _repo;
  final TasasRepositorio _tasas;

  List<Cuenta> cuentas = [];
  List<Meta> metas = [];
  List<Cierre> cierres = []; // siempre ordenados del más antiguo al más reciente
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

  Future<void> _iniciar() async {
    final d = await _repo.leer();
    cuentas = d.cuentas;
    metas = d.metas;
    cierres = d.cierres;
    _ordenar();
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

  /// Tabla separada por tabulaciones: se pega directo en Excel.
  String exportarTabla() {
    final nombres = <String>{for (final x in cierres) ...x.saldos.keys}.toList();
    String n(double v, [int dec = 2]) => paraInput(v, dec);
    final b = StringBuffer()
      ..writeln(['Fecha', 'Hora', 'Etiqueta', 'Tasa BCV', 'Tasa paralelo', ...nombres, 'Total BCV', 'Total paralelo']
          .join('\t'));
    for (final x in cierres) {
      b.writeln([
        fechaCorta(x.momento),
        horaCorta(x.momento),
        (x.etiqueta ?? '').replaceAll('\t', ' '),
        n(x.bcv, 4),
        n(x.paralelo, 4),
        for (final nom in nombres) x.saldos.containsKey(nom) ? n(x.saldos[nom]!) : '',
        n(x.totalBcv),
        n(x.totalParalelo),
      ].join('\t'));
    }
    return b.toString();
  }

  String exportarJson() => FinanzasRepositorio.codificar(FinanzasDatos(
        cuentas: cuentas,
        metas: metas,
        cierres: cierres,
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
