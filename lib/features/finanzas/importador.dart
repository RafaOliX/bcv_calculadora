// Lectura de una hoja de Excel pegada como texto y conversión a cierres.
// Sin dependencias de Flutter: lógica pura.
import '../../core/formato.dart';
import 'modelos.dart';

enum Rol {
  ignorar('Ignorar'),
  fecha('Fecha'),
  bcv('Tasa BCV'),
  paralelo('Tasa paralelo'),
  etiqueta('Etiqueta'),
  bs('Cuenta en Bs'),
  usd('Cuenta en USD'),
  usdt('Cuenta en USDT');

  const Rol(this.nombre);
  final String nombre;

  bool get esCuenta => this == bs || this == usd || this == usdt;

  Moneda? get moneda => switch (this) {
        Rol.bs => Moneda.bs,
        Rol.usd => Moneda.usd,
        Rol.usdt => Moneda.usdt,
        _ => null,
      };
}

class TablaImportada {
  TablaImportada(this.encabezados, this.filas);
  final List<String> encabezados;
  final List<List<String>> filas;
}

class ResultadoImport {
  const ResultadoImport(this.cierres, this.cuentas, this.omitidas);
  final List<Cierre> cierres;
  final List<Cuenta> cuentas; // columnas de cuenta, con el saldo del cierre más reciente
  final int omitidas; // filas sin fecha o sin tasa BCV
}

/// Texto copiado de Excel (tabulaciones) o CSV (; o ,). La primera línea son los encabezados.
TablaImportada? leerTabla(String texto) {
  final lineas = texto.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
  if (lineas.length < 2) return null;
  final sep = lineas.first.contains('\t') ? '\t' : (lineas.first.contains(';') ? ';' : ',');
  List<String> celdas(String l) => l.split(sep).map((c) => c.trim().replaceAll('"', '')).toList();
  return TablaImportada(celdas(lineas.first), lineas.skip(1).map(celdas).toList());
}

Rol _adivinar(String h) {
  final t = h.toLowerCase().trim();
  if (t == 'fecha') return Rol.fecha;
  if (t.contains('etiqueta') || t.contains('nota') || t.contains('concepto')) return Rol.etiqueta;
  if (t.isEmpty ||
      t == 'dia' ||
      t == 'día' ||
      t == 'hora' ||
      t.contains('total') ||
      t.contains('falta') ||
      t.contains('objetivo') ||
      t.contains('diciembre') ||
      t.contains('p2p')) {
    return Rol.ignorar;
  }
  if (t.contains('paralelo')) return Rol.paralelo;
  if (t.contains('bcv')) return Rol.bcv;
  if (t.contains('usdt')) return Rol.usdt;
  if (t.contains('\$') || t.contains('usd') || t.contains('efectivo')) return Rol.usd;
  return Rol.bs;
}

List<Rol> adivinarRoles(List<String> encabezados) => encabezados.map(_adivinar).toList();

DateTime? _fecha(int a, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31) return null;
  return DateTime(a, m, d, 12);
}

/// dd/mm/aaaa, dd-mm-aa, dd/mm (año actual) o aaaa-mm-dd.
DateTime? parsearFecha(String texto) {
  final t = texto.trim();
  var m = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})[/\-.](\d{2,4})').firstMatch(t);
  if (m != null) {
    var a = int.parse(m[3]!);
    if (a < 100) a += 2000;
    return _fecha(a, int.parse(m[2]!), int.parse(m[1]!));
  }
  m = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(t);
  if (m != null) return _fecha(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  m = RegExp(r'^(\d{1,2})[/\-.](\d{1,2})$').firstMatch(t);
  if (m != null) return _fecha(DateTime.now().year, int.parse(m[2]!), int.parse(m[1]!));
  return null;
}

ResultadoImport construir(TablaImportada t, List<Rol> roles) {
  final iF = roles.indexOf(Rol.fecha);
  final iB = roles.indexOf(Rol.bcv);
  final iP = roles.indexOf(Rol.paralelo);
  final iE = roles.indexOf(Rol.etiqueta);
  final cols = [for (var i = 0; i < roles.length; i++) if (roles[i].esCuenta) i];
  if (iF < 0 || iB < 0 || cols.isEmpty) {
    return ResultadoImport(const [], const [], t.filas.length);
  }

  final cierres = <Cierre>[];
  var omitidas = 0;
  var n = 0;
  for (final fila in t.filas) {
    String c(int i) => (i >= 0 && i < fila.length) ? fila[i] : '';
    final f = parsearFecha(c(iF));
    final bcv = parsear(c(iB));
    if (f == null || bcv == null || bcv <= 0) {
      omitidas++;
      continue;
    }
    final leidaPar = iP >= 0 ? parsear(c(iP)) : null;
    final par = (leidaPar != null && leidaPar > 0) ? leidaPar : bcv;

    final saldos = <String, double>{};
    var usd = 0.0, bs = 0.0;
    for (final i in cols) {
      final v = parsear(c(i)) ?? 0;
      saldos[t.encabezados[i]] = v;
      if (roles[i] == Rol.bs) {
        bs += v;
      } else {
        usd += v;
      }
    }
    final et = iE >= 0 ? c(iE) : '';
    cierres.add(Cierre(
      id: 'imp_${f.millisecondsSinceEpoch}_${n++}',
      momento: f,
      bcv: bcv,
      paralelo: par,
      totalBcv: usd + bs / bcv,
      totalParalelo: usd + bs / par,
      saldos: saldos,
      etiqueta: et.isEmpty ? null : et,
    ));
  }
  cierres.sort((x, y) => x.momento.compareTo(y.momento));

  final cuentas = <Cuenta>[];
  if (cierres.isNotEmpty) {
    final ultimo = cierres.last;
    for (final i in cols) {
      final nombre = t.encabezados[i];
      cuentas.add(Cuenta(
        id: 'imp_c${i}_${n++}',
        nombre: nombre,
        moneda: roles[i].moneda!,
        saldo: ultimo.saldos[nombre] ?? 0,
      ));
    }
  }
  return ResultadoImport(cierres, cuentas, omitidas);
}
