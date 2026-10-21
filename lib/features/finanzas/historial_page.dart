// Historial de cierres: tu Excel, una fila por día.
import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/widgets/dialogos.dart';
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
        final lista = c.cierres.reversed.toList();
        return Scaffold(
          appBar: AppBar(title: const Text('Historial')),
          body: lista.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Aún no hay cierres. Usa "Guardar cierre de hoy" en Finanzas.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: lista.length,
                  itemBuilder: (context, i) {
                    final x = lista[i];
                    final f = x.fechaDate;
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        shape: const Border(),
                        title: Text('${_dia(f)}  ${fechaCorta(f)}'),
                        subtitle: Text(
                          'BCV ${paraMostrar(x.bcv, dec: 2)} · Paralelo ${paraMostrar(x.paralelo, dec: 2)}',
                        ),
                        trailing: Text(
                          '${paraMostrar(x.totalBcv)} \$',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                            title: const Text('P2P pendiente'),
                            trailing: Text('${paraMostrar(x.p2p)} \$'),
                          ),
                          ListTile(
                            dense: true,
                            title: const Text('Total a paralelo'),
                            trailing: Text('${paraMostrar(x.totalParalelo)} \$'),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Eliminar este cierre'),
                            onPressed: () async {
                              if (await confirmar(context, '¿Eliminar el cierre del ${fechaCorta(f)}?')) {
                                c.eliminarCierre(x);
                              }
                            },
                          ),
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
