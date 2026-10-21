// Almacenamiento de las finanzas. Hoy: un JSON en el teléfono. Mañana se puede
// cambiar por SQLite sin tocar controlador ni pantallas.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/errores.dart';
import 'modelos.dart';

class FinanzasDatos {
  FinanzasDatos({
    List<Cuenta>? cuentas,
    List<Meta>? metas,
    List<Cierre>? cierres,
    this.paralelo,
  })  : cuentas = cuentas ?? [],
        metas = metas ?? [],
        cierres = cierres ?? [];

  final List<Cuenta> cuentas;
  final List<Meta> metas;
  final List<Cierre> cierres;
  final double? paralelo;
}

class FinanzasRepositorio {
  static const _clave = 'finanzas_v1';

  /// Todo el estado como texto JSON (sirve para guardar y para copias de seguridad).
  static String codificar(FinanzasDatos d) => jsonEncode({
        'cuentas': d.cuentas.map((e) => e.toJson()).toList(),
        'metas': d.metas.map((e) => e.toJson()).toList(),
        'cierres': d.cierres.map((e) => e.toJson()).toList(),
        'paralelo': d.paralelo,
      });

  /// Lanza una excepción si el texto no es válido.
  static FinanzasDatos decodificar(String s) {
    final j = jsonDecode(s) as Map<String, dynamic>;
    List<T> lista<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List?) ?? []).map((e) => f(e as Map<String, dynamic>)).toList();
    return FinanzasDatos(
      cuentas: lista('cuentas', Cuenta.fromJson),
      metas: lista('metas', Meta.fromJson),
      cierres: lista('cierres', Cierre.fromJson),
      paralelo: (j['paralelo'] as num?)?.toDouble(),
    );
  }

  Future<FinanzasDatos> leer() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_clave);
      if (s == null) return FinanzasDatos();
      return decodificar(s);
    } catch (e, st) {
      RegistroErrores.instancia.registrar('Leer finanzas', e, st);
      return FinanzasDatos();
    }
  }

  Future<bool> guardar(FinanzasDatos d) async {
    try {
      final p = await SharedPreferences.getInstance();
      final ok = await p.setString(_clave, codificar(d));
      if (!ok) RegistroErrores.instancia.registrar('Guardar finanzas', 'setString devolvió false');
      return ok;
    } catch (e, st) {
      RegistroErrores.instancia.registrar('Guardar finanzas', e, st);
      return false;
    }
  }
}
