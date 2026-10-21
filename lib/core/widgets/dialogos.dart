// Diálogos reutilizables.
import 'package:flutter/material.dart';

import '../formato.dart';
import 'campo_numerico.dart';

/// Pide un número. Devuelve null si el usuario cancela o lo deja vacío.
Future<double?> pedirNumero(
  BuildContext context, {
  required String titulo,
  String etiqueta = 'Monto',
  String? sufijo,
  double? inicial,
}) {
  final c = TextEditingController(text: inicial == null ? '' : paraInput(inicial));
  return showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: CampoNumerico(
        controller: c,
        label: etiqueta,
        sufijo: sufijo,
        autoenfocar: true,
        estilo: Theme.of(ctx).textTheme.titleLarge,
        onChanged: (_) {},
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, parsear(c.text)),
          child: const Text('Aceptar'),
        ),
      ],
    ),
  );
}

Future<bool> confirmar(BuildContext context, String mensaje) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      content: Text(mensaje),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
      ],
    ),
  );
  return r ?? false;
}
