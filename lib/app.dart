// Configuración global: título y temas. Aquí también irá la navegación
// cuando existan más pantallas.
import 'package:flutter/material.dart';

import 'core/tema.dart';
import 'features/inicio/inicio_page.dart';

class BcvApp extends StatelessWidget {
  const BcvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tasa BCV',
      debugShowCheckedModeBanner: false,
      theme: construirTema(Brightness.light),
      darkTheme: construirTema(Brightness.dark),
      home: const InicioPage(),
    );
  }
}
