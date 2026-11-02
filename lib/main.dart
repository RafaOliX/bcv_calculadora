import 'dart:ui';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/colores.dart';
import 'core/errores.dart';
import 'core/hora_venezuela.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Todo error no capturado queda anotado para poder verlo y copiarlo.
  FlutterError.onError = (d) {
    RegistroErrores.instancia.registrar('Flutter', d.exception, d.stack);
    FlutterError.presentError(d);
  };
  PlatformDispatcher.instance.onError = (e, st) {
    RegistroErrores.instancia.registrar('Sin capturar', e, st);
    return true;
  };
  await ColoresApp.instancia.cargar();
  RelojVzla.instancia.iniciar();
  runApp(const BcvApp());
}
