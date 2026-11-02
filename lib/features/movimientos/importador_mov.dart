// Convierte las filas de un CSV de movimientos en Movimiento. Sin Flutter.
import '../../core/formato.dart';
import '../finanzas/importador.dart';
import '../finanzas/modelos.dart';
import 'movimiento.dart';

class ResultadoMov {
  const ResultadoMov({
    this.movimientos = const [],
    this.cuentasNuevas = const [],
    this.omitidas = 0,
    this.sinTasa = 0,
    this.tasasBuscadas = 0,
    this.error,
  });

  final List<Movimiento> movimientos;
  final List<Cuenta> cuentasNuevas;
  final int omitidas; // filas con fecha, tipo, cuenta o monto inválidos
  final int sinTasa; // cuentas en Bs sin tasa BCV (ni escrita ni encontrada)
  final int tasasBuscadas; // filas cuya tasa BCV se buscó por fecha
  final String? error;
}

typedef TasaDelDia = Future<({double? bcv, double? paralelo})> Function(DateTime dia);

Future<ResultadoMov> construirMovimientos({
  required List<List<String>> filas,
  required List<Cuenta> existentes,
  required String Function() nuevoId,
  required TasaDelDia tasaDelDia,
}) async {
  if (filas.length < 2) {
    return const ResultadoMov(error: 'El archivo no tiene filas de datos debajo de los encabezados.');
  }
  final enc = filas.first.map((h) => h.toLowerCase().trim()).toList();
  int col(bool Function(String) test) {
    for (var i = 0; i < enc.length; i++) {
      if (test(enc[i])) return i;
    }
    return -1;
  }

  final iFecha = col((h) => h == 'fecha');
  final iHora = col((h) => h == 'hora');
  final iTipo = col((h) => h == 'tipo');
  final iEt = col((h) => h == 'etiqueta');
  final iCuenta = col((h) => h == 'cuenta');
  final iMon = col((h) => h == 'moneda');
  final iMonto = col((h) => h == 'monto');
  final iBcv = col((h) => h.startsWith('tasa bcv'));
  final iPar = col((h) => h.startsWith('tasa paralelo'));
  final iNota = col((h) => h == 'nota');

  final faltan = <String>[
    if (iFecha < 0) 'Fecha',
    if (iTipo < 0) 'Tipo',
    if (iCuenta < 0) 'Cuenta',
    if (iMonto < 0) 'Monto',
  ];
  if (faltan.isNotEmpty) {
    return ResultadoMov(
      omitidas: filas.length - 1,
      error: 'Faltan columnas: ${faltan.join(', ')}. Descarga la plantilla para ver el formato.',
    );
  }

  final porNombre = <String, Cuenta>{for (final c in existentes) c.nombre.toLowerCase(): c};
  final nuevas = <Cuenta>[];
  final movs = <Movimiento>[];
  final cache = <String, ({double? bcv, double? paralelo})>{};
  var omitidas = 0, sinTasa = 0, buscadas = 0;
  var buscar = true; // si una consulta falla del todo (sin internet), no insistir

  for (final fila in filas.skip(1)) {
    String c(int i) => (i >= 0 && i < fila.length) ? fila[i].trim() : '';

    final f = parsearFecha(c(iFecha));
    final monto = parsear(c(iMonto));
    final nombre = c(iCuenta);
    final t = c(iTipo).toLowerCase();
    final esGasto = t.startsWith('g') || t.startsWith('-') || t.contains('egreso');
    final esIngreso = t.startsWith('i') || t.startsWith('+');
    if (f == null || monto == null || monto <= 0 || nombre.isEmpty || (!esGasto && !esIngreso)) {
      omitidas++;
      continue;
    }

    final hm = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(c(iHora));
    final momento =
        hm == null ? f : DateTime(f.year, f.month, f.day, int.parse(hm[1]!), int.parse(hm[2]!));

    final existente = porNombre[nombre.toLowerCase()];
    final Cuenta cuenta;
    if (existente != null) {
      cuenta = existente;
    } else {
      final m = c(iMon).toLowerCase();
      final moneda = m.contains('usdt')
          ? Moneda.usdt
          : (m.contains('usd') || m.contains('\$') ? Moneda.usd : Moneda.bs);
      cuenta = Cuenta(id: nuevoId(), nombre: nombre, moneda: moneda);
      porNombre[nombre.toLowerCase()] = cuenta;
      nuevas.add(cuenta);
    }

    var bcv = parsear(c(iBcv));
    var par = parsear(c(iPar));
    if (bcv != null && bcv <= 0) bcv = null;
    if (par != null && par <= 0) par = null;
    if ((bcv == null || par == null) && buscar) {
      final clave = '${f.year}-${f.month}-${f.day}';
      var r = cache[clave];
      if (r == null) {
        r = await tasaDelDia(f);
        cache[clave] = r;
        if (r.bcv == null && r.paralelo == null) buscar = false;
      }
      if (bcv == null && r.bcv != null) {
        bcv = r.bcv;
        buscadas++;
      }
      par ??= r.paralelo;
    }
    if (!cuenta.moneda.esDolar && (bcv == null || bcv <= 0)) {
      sinTasa++;
      continue;
    }

    final et = c(iEt);
    final nota = c(iNota);
    movs.add(Movimiento(
      id: nuevoId(),
      momento: momento,
      tipo: esGasto ? TipoMov.gasto : TipoMov.ingreso,
      cuentaId: cuenta.id,
      cuentaNombre: cuenta.nombre,
      moneda: cuenta.moneda,
      monto: monto,
      bcv: bcv ?? 0,
      paralelo: par,
      etiqueta: et.isEmpty ? null : et,
      nota: nota.isEmpty ? null : nota,
      ajustoSaldo: false, // son históricos: no cambian los saldos actuales
    ));
  }

  return ResultadoMov(
    movimientos: movs,
    cuentasNuevas: nuevas,
    omitidas: omitidas,
    sinTasa: sinTasa,
    tasasBuscadas: buscadas,
  );
}
