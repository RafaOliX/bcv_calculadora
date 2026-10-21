// Tarjeta de error con "Ver detalles" (copiable) y, opcionalmente, "Reintentar".
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> mostrarDetalleError(BuildContext context, String texto) {
  var copiado = false;
  return showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('Detalle del error'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              texto,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
          FilledButton.icon(
            icon: Icon(copiado ? Icons.check : Icons.copy, size: 18),
            label: Text(copiado ? '¡Copiado!' : 'Copiar'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: texto));
              setS(() => copiado = true);
            },
          ),
        ],
      ),
    ),
  );
}

class TarjetaError extends StatelessWidget {
  const TarjetaError({super.key, required this.mensaje, this.detalle, this.onReintentar});

  final String mensaje;
  final String? detalle;
  final VoidCallback? onReintentar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: cs.errorContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.error_outline, size: 18, color: cs.onErrorContainer),
              const SizedBox(width: 8),
              Expanded(child: Text(mensaje, style: TextStyle(color: cs.onErrorContainer))),
            ]),
            Wrap(children: [
              if (detalle != null)
                TextButton.icon(
                  icon: const Icon(Icons.bug_report_outlined, size: 18),
                  label: const Text('Ver detalles'),
                  onPressed: () => mostrarDetalleError(context, detalle!),
                ),
              if (onReintentar != null)
                TextButton(onPressed: onReintentar, child: const Text('Reintentar')),
            ]),
          ],
        ),
      ),
    );
  }
}
