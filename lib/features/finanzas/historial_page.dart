// Historial de cierres: tu Excel, una fila por cierre (puede haber varias por día).
import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/widgets/dialogos.dart';
import 'dialogo_etiqueta.dart';
import 'finanzas_controller.dart';

class HistorialPage extends StatelessWidget {
  const HistorialPage({super.key, required this.c});

  final FinanzasController c;

  // Igual que tu fórmula ELEGIR(DIASEM(...)): L M X J V S D
  String _dia(DateTime d) => 'LMXJVSD'[d.weekday - 1];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final asc = c.cierres;
        return Scaffold(
          appBar: AppBar(title: const Text('Historial')),
          body: asc.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Aún no hay cierres. Usa "Guardar cierre" en Finanzas o importa tu Excel desde Ajustes.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: asc.length,
                  itemBuilder: (context, k) {
                    final i = asc.length - 1 - k; // el más reciente primero
                    final x = asc[i];
                    final prev = i > 0 ? asc[i - 1] : null;
                    final delta = prev == null ? null : x.totalBcv - prev.totalBcv;
                    final m = x.momento;
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        shape: const Border(),
                        title: Text('${_dia(m)}  ${fechaCorta(m)}  ${horaCorta(m)}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (x.etiqueta != null)
                              Text(
                                x.etiqueta!,
                                style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                              ),
                            Text(
                              'BCV ${paraMostrar(x.bcv)} · Paralelo ${paraMostrar(x.paralelo)}',
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${paraMostrar(x.totalBcv)} \$',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            if (delta != null)
                              Text(
                                '${conSigno(delta)} \$',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: delta >= 0 ? cs.primary : cs.error,
                                ),
                              ),
                          ],
                        ),
                        children: [
                          for (final e in x.saldos.entries)
                            ListTile(
                              dense: true,
                              title: Text(e.key),
                              trailing: Text(paraMostrar(e.value)),
                            ),
                          ListTile(
                            dense: true,
                            title: const Text('Total a paralelo'),
                            trailing: Text('${paraMostrar(x.totalParalelo)} \$'),
                          ),
                          Wrap(children: [
                            TextButton.icon(
                              icon: const Icon(Icons.label_outline),
                              label: Text(x.etiqueta == null ? 'Poner etiqueta' : 'Cambiar etiqueta'),
                              onPressed: () async {
                                final e = await pedirEtiqueta(
                                  context,
                                  titulo: 'Etiqueta del cierre',
                                  inicial: x.etiqueta,
                                  sugeridas: c.etiquetasSugeridas,
                                );
                                if (e != null) c.editarEtiqueta(x, e);
                              },
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Eliminar'),
                              onPressed: () async {
                                if (await confirmar(
                                    context, '¿Eliminar el cierre del ${fechaCorta(m)} ${horaCorta(m)}?')) {
                                  c.eliminarCierre(x);
                                }
                              },
                            ),
                          ]),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
