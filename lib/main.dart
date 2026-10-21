import 'dart:ui';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/errores.dart';

void main() {
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
  runApp(const BcvApp());
}
