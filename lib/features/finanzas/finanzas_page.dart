// Pantalla principal de finanzas.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/errores.dart';
import '../../core/formato.dart';
import '../../core/widgets/campo_numerico.dart';
import '../../core/widgets/dialogos.dart';
import '../../core/widgets/tarjeta_error.dart';
import '../tasas/tasas_repositorio.dart';
import 'finanzas_controller.dart';
import 'finanzas_repositorio.dart';
import 'historial_page.dart';
import 'modelos.dart';

class FinanzasPage extends StatefulWidget {
  const FinanzasPage({super.key});

  @override
  State<FinanzasPage> createState() => _FinanzasPageState();
}

class _FinanzasPageState extends State<FinanzasPage> {
  late final FinanzasController c =
      FinanzasController(FinanzasRepositorio(), TasasRepositorio());

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  String _m(double? v) => v == null ? '—' : paraMostrar(v);

  void _aviso(String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto), behavior: SnackBarBehavior.floating));
  }

  // ---- Diálogos -----------------------------------------------------------
  Future<(String, Moneda)?> _pedirCuenta() {
    final nombre = TextEditingController();
    var moneda = Moneda.bs;
    return showDialog<(String, Moneda)>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Nueva cuenta'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nombre,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nombre (ej. Provincial)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<Moneda>(
              showSelectedIcon: false,
              segments: [
                for (final m in Moneda.values) ButtonSegment(value: m, label: Text(m.etiqueta)),
              ],
              selected: {moneda},
              onSelectionChanged: (s) => setS(() => moneda = s.first),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                final n = nombre.text.trim();
                if (n.isEmpty) return;
                Navigator.pop(ctx, (n, moneda));
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<(String, double)?> _pedirMeta() {
    final nombre = TextEditingController();
    final monto = TextEditingController();
    return showDialog<(String, double)>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva meta'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: nombre,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nombre (ej. Diciembre)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          CampoNumerico(
            controller: monto,
            label: 'Monto objetivo',
            sufijo: 'USD',
            estilo: Theme.of(ctx).textTheme.titleLarge,
            onChanged: (_) {},
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final n = nombre.text.trim();
              final v = parsear(monto.text);
              if (n.isEmpty || v == null || v <= 0) return;
              Navigator.pop(ctx, (n, v));
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  // ---- Secciones ----------------------------------------------------------
  Widget _totales(ColorScheme cs, TextTheme tt) {
    final on = cs.onPrimaryContainer;
    return Card(
      elevation: 0,
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total en dólares (BCV)', style: TextStyle(color: on)),
            SelectableText(
              '${_m(c.totalBcv)} \$',
              style: tt.headlineLarge?.copyWith(fontWeight: FontWeight.bold, color: on),
            ),
            const SizedBox(height: 8),
            Text('A tasa paralelo: ${_m(c.totalParalelo)} \$', style: TextStyle(color: on)),
            Text(
              'Dólares ${_m(c.dolares)} \$  ·  Bolívares ${_m(c.bolivares)} Bs',
              style: tt.bodySmall?.copyWith(color: on),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tasas() {
    return Card(
      elevation: 0,
      child: Column(children: [
        ListTile(
          dense: true,
          title: const Text('Tasa BCV'),
          subtitle: c.fechaBcv == null ? null : Text(fechaCorta(c.fechaBcv)),
          trailing: Text(c.bcv == null ? '—' : '${paraMostrar(c.bcv!, dec: 4)} Bs'),
        ),
        ListTile(
          dense: true,
          title: const Text('Tasa paralelo'),
          subtitle: const Text('Toca para escribirla'),
          trailing: Text(c.paralelo == null ? '—' : '${paraMostrar(c.paralelo!, dec: 4)} Bs'),
          onTap: () async {
            final v = await pedirNumero(context,
                titulo: 'Tasa paralelo', sufijo: 'Bs', inicial: c.paralelo);
            if (v != null && v > 0) c.setParalelo(v);
          },
        ),
        ListTile(
          dense: true,
          title: const Text('P2P pendiente'),
          subtitle: const Text('Se resta del total'),
          trailing: Text('${paraMostrar(c.p2p)} \$'),
          onTap: () async {
            final v = await pedirNumero(context,
                titulo: 'P2P pendiente', sufijo: 'USD', inicial: c.p2p);
            if (v != null && v >= 0) c.setP2p(v);
          },
        ),
      ]),
    );
  }

  IconData _icono(Moneda m) => switch (m) {
        Moneda.bs => Icons.account_balance,
        Moneda.usd => Icons.attach_money,
        Moneda.usdt => Icons.currency_bitcoin,
      };

  Widget _cuentas(ColorScheme cs) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Cuentas', style: Theme.of(context).textTheme.titleMedium)),
        IconButton(
          tooltip: 'Agregar cuenta',
          icon: const Icon(Icons.add),
          onPressed: () async {
            final r = await _pedirCuenta();
            if (r != null) c.agregarCuenta(r.$1, r.$2);
          },
        ),
      ]),
      if (c.cuentas.isEmpty)
        Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              const Text('Aún no tienes cuentas. Agrega las tuyas o empieza con un ejemplo.'),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: c.cargarEjemplo,
                child: const Text('Crear cuentas de ejemplo'),
              ),
            ]),
          ),
        )
      else
        for (final cu in c.cuentas)
          Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.secondaryContainer,
                child: Icon(_icono(cu.moneda), color: cs.onSecondaryContainer),
              ),
              title: Text(cu.nombre),
              subtitle: cu.moneda.esDolar ? null : Text('≈ ${_m(c.valorEnDolares(cu))} \$ (BCV)'),
              trailing: Text(
                '${paraMostrar(cu.saldo)} ${cu.moneda.etiqueta}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              onTap: () async {
                final v = await pedirNumero(context,
                    titulo: cu.nombre,
                    etiqueta: 'Saldo',
                    sufijo: cu.moneda.etiqueta,
                    inicial: cu.saldo);
                if (v != null) c.editarSaldo(cu, v);
              },
              onLongPress: () async {
                if (await confirmar(context, '¿Eliminar la cuenta "${cu.nombre}"?')) {
                  c.eliminarCuenta(cu);
                }
              },
            ),
          ),
    ]);
  }

  Widget _metas() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Metas', style: Theme.of(context).textTheme.titleMedium)),
        IconButton(
          tooltip: 'Agregar meta',
          icon: const Icon(Icons.add),
          onPressed: () async {
            final r = await _pedirMeta();
            if (r != null) c.agregarMeta(r.$1, r.$2);
          },
        ),
      ]),
      if (c.metas.isEmpty)
        Text('Sin metas todavía.', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      for (final m in c.metas) _meta(m),
    ]);
  }

  Widget _meta(Meta m) {
    final tb = c.totalBcv, tp = c.totalParalelo;
    final avance = tb == null ? 0.0 : (tb / m.monto).clamp(0.0, 1.0);
    String falta(double? t) => t == null ? '—' : paraMostrar((m.monto - t).clamp(0, double.infinity));
    final lograda = tb != null && tb >= m.monto;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text('${m.nombre}  ·  ${paraMostrar(m.monto)} \$'),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LinearProgressIndicator(value: avance, minHeight: 8, borderRadius: BorderRadius.circular(8)),
            const SizedBox(height: 6),
            Text(lograda
                ? '¡Meta lograda!'
                : 'Falta ${falta(tb)} \$ (BCV)  ·  ${falta(tp)} \$ (paralelo)'),
          ]),
        ),
        onLongPress: () async {
          if (await confirmar(context, '¿Eliminar la meta "${m.nombre}"?')) c.eliminarMeta(m);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Mis finanzas'),
            actions: [
              IconButton(
                tooltip: 'Historial',
                icon: const Icon(Icons.history),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => HistorialPage(c: c)),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: c.cargando
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      if (c.sinGuardado)
                        TarjetaError(
                          mensaje:
                              'No se pudo guardar en el teléfono. Los cambios se perderán al cerrar la app.',
                          detalle: RegistroErrores.instancia.texto,
                        ),
                      _totales(cs, tt),
                      const SizedBox(height: 12),
                      _tasas(),
                      const SizedBox(height: 16),
                      _cuentas(cs),
                      const SizedBox(height: 16),
                      _metas(),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar cierre de hoy'),
                        onPressed: () {
                          final err = c.guardarCierre();
                          HapticFeedback.lightImpact();
                          _aviso(err ?? 'Cierre de hoy guardado');
                        },
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
