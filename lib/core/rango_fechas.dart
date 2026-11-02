// Rangos de fechas reutilizables (hoy, 7 días, este mes, personalizado...).
import 'formato.dart';

enum PresetRango {
  todo('Todo'),
  hoy('Hoy'),
  dias7('7 días'),
  dias30('30 días'),
  mes('Este mes'),
  mesPasado('Mes pasado'),
  anio('Este año'),
  personalizado('Fechas…');

  const PresetRango(this.nombre);
  final String nombre;
}

class RangoFechas {
  const RangoFechas(this.desde, this.hasta);

  static const todo = RangoFechas(null, null);

  final DateTime? desde; // inclusive; null = sin límite
  final DateTime? hasta; // inclusive; null = sin límite

  factory RangoFechas.preset(PresetRango p) {
    final n = DateTime.now();
    final h = DateTime(n.year, n.month, n.day);
    switch (p) {
      case PresetRango.todo:
      case PresetRango.personalizado:
        return todo;
      case PresetRango.hoy:
        return RangoFechas(h, h);
      case PresetRango.dias7:
        return RangoFechas(DateTime(h.year, h.month, h.day - 6), h);
      case PresetRango.dias30:
        return RangoFechas(DateTime(h.year, h.month, h.day - 29), h);
      case PresetRango.mes:
        return RangoFechas(DateTime(h.year, h.month, 1), DateTime(h.year, h.month + 1, 0));
      case PresetRango.mesPasado:
        return RangoFechas(DateTime(h.year, h.month - 1, 1), DateTime(h.year, h.month, 0));
      case PresetRango.anio:
        return RangoFechas(DateTime(h.year, 1, 1), DateTime(h.year, 12, 31));
    }
  }

  bool contiene(DateTime d) {
    final x = DateTime(d.year, d.month, d.day);
    if (desde != null && x.isBefore(desde!)) return false;
    if (hasta != null && x.isAfter(hasta!)) return false;
    return true;
  }

  String get etiqueta {
    if (desde == null && hasta == null) return 'Todo';
    if (desde == hasta) return fechaCorta(desde);
    return '${fechaCorta(desde)} – ${fechaCorta(hasta)}';
  }
}
