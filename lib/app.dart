// Configuración global: título y temas (que cambian cuando el usuario elige colores).
import 'package:flutter/material.dart';

import 'core/colores.dart';
import 'core/tema.dart';
import 'features/inicio/inicio_page.dart';

class BcvApp extends StatelessWidget {
  const BcvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ColoresApp.instancia,
      builder: (context, _) => MaterialApp(
        title: 'Tasa BCV',
        debugShowCheckedModeBanner: false,
        theme: construirTema(Brightness.light),
        darkTheme: construirTema(Brightness.dark),
        themeMode: ColoresApp.instancia.modo,
        home: const InicioPage(),
      ),
    );
  }
}
