// Lógica pura: agrupar movimientos y calcular resúmenes y análisis.
import '../../core/rango_fechas.dart';
import '../finanzas/historial_logica.dart';
import 'movimiento.dart';

class GrupoMov {
  GrupoMov(this.clave, this.titulo, this.items, this.ingresos, this.gastos);

  final String clave;
  final String titulo;
  final List<Movimiento> items; // el más reciente primero
  final double ingresos; // en dólares
  final double gastos; // en dólares, número positivo

  double get neto => ingresos - gastos;
}

/// `asc`: del más antiguo al más reciente. Devuelve los grupos, el más reciente primero.
List<GrupoMov> agruparMov(List<Movimiento> asc, Agrupar modo, bool enParalelo) {
  final mapa = <String, List<Movimiento>>{};
  final titulos = <String, String>{};
  for (final m in asc) {
    final k = claveGrupo(m.momento, modo);
    mapa.putIfAbsent(k.clave, () => []).add(m);
    titulos[k.clave] = k.titulo;
  }
  final r = <GrupoMov>[];
  for (final e in mapa.entries) {
    var ing = 0.0, gas = 0.0;
    for (final m in e.value) {
      final v = m.firmado(enParalelo);
      if (v >= 0) {
        ing += v;
      } else {
        gas += -v;
      }
    }
    r.add(GrupoMov(e.key, titulos[e.key]!, e.value.reversed.toList(), ing, gas));
  }
  return r.reversed.toList();
}

class ResumenMov {
  ResumenMov({
    required this.ingresos,
    required this.gastos,
    required this.gastoPorEtiqueta,
    required this.ingresoPorEtiqueta,
    required this.gastoPorDiaSemana,
    required this.gastoPorDia,
    required this.dias,
  });

  final double ingresos;
  final double gastos;
  final List<MapEntry<String, double>> gastoPorEtiqueta; // de mayor a menor
  final List<MapEntry<String, double>> ingresoPorEtiqueta;
  final List<double> gastoPorDiaSemana; // lunes..domingo
  final Map<DateTime, double> gastoPorDia;
  final int dias; // días que abarca el período (hasta hoy)

  double get neto => ingresos - gastos;
  double get promedioDiario => dias <= 0 ? 0 : gastos / dias;
}

ResumenMov resumir(List<Movimiento> lista, bool enParalelo, RangoFechas rango) {
  var ing = 0.0, gas = 0.0;
  final gEt = <String, double>{};
  final iEt = <String, double>{};
  final sem = List<double>.filled(7, 0);
  final porDia = <DateTime, double>{};
  DateTime? primero;

  for (final m in lista) {
    final v = m.firmado(enParalelo);
    final et = (m.etiqueta == null || m.etiqueta!.isEmpty) ? 'Sin etiqueta' : m.etiqueta!;
    final d = DateTime(m.momento.year, m.momento.month, m.momento.day);
    if (primero == null || d.isBefore(primero)) primero = d;
    if (v >= 0) {
      ing += v;
      iEt[et] = (iEt[et] ?? 0) + v;
    } else {
      gas += -v;
      gEt[et] = (gEt[et] ?? 0) + (-v);
      sem[m.momento.weekday - 1] += -v;
      porDia[d] = (porDia[d] ?? 0) + (-v);
    }
  }

  final n = DateTime.now();
  final hoy = DateTime(n.year, n.month, n.day);
  final desde = rango.desde ?? primero ?? hoy;
  var hasta = rango.hasta ?? hoy;
  if (hasta.isAfter(hoy)) hasta = hoy;
  var dias = hasta.difference(desde).inDays + 1;
  if (dias < 1) dias = 1;

  List<MapEntry<String, double>> ordenar(Map<String, double> m) =>
      m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  return ResumenMov(
    ingresos: ing,
    gastos: gas,
    gastoPorEtiqueta: ordenar(gEt),
    ingresoPorEtiqueta: ordenar(iEt),
    gastoPorDiaSemana: sem,
    gastoPorDia: porDia,
    dias: dias,
  );
}
