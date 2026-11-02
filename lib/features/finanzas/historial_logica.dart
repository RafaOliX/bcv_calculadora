// Lógica pura del historial: agrupar cierres por día, semana, mes o año.
import '../../core/formato.dart';
import 'modelos.dart';

enum Agrupar {
  ninguno('Todo'),
  dia('Día'),
  semana('Semana'),
  mes('Mes'),
  anio('Año');

  const Agrupar(this.nombre);
  final String nombre;
}

const _meses = [
  'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
  'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
];
const _mesesCorto = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];

({String clave, String titulo}) claveGrupo(DateTime d, Agrupar modo) {
  String dos(int n) => n.toString().padLeft(2, '0');
  switch (modo) {
    case Agrupar.dia:
      final letra = 'LMXJVSD'[d.weekday - 1];
      return (clave: '${d.year}-${dos(d.month)}-${dos(d.day)}', titulo: '$letra  ${fechaCorta(d)}');
    case Agrupar.semana:
      final lunes = DateTime(d.year, d.month, d.day - (d.weekday - 1));
      final domingo = DateTime(lunes.year, lunes.month, lunes.day + 6);
      return (
        clave: 'w${lunes.year}-${dos(lunes.month)}-${dos(lunes.day)}',
        titulo: 'Semana del ${lunes.day} ${_mesesCorto[lunes.month - 1]} '
            'al ${domingo.day} ${_mesesCorto[domingo.month - 1]} ${domingo.year}',
      );
    case Agrupar.mes:
      return (clave: 'm${d.year}-${dos(d.month)}', titulo: '${_meses[d.month - 1]} ${d.year}');
    case Agrupar.anio:
      return (clave: 'y${d.year}', titulo: '${d.year}');
    case Agrupar.ninguno:
      return (clave: 'todo', titulo: 'Todos los cierres');
  }
}

class GrupoHistorial {
  GrupoHistorial(this.clave, this.titulo, this.cierres, this.entradas, this.salidas);

  final String clave;
  final String titulo;
  final List<Cierre> cierres; // el más reciente primero
  final double entradas; // suma de variaciones positivas entre cierres
  final double salidas; // suma de variaciones negativas (número negativo)

  double get neto => entradas + salidas;
  Cierre get ultimo => cierres.first;
}

/// `asc` va del más antiguo al más reciente. `deltas` es la variación de cada
/// cierre respecto al anterior (por id). Devuelve los grupos, el más reciente primero.
List<GrupoHistorial> agrupar(List<Cierre> asc, Map<String, double> deltas, Agrupar modo) {
  final mapa = <String, List<Cierre>>{};
  final titulos = <String, String>{};
  for (final x in asc) {
    final k = claveGrupo(x.momento, modo);
    mapa.putIfAbsent(k.clave, () => []).add(x);
    titulos[k.clave] = k.titulo;
  }
  final r = <GrupoHistorial>[];
  for (final e in mapa.entries) {
    var ent = 0.0, sal = 0.0;
    for (final x in e.value) {
      final d = deltas[x.id] ?? 0;
      if (d > 0) {
        ent += d;
      } else {
        sal += d;
      }
    }
    r.add(GrupoHistorial(e.key, titulos[e.key]!, e.value.reversed.toList(), ent, sal));
  }
  return r.reversed.toList();
}
