// Pantalla principal de finanzas.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/errores.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../core/widgets/visuales.dart';
import '../../core/widgets/campo_numerico.dart';
import '../../core/widgets/dialogos.dart';
import '../../core/widgets/tarjeta_error.dart';
import '../tasas/tasas_repositorio.dart';
import 'finanzas_controller.dart';
import 'finanzas_repositorio.dart';
import 'ajustes_page.dart';
import 'dialogo_etiqueta.dart';
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
  Color _colorMoneda(Moneda m) => switch (m) {
        Moneda.bs => Paleta.bs,
        Moneda.usd => Paleta.usd,
        Moneda.usdt => Paleta.usdt,
      };

  IconData _icono(Moneda m) => switch (m) {
        Moneda.bs => Icons.payments_outlined,
        Moneda.usd => Icons.attach_money,
        Moneda.usdt => Icons.currency_bitcoin,
      };

  Widget _pildora(IconData icono, String texto) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icono, size: 15, color: Colors.white),
          const SizedBox(width: 6),
          Text(texto,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _mini(String titulo, String valor) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(valor,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
        ],
      );

  Widget _totales(ColorScheme cs, TextTheme tt) {
    final brecha = (c.bcv != null && c.paralelo != null) ? c.paralelo! / c.bcv! - 1 : null;
    return Aparecer(
      child: TarjetaDegradado(
        colores: const [Color(0xFF0B7A6B), Color(0xFF1B5FB5)],
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.account_balance_wallet, color: Colors.white70, size: 18),
            SizedBox(width: 8),
            Text('Total en dólares · BCV', style: TextStyle(color: Colors.white70)),
          ]),
          const SizedBox(height: 6),
          NumeroAnimado(
            valor: c.totalBcv,
            formato: (v) => '${paraMostrar(v)} \$',
            estilo: const TextStyle(
                color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pildora(Icons.trending_up, '${_m(c.totalParalelo)} \$ paralelo'),
            if (brecha != null)
              _pildora(Icons.compare_arrows, 'Brecha ${conSigno(brecha * 100)}%'),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: _mini('Dólares', '${_m(c.dolares)} \$')),
            Expanded(child: _mini('Bolívares', '${_m(c.bolivares)} Bs')),
          ]),
        ]),
      ),
    );
  }

  Widget _tarjetaTasa({
    required IconData icono,
    required Color color,
    required String titulo,
    required String valor,
    required String pie,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icono, size: 18, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600))),
                if (onTap != null) Icon(Icons.edit_outlined, size: 16, color: color),
              ]),
              const SizedBox(height: 10),
              Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              Text(pie,
                  style: TextStyle(
                      fontSize: 12, color: Theme.of(context).colorScheme.outline)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tasas() {
    final cs = Theme.of(context).colorScheme;
    return Aparecer(
      retraso: 100,
      child: Row(children: [
        _tarjetaTasa(
          icono: Icons.account_balance,
          color: cs.primary,
          titulo: 'BCV',
          valor: c.bcv == null ? '—' : paraMostrar(c.bcv!),
          pie: c.fechaBcv == null ? 'Bs por dólar' : fechaCorta(c.fechaBcv),
        ),
        const SizedBox(width: 8),
        _tarjetaTasa(
          icono: Icons.trending_up,
          color: Paleta.paralelo,
          titulo: 'Paralelo',
          valor: c.paralelo == null ? '—' : paraMostrar(c.paralelo!),
          pie: 'Toca para editar',
          onTap: () async {
            final v = await pedirNumero(context,
                titulo: 'Tasa paralelo', sufijo: 'Bs', inicial: c.paralelo);
            if (v != null && v > 0) c.setParalelo(v);
          },
        ),
      ]),
    );
  }

  Widget _encabezado(String titulo, IconData icono, String tooltip, VoidCallback onAdd) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icono, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(titulo,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ),
        IconButton.filledTonal(tooltip: tooltip, icon: const Icon(Icons.add), onPressed: onAdd),
      ]),
    );
  }

  Widget _cuentas(ColorScheme cs) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _encabezado('Cuentas', Icons.account_balance_wallet_outlined, 'Agregar cuenta', () async {
        final r = await _pedirCuenta();
        if (r != null) c.agregarCuenta(r.$1, r.$2);
      }),
      if (c.cuentas.isEmpty)
        Aparecer(
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Icon(Icons.savings_outlined, size: 48, color: cs.primary),
                const SizedBox(height: 8),
                const Text(
                  'Aún no tienes cuentas.\nAgrega las tuyas o empieza con un ejemplo.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: c.cargarEjemplo,
                  child: const Text('Crear cuentas de ejemplo'),
                ),
              ]),
            ),
          ),
        )
      else
        for (var i = 0; i < c.cuentas.length; i++) _cuenta(c.cuentas[i], i),
    ]);
  }

  Widget _cuenta(Cuenta cu, int i) {
    final color = _colorMoneda(cu.moneda);
    return Aparecer(
      retraso: 60 * i,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.18),
            child: Icon(_icono(cu.moneda), color: color),
          ),
          title: Text(cu.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Insignia(texto: cu.moneda.etiqueta, color: color),
                if (!cu.moneda.esDolar) Text('≈ ${_m(c.valorEnDolares(cu))} \$'),
              ],
            ),
          ),
          trailing: Text(
            '${paraMostrar(cu.saldo)} ${cu.moneda.etiqueta}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
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
    );
  }

  Widget _metas() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _encabezado('Metas', Icons.flag_outlined, 'Agregar meta', () async {
        final r = await _pedirMeta();
        if (r != null) c.agregarMeta(r.$1, r.$2);
      }),
      if (c.metas.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Sin metas todavía. Crea una para ver tu progreso.',
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      for (var i = 0; i < c.metas.length; i++) _meta(c.metas[i], i),
    ]);
  }

  Widget _meta(Meta m, int i) {
    final cs = Theme.of(context).colorScheme;
    final tb = c.totalBcv, tp = c.totalParalelo;
    final avance = tb == null ? 0.0 : (tb / m.monto).clamp(0.0, 1.0);
    final lograda = tb != null && tb >= m.monto;
    final color = lograda ? Paleta.usd : cs.primary;
    String falta(double? t) =>
        t == null ? '—' : paraMostrar((m.monto - t).clamp(0, double.infinity));
    return Aparecer(
      retraso: 60 * i,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onLongPress: () async {
            if (await confirmar(context, '¿Eliminar la meta "${m.nombre}"?')) c.eliminarMeta(m);
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(m.nombre,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                Insignia(
                  texto: lograda ? '¡Lograda!' : '${(avance * 100).round()}%',
                  color: color,
                  icono: lograda ? Icons.emoji_events : Icons.flag,
                ),
              ]),
              Text('Objetivo ${paraMostrar(m.monto)} \$',
                  style: TextStyle(fontSize: 12, color: cs.outline)),
              const SizedBox(height: 10),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: avance),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(8),
                  color: color,
                ),
              ),
              const SizedBox(height: 8),
              Text(lograda
                  ? 'Meta alcanzada'
                  : 'Falta ${falta(tb)} \$ (BCV)  ·  ${falta(tp)} \$ (paralelo)'),
            ]),
          ),
        ),
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
                tooltip: 'Ajustes',
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AjustesPage(c: c)),
                ),
              ),
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
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        icon: const Icon(Icons.save),
                        label: const Text('Guardar cierre'),
                        onPressed: () async {
                          final e = await pedirEtiqueta(
                            context,
                            titulo: 'Guardar cierre',
                            sugeridas: c.etiquetasSugeridas,
                          );
                          if (e == null || !mounted) return;
                          final err = c.guardarCierre(etiqueta: e);
                          HapticFeedback.lightImpact();
                          _aviso(err ?? 'Cierre guardado');
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
