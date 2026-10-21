// Diálogo para poner o cambiar la etiqueta de un cierre.
import 'package:flutter/material.dart';

/// Devuelve null si cancela; '' si lo deja sin etiqueta.
Future<String?> pedirEtiqueta(
  BuildContext context, {
  required String titulo,
  required List<String> sugeridas,
  String? inicial,
  String confirmar = 'Guardar',
}) {
  final c = TextEditingController(text: inicial ?? '');
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: c,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Etiqueta (opcional)',
              hintText: 'Ej. Salida con amigos',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in sugeridas)
                ActionChip(
                  label: Text(s),
                  onPressed: () {
                    c.text = s;
                    c.selection = TextSelection.collapsed(offset: s.length);
                  },
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text(confirmar)),
      ],
    ),
  );
}
