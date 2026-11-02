// Colores personalizables y modo claro/oscuro. Se guardan en el teléfono.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'errores.dart';

enum ClaveColor {
  principal('Color principal', Color(0xFF0F8F7E)),
  usd('Dólares (USD)', Color(0xFF2E9E6B)),
  eur('Euros (EUR)', Color(0xFF3F6FE0)),
  bs('Bolívares (Bs)', Color(0xFFE8A33D)),
  usdt('USDT', Color(0xFF1FA39A)),
  paralelo('Tasa paralelo', Color(0xFF8E5CD9)),
  sube('Sube / ganancia', Color(0xFF2E9E6B)),
  baja('Baja / gasto', Color(0xFFE0524D));

  const ClaveColor(this.nombre, this.porDefecto);
  final String nombre;
  final Color porDefecto;
}

class ColoresApp extends ChangeNotifier {
  ColoresApp._();
  static final instancia = ColoresApp._();

  static const _clave = 'colores_v1';

  final Map<ClaveColor, Color> _c = {for (final k in ClaveColor.values) k: k.porDefecto};
  ThemeMode modo = ThemeMode.system;

  Color de(ClaveColor k) => _c[k]!;
  Color get principal => de(ClaveColor.principal);

  Future<void> cargar() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_clave);
      if (s == null) return;
      final j = jsonDecode(s) as Map<String, dynamic>;
      for (final k in ClaveColor.values) {
        final v = j[k.name];
        if (v is int) _c[k] = Color(v);
      }
      modo = switch (j['modo']) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
    } catch (e, st) {
      RegistroErrores.instancia.registrar('Leer colores', e, st);
    }
  }

  Future<void> _guardar() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        _clave,
        jsonEncode({
          for (final k in ClaveColor.values) k.name: _c[k]!.toARGB32(),
          'modo': modo.name,
        }),
      );
    } catch (e, st) {
      RegistroErrores.instancia.registrar('Guardar colores', e, st);
    }
  }

  void elegir(ClaveColor k, Color color) {
    _c[k] = color;
    notifyListeners();
    _guardar();
  }

  void cambiarModo(ThemeMode m) {
    modo = m;
    notifyListeners();
    _guardar();
  }

  void restablecer() {
    for (final k in ClaveColor.values) {
      _c[k] = k.porDefecto;
    }
    notifyListeners();
    _guardar();
  }
}
