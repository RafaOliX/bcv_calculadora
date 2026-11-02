// Guarda las tasas del BCV con su fecha valor (el día en que rigen), para poder
// seguir usando la de hoy aunque el BCV ya haya publicado la de mañana.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errores.dart';
import '../../core/hora_venezuela.dart';
import 'oficial.dart';

class TasaCache {
  static const _clave = 'tasas_hist_v1';

  static String _f(DateTime d) {
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${dos(d.month)}-${dos(d.day)}';
  }

  static DateTime? _d(String? s) {
    if (s == null || s.length < 10) return null;
    final p = s.substring(0, 10).split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]), m = int.tryParse(p[1]), d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  /// Todas las tasas guardadas, de la más antigua a la más reciente (por fecha valor).
  static Future<List<Oficial>> leerTodas() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_clave);
      if (s != null) {
        return (jsonDecode(s) as List<dynamic>)
            .map((e) {
              final j = e as Map<String, dynamic>;
              return Oficial(
                usd: (j['usd'] as num).toDouble(),
                eur: (j['eur'] as num).toDouble(),
                fecha: _d(j['f'] as String?),
              );
            })
            .where((o) => o.fecha != null)
            .toList();
      }
      // Versión anterior de la app: una sola tasa guardada.
      final usd = p.getDouble('usd');
      final eur = p.getDouble('eur');
      if (usd != null && eur != null) {
        return [Oficial(usd: usd, eur: eur, fecha: _d(p.getString('fecha')) ?? hoyVzla())];
      }
      return [];
    } catch (e, st) {
      RegistroErrores.instancia.registrar('Leer caché de tasas', e, st);
      return [];
    }
  }

  static Future<void> guardar(Oficial o) async {
    try {
      final lista = await leerTodas();
      final fecha = o.fecha ?? hoyVzla();
      lista.removeWhere((x) => x.fecha == fecha);
      lista.add(Oficial(usd: o.usd, eur: o.eur, fecha: fecha));
      lista.sort((a, b) => a.fecha!.compareTo(b.fecha!));
      final recorte = lista.length > 20 ? lista.sublist(lista.length - 20) : lista;
      final p = await SharedPreferences.getInstance();
      await p.setString(
        _clave,
        jsonEncode([
          for (final x in recorte) {'f': _f(x.fecha!), 'usd': x.usd, 'eur': x.eur},
        ]),
      );
    } catch (e, st) {
      RegistroErrores.instancia.registrar('Guardar caché de tasas', e, st);
    }
  }
}
