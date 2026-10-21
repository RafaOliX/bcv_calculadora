// Almacenamiento de las finanzas. Hoy: un JSON en el teléfono. Mañana se puede
// cambiar por SQLite sin tocar controlador ni pantallas.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'modelos.dart';

class FinanzasDatos {
  FinanzasDatos({
    List<Cuenta>? cuentas,
    List<Meta>? metas,
    List<Cierre>? cierres,
    this.p2p = 0,
    this.paralelo,
  })  : cuentas = cuentas ?? [],
        metas = metas ?? [],
        cierres = cierres ?? [];

  final List<Cuenta> cuentas;
  final List<Meta> metas;
  final List<Cierre> cierres;
  final double p2p;
  final double? paralelo;
}

class FinanzasRepositorio {
  static const _clave = 'finanzas_v1';

  Future<FinanzasDatos> leer() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_clave);
      if (s == null) return FinanzasDatos();
      final j = jsonDecode(s) as Map<String, dynamic>;
      List<T> lista<T>(String k, T Function(Map<String, dynamic>) f) =>
          ((j[k] as List?) ?? []).map((e) => f(e as Map<String, dynamic>)).toList();
      return FinanzasDatos(
        cuentas: lista('cuentas', Cuenta.fromJson),
        metas: lista('metas', Meta.fromJson),
        cierres: lista('cierres', Cierre.fromJson),
        p2p: (j['p2p'] as num?)?.toDouble() ?? 0,
        paralelo: (j['paralelo'] as num?)?.toDouble(),
      );
    } catch (_) {
      return FinanzasDatos();
    }
  }

  Future<bool> guardar(FinanzasDatos d) async {
    try {
      final p = await SharedPreferences.getInstance();
      return await p.setString(
        _clave,
        jsonEncode({
          'cuentas': d.cuentas.map((e) => e.toJson()).toList(),
          'metas': d.metas.map((e) => e.toJson()).toList(),
          'cierres': d.cierres.map((e) => e.toJson()).toList(),
          'p2p': d.p2p,
          'paralelo': d.paralelo,
        }),
      );
    } catch (_) {
      return false;
    }
  }
}
