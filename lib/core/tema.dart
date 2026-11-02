// Tema y colores. El mismo color siempre significa lo mismo en toda la app,
// y el usuario puede cambiarlos desde Ajustes > Colores y apariencia.
import 'package:flutter/material.dart';

import 'colores.dart';

class Paleta {
  static Color get usd => ColoresApp.instancia.de(ClaveColor.usd);
  static Color get eur => ColoresApp.instancia.de(ClaveColor.eur);
  static Color get bs => ColoresApp.instancia.de(ClaveColor.bs);
  static Color get usdt => ColoresApp.instancia.de(ClaveColor.usdt);
  static Color get paralelo => ColoresApp.instancia.de(ClaveColor.paralelo);
  static Color get sube => ColoresApp.instancia.de(ClaveColor.sube);
  static Color get baja => ColoresApp.instancia.de(ClaveColor.baja);
}

ThemeData construirTema(Brightness brillo) {
  final cs = ColorScheme.fromSeed(seedColor: ColoresApp.instancia.principal, brightness: brillo);
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
