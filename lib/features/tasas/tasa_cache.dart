// Capa de almacenamiento: guarda la última tasa. Es opcional: si el plugin
// falla, la app sigue funcionando sin caché.
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errores.dart';
import 'oficial.dart';

class TasaCache {
  static Future<Oficial?> leer() async {
    try {
      final p = await SharedPreferences.getInstance();
      final usd = p.getDouble('usd');
      final eur = p.getDouble('eur');
      if (usd == null || eur == null) return null;
      return Oficial(usd: usd, eur: eur, fecha: DateTime.tryParse(p.getString('fecha') ?? ''));
    } catch (e, st) {
      RegistroErrores.instancia.registrar('Leer caché de tasas', e, st);
      return null;
    }
  }

  static Future<void> guardar(Oficial o) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble('usd', o.usd);
      await p.setDouble('eur', o.eur);
      if (o.fecha != null) await p.setString('fecha', o.fecha!.toIso8601String());
    } catch (e, st) {
      RegistroErrores.instancia.registrar('Guardar caché de tasas', e, st);
    }
  }
}
