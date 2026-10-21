// Configuración global: título y temas. Aquí también irá la navegación
// cuando existan varias pantallas (conversor, cuentas, metas...).
import 'package:flutter/material.dart';

import 'features/inicio/inicio_page.dart';

class BcvApp extends StatelessWidget {
  const BcvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tasa BCV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: const InicioPage(),
    );
  }
}
