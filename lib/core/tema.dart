// Tema y colores. El mismo color siempre significa lo mismo en toda la app.
import 'package:flutter/material.dart';

class Paleta {
  static const usd = Color(0xFF2E9E6B); // verde: dólares
  static const eur = Color(0xFF3F6FE0); // azul: euros
  static const bs = Color(0xFFE8A33D); // ámbar: bolívares
  static const usdt = Color(0xFF1FA39A); // turquesa: USDT
  static const paralelo = Color(0xFF8E5CD9); // violeta: tasa paralelo
  static const sube = Color(0xFF2E9E6B);
  static const baja = Color(0xFFE0524D);
}

ThemeData construirTema(Brightness brillo) {
  final cs = ColorScheme.fromSeed(seedColor: const Color(0xFF0F8F7E), brightness: brillo);
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cs.onSurface),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      indicatorColor: cs.primaryContainer,
    ),
  );
}
