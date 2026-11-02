// Consulta la tasa de cualquier día pasado (BCV y paralelo). Descarga el
// historial una sola vez por sesión; si un día no tiene dato (fin de semana,
// feriado) usa el más reciente anterior, hasta 10 días atrás.
import 'tasa_servicio.dart';

class TasasHistoricas {
  TasasHistoricas._();
  static final instancia = TasasHistoricas._();

  Map<String, double>? _oficial;
  Map<String, double>? _paralelo;

  static String _clave(DateTime d) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${dos(d.month)}-${dos(d.day)}';
  }

  double? _buscar(Map<String, double>? m, DateTime d) {
    if (m == null) return null;
    for (var i = 0; i < 10; i++) {
      final v = m[_clave(DateTime(d.year, d.month, d.day - i))];
      if (v != null) return v;
    }
    return null;
  }

  Future<({double? bcv, double? paralelo})> deDia(DateTime d) async {
    _oficial ??= await TasaServicio.historial('oficial');
    _paralelo ??= await TasaServicio.historial('paralelo');
    return (bcv: _buscar(_oficial, d), paralelo: _buscar(_paralelo, d));
  }
}
