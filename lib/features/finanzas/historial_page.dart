// Historial: agrupa por día/semana/mes/año, filtra por etiquetas y compara cierres.
import 'package:flutter/material.dart';

import '../../core/colores.dart';
import '../../core/formato.dart';
import '../../core/rango_fechas.dart';
import '../../core/tema.dart';
import '../../core/widgets/dialogos.dart';
import '../../core/widgets/selector_rango.dart';
import '../../core/widgets/visuales.dart';
import 'comparacion.dart';
import 'dialogo_etiqueta.dart';
import 'finanzas_controller.dart';
import 'historial_logica.dart';
import 'modelos.dart';

class _Item {
  _Item.controles() : g = null, x = null, delta = null, tipo = 0;
  _Item.grupo(this.g) : x = null, delta = null, tipo = 1;
  _Item.cierre(this.x, this.delta) : g = null, tipo = 2;
  _Item.vacio() : g = null, x = null, delta = null, tipo = 3;

  final int tipo;
  final GrupoHistorial? g;
  final Cierre? x;
  final double? delta;
}

class HistorialPage extends StatefulWidget {
  const HistorialPage({super.key, required this.c});

  final FinanzasController c;

  @override
  State<HistorialPage> createState() => _HistorialPageState();
}

class _HistorialPageState extends State<HistorialPage> {
  FinanzasController get c => widget.c;

  static const _sin = '__sin_etiqueta__';

  Agrupar modo = Agrupar.mes;
  final Set<String> filtro = {};
  final Set<String> colapsados = {};
  final List<Cierre> seleccion = [];
  bool comparando = false;
  PresetRango preset = PresetRango.todo;
  RangoFechas rango = RangoFechas.todo;

  String _dia(DateTime d) => 'LMXJVSD'[d.weekday - 1];

  String _claveEtiqueta(Cierre x) {
    final e = x.etiqueta;
    return (e == null || e.isEmpty) ? _sin : e;
  }

  // ---- Comparar -----------------------------------------------------------
  void _alternarModoComparar([Cierre? primero]) {
    setState(() {
      comparando = primero != null ? true : !comparando;
      seleccion.clear();
      if (primero != null) seleccion.add(primero);
    });
  }

  void _alternar(Cierre x) {
    setState(() {
      if (seleccion.contains(x)) {
        seleccion.remove(x);
      } else {
        if (seleccion.length >= 2) seleccion.removeAt(0);
        seleccion.add(x);
      }
    });
  }

  void _comparar() {
    final par = [...seleccion]..sort((x, y) => x.momento.compareTo(y.momento));
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => HojaComparacion(a: par[0], b: par[1]),
    );
  }

  // ---- Piezas -------------------------------------------------------------
  Widget _controles(
    ColorScheme cs,
    List<Cierre> visibles,
    double ent,
    double sal,
    List<String> etiquetas,
    bool hayVacias,
  ) {
    final tt = Theme.of(context).textTheme;
    final neto = ent + sal;
    final suave = TextStyle(color: cs.outline, fontSize: 12);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.insights, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  filtro.isEmpty ? 'Resumen' : 'Resumen filtrado',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text('${visibles.length} cierres', style: TextStyle(color: cs.outline)),
            ]),
            const SizedBox(height: 8),
            Sparkline(valores: [for (final x in visibles) x.totalBcv], color: cs.primary),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              Insignia(
                texto: 'Neto ${conSigno(neto)} \$',
                color: neto >= 0 ? Paleta.sube : Paleta.baja,
                icono: neto >= 0 ? Icons.trending_up : Icons.trending_down,
              ),
              Insignia(
                texto: 'Entradas ${conSigno(ent)} \$',
                color: Paleta.sube,
                icono: Icons.add_circle_outline,
              ),
              Insignia(
                texto: 'Salidas ${conSigno(sal)} \$',
                color: Paleta.baja,
                icono: Icons.remove_circle_outline,
              ),
            ]),
            const SizedBox(height: 6),
            Text('Las entradas y salidas salen de la variación entre cierres.', style: suave),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      Text('Rango de fechas', style: tt.labelLarge),
      const SizedBox(height: 6),
      SelectorRango(
        preset: preset,
        rango: rango,
        onCambio: (p, r) => setState(() {
          preset = p;
          rango = r;
        }),
      ),
      const SizedBox(height: 10),
      Text('Agrupar por', style: tt.labelLarge),
      const SizedBox(height: 6),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final a in Agrupar.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(a.nombre),
                selected: modo == a,
                onSelected: (_) => setState(() => modo = a),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 10),
      Text('Filtrar por etiqueta', style: tt.labelLarge),
      const SizedBox(height: 6),
      if (etiquetas.isEmpty)
        Text('Aún no hay etiquetas. Ponlas al guardar un cierre para poder filtrar.', style: suave)
      else
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('Todas'),
                selected: filtro.isEmpty,
                onSelected: (_) => setState(filtro.clear),
              ),
            ),
            for (final e in [...etiquetas, if (hayVacias) _sin])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(e == _sin ? 'Sin etiqueta' : e),
                  selected: filtro.contains(e),
                  onSelected: (v) => setState(() {
                    if (v) {
                      filtro.add(e);
                    } else {
                      filtro.remove(e);
                    }
                  }),
                ),
              ),
          ]),
        ),
      const SizedBox(height: 4),
    ]);
  }

  Widget _cabecera(GrupoHistorial g, ColorScheme cs) {
    final colapsado = colapsados.contains(g.clave);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() {
        if (colapsado) {
          colapsados.remove(g.clave);
        } else {
          colapsados.add(g.clave);
        }
      }),
      child: Container(
        margin: const EdgeInsets.only(top: 14, bottom: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.secondaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(g.titulo,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            Text('${paraMostrar(g.ultimo.totalBcv)} \$',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Icon(colapsado ? Icons.expand_more : Icons.expand_less),
          ]),
          Text(
            '${g.cierres.length} ${g.cierres.length == 1 ? 'cierre' : 'cierres'} · total al último cierre',
            style: TextStyle(fontSize: 12, color: cs.outline),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            Insignia(
              texto: 'Neto ${conSigno(g.neto)} \$',
              color: g.neto >= 0 ? Paleta.sube : Paleta.baja,
              icono: g.neto >= 0 ? Icons.trending_up : Icons.trending_down,
            ),
            if (g.entradas > 0)
              Insignia(
                texto: 'Entradas ${conSigno(g.entradas)} \$',
                color: Paleta.sube,
                icono: Icons.add_circle_outline,
              ),
            if (g.salidas < 0)
              Insignia(
                texto: 'Salidas ${conSigno(g.salidas)} \$',
                color: Paleta.baja,
                icono: Icons.remove_circle_outline,
              ),
          ]),
        ]),
      ),
    );
  }

  Widget _tarjetaCierre(Cierre x, double? delta, ColorScheme cs) {
    final m = x.momento;
    final deltaW = delta == null
        ? null
        : Insignia(
            texto: '${conSigno(delta)} \$',
            color: delta >= 0 ? Paleta.sube : Paleta.baja,
            icono: delta >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
          );

    if (comparando) {
      final sel = seleccion.contains(x);
      return Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 6),
        color: sel ? cs.primaryContainer : null,
        child: ListTile(
          leading: Icon(
            sel ? Icons.check_circle : Icons.radio_button_unchecked,
            color: sel ? cs.primary : cs.outline,
          ),
          title: Text('${_dia(m)}  ${fechaCorta(m)}  ${horaCorta(m)}'),
          subtitle: x.etiqueta == null ? null : Text(x.etiqueta!),
          trailing: Text('${paraMostrar(x.totalBcv)} \$',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          onTap: () => _alternar(x),
        ),
      );
    }

    return GestureDetector(
      onLongPress: () => _alternarModoComparar(x),
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 6),
        child: ExpansionTile(
          shape: const Border(),
          leading: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Text(_dia(m),
                style: TextStyle(fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
          ),
          title: Text('${fechaCorta(m)}  ${horaCorta(m)}'),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (x.etiqueta != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Insignia(texto: x.etiqueta!, color: cs.primary, icono: Icons.label),
              ),
            Text('BCV ${paraMostrar(x.bcv)} · Paralelo ${paraMostrar(x.paralelo)}'),
          ]),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${paraMostrar(x.totalBcv)} \$',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              if (deltaW != null) deltaW,
            ],
          ),
          children: [
            for (final e in x.saldos.entries)
              ListTile(dense: true, title: Text(e.key), trailing: Text(paraMostrar(e.value))),
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
                icon: const Icon(Icons.compare_arrows),
                label: const Text('Comparar'),
                onPressed: () => _alternarModoComparar(x),
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
      ),
    );
  }

  // ---- Pantalla -----------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([c, ColoresApp.instancia]),
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final asc = c.cierres;

        // Variación de cada cierre respecto al anterior (sobre todo el historial).
        final deltas = <String, double>{
          for (var i = 1; i < asc.length; i++) asc[i].id: asc[i].totalBcv - asc[i - 1].totalBcv,
        };
        final etiquetas = <String>[];
        for (final x in asc.reversed) {
          final e = x.etiqueta;
          if (e != null && e.isNotEmpty && !etiquetas.contains(e)) etiquetas.add(e);
        }
        final hayVacias = asc.any((x) => _claveEtiqueta(x) == _sin);
        filtro.removeWhere((e) => e != _sin && !etiquetas.contains(e));

        final visibles = asc
            .where((x) =>
                rango.contiene(x.momento) &&
                (filtro.isEmpty || filtro.contains(_claveEtiqueta(x))))
            .toList();
        var ent = 0.0, sal = 0.0;
        for (final x in visibles) {
          final d = deltas[x.id] ?? 0;
          if (d > 0) {
            ent += d;
          } else {
            sal += d;
          }
        }

        final items = <_Item>[_Item.controles()];
        if (visibles.isEmpty) {
          items.add(_Item.vacio());
        } else {
          for (final g in agrupar(visibles, deltas, modo)) {
            if (modo != Agrupar.ninguno) items.add(_Item.grupo(g));
            if (!colapsados.contains(g.clave)) {
              for (final x in g.cierres) {
                items.add(_Item.cierre(x, deltas[x.id]));
              }
            }
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(comparando ? 'Elige 2 cierres' : 'Historial'),
            actions: [
              IconButton(
                tooltip: comparando ? 'Salir de comparar' : 'Comparar cierres',
                icon: Icon(comparando ? Icons.close : Icons.compare_arrows),
                onPressed: asc.length < 2 ? null : _alternarModoComparar,
              ),
            ],
          ),
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
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final it = items[i];
                    switch (it.tipo) {
                      case 0:
                        return _controles(cs, visibles, ent, sal, etiquetas, hayVacias);
                      case 1:
                        return _cabecera(it.g!, cs);
                      case 2:
                        return _tarjetaCierre(it.x!, it.delta, cs);
                      default:
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(children: [
                            Icon(Icons.filter_alt_off_outlined, size: 40, color: cs.outline),
                            const SizedBox(height: 8),
                            const Text('No hay cierres con esas etiquetas.'),
                            TextButton(
                              onPressed: () => setState(filtro.clear),
                              child: const Text('Quitar filtro'),
                            ),
                          ]),
                        );
                    }
                  },
                ),
          bottomNavigationBar: comparando
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      icon: const Icon(Icons.compare_arrows),
                      label: Text(seleccion.length == 2
                          ? 'Comparar los 2 cierres'
                          : 'Elige ${2 - seleccion.length} más'),
                      onPressed: seleccion.length == 2 ? _comparar : null,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }
}
