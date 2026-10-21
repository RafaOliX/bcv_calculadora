// Pantalla del conversor: solo interfaz.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/formato.dart';
import '../../core/widgets/campo_numerico.dart';
import '../tasas/tasas_repositorio.dart';
import 'conversor_controller.dart';

class ConversorPage extends StatefulWidget {
  const ConversorPage({super.key});

  @override
  State<ConversorPage> createState() => _ConversorPageState();
}

class _ConversorPageState extends State<ConversorPage> {
  late final ConversorController c = ConversorController(TasasRepositorio());

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  void _copiar(String texto) {
    Clipboard.setData(ClipboardData(text: texto));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Copiado'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ));
  }

  List<Widget> _accionesMonto(TextEditingController ctrl) => ctrl.text.isEmpty
      ? const []
      : [
          IconButton(
            tooltip: 'Copiar',
            icon: const Icon(Icons.copy, size: 20),
            onPressed: () => _copiar(ctrl.text),
          ),
          IconButton(
            tooltip: 'Limpiar',
            icon: const Icon(Icons.clear),
            onPressed: c.limpiarMontos,
          ),
        ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final sutil = Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.outline);
        final o = c.oficial;
        final base = c.oficialActual;

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Conversor BCV'),
              actions: [
                IconButton(
                  tooltip: 'Actualizar tasa',
                  onPressed: c.cargando ? null : c.actualizar,
                  icon: c.cargando
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            body: SafeArea(
              child: RefreshIndicator(
                onRefresh: c.actualizar,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    // Tasa oficial (cita sutil)
                    Text('Tasa oficial', style: sutil),
                    Text('USD:  ${o == null ? '—' : paraMostrar(o.usd, dec: 4)}', style: sutil),
                    Text('EUR:  ${o == null ? '—' : paraMostrar(o.eur, dec: 4)}', style: sutil),
                    if (o?.fecha != null)
                      Text(fechaCorta(o!.fecha), style: sutil?.copyWith(fontSize: 12)),

                    if (c.aviso != null) ...[
                      const SizedBox(height: 12),
                      Card(
                        elevation: 0,
                        color: cs.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Icon(Icons.wifi_off, size: 18, color: cs.onErrorContainer),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(c.aviso!,
                                      style: TextStyle(color: cs.onErrorContainer)),
                                ),
                                TextButton(
                                    onPressed: c.actualizar, child: const Text('Reintentar')),
                              ]),
                              if (c.detalle != null)
                                SelectableText(
                                  c.detalle!,
                                  style: TextStyle(color: cs.onErrorContainer, fontSize: 11),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // Campo 1: elegir tasa
                    SegmentedButton<Fuente>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: Fuente.usd, label: Text('USD')),
                        ButtonSegment(value: Fuente.eur, label: Text('EUR')),
                      ],
                      selected: {c.fuente},
                      onSelectionChanged: (s) {
                        HapticFeedback.selectionClick();
                        c.cambiarFuente(s.first);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Tasa: placeholder = oficial; si el usuario escribe, es personalizada
                    CampoNumerico(
                      controller: c.tasaCtrl,
                      label: c.esPersonalizada ? 'Tasa personalizada' : 'Tasa ${c.simbolo}',
                      sufijo: 'Bs',
                      hint: base == null ? null : paraMostrar(base, dec: 4),
                      ayuda: c.esPersonalizada
                          ? 'Usando tu tasa. Toca ✕ para volver a la oficial.'
                          : 'Escribe aquí para usar otra tasa.',
                      estilo: Theme.of(context).textTheme.titleLarge,
                      onChanged: c.tasaEscrita,
                      acciones: c.tasaCtrl.text.isEmpty
                          ? const []
                          : [
                              IconButton(
                                tooltip: 'Usar tasa oficial',
                                icon: const Icon(Icons.clear),
                                onPressed: c.usarOficial,
                              ),
                            ],
                    ),
                    const SizedBox(height: 20),

                    // Campo 2: Bs
                    CampoNumerico(
                      controller: c.bsCtrl,
                      label: 'Monto en Bs',
                      sufijo: 'Bs',
                      onChanged: (_) => c.montoEscrito(esBs: true),
                      acciones: _accionesMonto(c.bsCtrl),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Icon(Icons.swap_vert, color: cs.outline),
                    ),

                    // Campo 3: USD / EUR
                    CampoNumerico(
                      controller: c.divisaCtrl,
                      label: 'Monto en ${c.simbolo}',
                      sufijo: c.simbolo,
                      onChanged: (_) => c.montoEscrito(esBs: false),
                      acciones: _accionesMonto(c.divisaCtrl),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
