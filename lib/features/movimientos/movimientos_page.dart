// Movimientos: gastos e ingresos con rango de fechas, agrupación, filtros por
// etiqueta y análisis (por etiqueta, por día de la semana y mapa de calor).
import 'package:flutter/material.dart';

import '../../core/colores.dart';
import '../../core/formato.dart';
import '../../core/rango_fechas.dart';
import '../../core/tema.dart';
import '../../core/widgets/selector_rango.dart';
import '../../core/widgets/visuales.dart';
import '../finanzas/finanzas_controller.dart';
import '../finanzas/historial_logica.dart';
import '../finanzas/modelos.dart';
import 'movimiento.dart';
import 'movimiento_form.dart';
import 'movimientos_logica.dart';

class _Item {
  _Item.controles() : g = null, m = null, tipo = 0;
  _Item.analisis() : g = null, m = null, tipo = 1;
  _Item.grupo(this.g) : m = null, tipo = 2;
  _Item.mov(this.m) : g = null, tipo = 3;
  _Item.vacio() : g = null, m = null, tipo = 4;

  final int tipo;
  final GrupoMov? g;
  final Movimiento? m;
}

const _diasPlural = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábados', 'domingos'];

class MovimientosPage extends StatefulWidget {
  const MovimientosPage({super.key, required this.c});

  final FinanzasController c;

  @override
  State<MovimientosPage> createState() => _MovimientosPageState();
}

class _MovimientosPageState extends State<MovimientosPage> {
  FinanzasController get c => widget.c;

  static const _sin = '__sin_etiqueta__';

  PresetRango preset = PresetRango.mes;
  RangoFechas rango = RangoFechas.preset(PresetRango.mes);
  TipoMov? tipo;
  Agrupar modo = Agrupar.semana;
  bool enParalelo = false;
  final Set<String> filtro = {};
  final Set<String> colapsados = {};

  String _claveEt(Movimiento m) {
    final e = m.etiqueta;
    return (e == null || e.isEmpty) ? _sin : e;
  }

  void _abrirForm([Movimiento? editar]) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => MovimientoForm(c: c, editar: editar),
    );
  }

  void _alternarEtiqueta(String e) {
    setState(() {
      if (!filtro.remove(e)) filtro.add(e);
    });
  }

  void _seleccionarDia(DateTime d) {
    setState(() {
      preset = PresetRango.personalizado;
      rango = RangoFechas(d, d);
    });
  }

  // ---- Controles ----------------------------------------------------------
  Widget _controles(List<String> etiquetas, bool hayVacias) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    Widget titulo(String t) =>
        Padding(padding: const EdgeInsets.only(top: 12, bottom: 6), child: Text(t, style: tt.labelLarge));
    Widget fila(List<Widget> chips) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final w in chips) Padding(padding: const EdgeInsets.only(right: 8), child: w),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SelectorRango(
        preset: preset,
        rango: rango,
        onCambio: (p, r) => setState(() {
          preset = p;
          rango = r;
        }),
      ),
      titulo('Tipo'),
      fila([
        ChoiceChip(
          label: const Text('Todos'),
          selected: tipo == null,
          onSelected: (_) => setState(() => tipo = null),
        ),
        ChoiceChip(
          avatar: Icon(Icons.north_east, size: 16, color: Paleta.baja),
          label: const Text('Gastos'),
          selected: tipo == TipoMov.gasto,
          onSelected: (_) => setState(() => tipo = TipoMov.gasto),
        ),
        ChoiceChip(
          avatar: Icon(Icons.south_west, size: 16, color: Paleta.sube),
          label: const Text('Ingresos'),
          selected: tipo == TipoMov.ingreso,
          onSelected: (_) => setState(() => tipo = TipoMov.ingreso),
        ),
      ]),
      titulo('Agrupar por'),
      fila([
        for (final a in Agrupar.values)
          ChoiceChip(
            label: Text(a.nombre),
            selected: modo == a,
            onSelected: (_) => setState(() => modo = a),
          ),
      ]),
      titulo('Valorar en dólares a tasa'),
      fila([
        ChoiceChip(
          label: const Text('BCV'),
          selected: !enParalelo,
          onSelected: (_) => setState(() => enParalelo = false),
        ),
        ChoiceChip(
          label: const Text('Paralelo'),
          selected: enParalelo,
          onSelected: (_) => setState(() => enParalelo = true),
        ),
      ]),
      titulo('Etiquetas'),
      if (etiquetas.isEmpty)
        Text('Aún no hay etiquetas. Ponlas al registrar un movimiento.',
            style: TextStyle(color: cs.outline, fontSize: 12))
      else
        fila([
          FilterChip(
            label: const Text('Todas'),
            selected: filtro.isEmpty,
            onSelected: (_) => setState(filtro.clear),
          ),
          for (final e in [...etiquetas, if (hayVacias) _sin])
            FilterChip(
              label: Text(e == _sin ? 'Sin etiqueta' : e),
              selected: filtro.contains(e),
              onSelected: (_) => _alternarEtiqueta(e),
            ),
        ]),
      const SizedBox(height: 8),
    ]);
  }

  // ---- Resumen y análisis -------------------------------------------------
  Widget _cifra(String t, double v, Color color, IconData icono, {bool signo = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icono, size: 16, color: color),
        const SizedBox(width: 4),
        Text(t, style: const TextStyle(fontSize: 12)),
      ]),
      NumeroAnimado(
        valor: v,
        formato: (x) => signo ? '${conSigno(x)} \$' : '${paraMostrar(x)} \$',
        estilo: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
      ),
    ]);
  }

  Widget _resumen(ResumenMov res, ColorScheme cs) {
    final total = enParalelo ? c.totalParalelo : c.totalBcv;
    final prom = res.promedioDiario;
    final autonomia = (total != null && total > 0 && prom > 0) ? total / prom : null;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: _cifra('Ingresos', res.ingresos, Paleta.sube, Icons.south_west)),
            Expanded(child: _cifra('Gastos', res.gastos, Paleta.baja, Icons.north_east)),
            Expanded(
              child: _cifra('Neto', res.neto, res.neto >= 0 ? Paleta.sube : Paleta.baja,
                  Icons.balance, signo: true),
            ),
          ]),
          const Divider(height: 24),
          Row(children: [
            Icon(Icons.speed, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Gastas en promedio ${paraMostrar(prom)} \$ por día '
                  '(${res.dias} ${res.dias == 1 ? 'día' : 'días'}).'),
            ),
          ]),
          if (autonomia != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.hourglass_bottom, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Con tu saldo actual (${paraMostrar(total!)} \$) te alcanzan '
                    '≈ ${autonomia.round()} días a este ritmo.'),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  Widget _subtitulo(String t, ColorScheme cs) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w800)),
      );

  Widget _porEtiqueta(List<MapEntry<String, double>> lista, Color color, ColorScheme cs) {
    if (lista.isEmpty) {
      return Text('Sin datos en este período.', style: TextStyle(color: cs.outline));
    }
    final mx = lista.first.value;
    final total = lista.fold(0.0, (a, e) => a + e.value);
    return Column(children: [
      for (final e in lista.take(6))
        InkWell(
          onTap: () => _alternarEtiqueta(e.key == 'Sin etiqueta' ? _sin : e.key),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text('${paraMostrar(e.value)} \$  ·  ${(e.value / total * 100).round()}%'),
              ]),
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: e.value / mx),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (_, t, __) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: t,
                    minHeight: 8,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ]),
          ),
        ),
    ]);
  }

  Widget _semana(ResumenMov res, ColorScheme cs) {
    final v = res.gastoPorDiaSemana;
    final mx = v.fold(0.0, (a, b) => a > b ? a : b);
    final imax = mx == 0 ? -1 : v.indexOf(mx);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        height: 96,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: mx == 0 ? 0 : v[i] / mx),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (_, t, __) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    height: 4 + 64 * t,
                    decoration: BoxDecoration(
                      color: i == imax ? Paleta.baja : Paleta.baja.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('LMXJVSD'[i],
                    style: TextStyle(
                        fontSize: 12, fontWeight: i == imax ? FontWeight.bold : FontWeight.normal)),
              ]),
            ),
        ]),
      ),
      if (imax >= 0)
        Text('Gastas más los ${_diasPlural[imax]} (${paraMostrar(v[imax])} \$ en total).',
            style: TextStyle(color: cs.outline)),
    ]);
  }

  Widget _celdaCalor(DateTime dia, DateTime hoy, ResumenMov base, double mx, ColorScheme cs) {
    final futuro = dia.isAfter(hoy);
    final g = base.gastoPorDia[dia] ?? 0;
    final t = mx == 0 ? 0.0 : g / mx;
    final fondo = futuro
        ? Colors.transparent
        : (g == 0 ? cs.surfaceContainerHighest : Paleta.baja.withValues(alpha: 0.25 + 0.75 * t));
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: GestureDetector(
            onTap: futuro ? null : () => _seleccionarDia(dia),
            child: Container(
              decoration: BoxDecoration(
                color: fondo,
                borderRadius: BorderRadius.circular(8),
                border: dia == hoy ? Border.all(color: cs.primary, width: 2) : null,
              ),
              child: Center(
                child: Text(
                  '${dia.day}',
                  style: TextStyle(
                    fontSize: 11,
                    color: (g > 0 && t > 0.55) ? Colors.white : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mapaCalor(ResumenMov base, ColorScheme cs) {
    final n = DateTime.now();
    final hoy = DateTime(n.year, n.month, n.day);
    final lunes = DateTime(hoy.year, hoy.month, hoy.day - (hoy.weekday - 1));
    final inicio = DateTime(lunes.year, lunes.month, lunes.day - 28);
    final mx = base.gastoPorDia.values.fold(0.0, (a, b) => a > b ? a : b);
    return Column(children: [
      Row(children: [
        for (final l in 'LMXJVSD'.split(''))
          Expanded(child: Center(child: Text(l, style: TextStyle(fontSize: 11, color: cs.outline)))),
      ]),
      for (var f = 0; f < 5; f++)
        Row(children: [
          for (var d = 0; d < 7; d++)
            _celdaCalor(DateTime(inicio.year, inicio.month, inicio.day + f * 7 + d), hoy, base, mx, cs),
        ]),
      const SizedBox(height: 4),
      Text('Toca un día para ver solo sus movimientos.',
          style: TextStyle(fontSize: 12, color: cs.outline)),
    ]);
  }

  Widget _analisis(ResumenMov res, ResumenMov base, ColorScheme cs) {
    final esIngreso = tipo == TipoMov.ingreso;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 10),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        initiallyExpanded: true,
        leading: Icon(Icons.insights, color: cs.primary),
        title: const Text('Análisis', style: TextStyle(fontWeight: FontWeight.w800)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subtitulo(esIngreso ? 'Ingresos por etiqueta' : 'Gastos por etiqueta', cs),
          _porEtiqueta(
            esIngreso ? res.ingresoPorEtiqueta : res.gastoPorEtiqueta,
            esIngreso ? Paleta.sube : Paleta.baja,
            cs,
          ),
          _subtitulo('Gastos por día de la semana', cs),
          _semana(res, cs),
          _subtitulo('Últimas 5 semanas', cs),
          _mapaCalor(base, cs),
        ],
      ),
    );
  }

  // ---- Lista --------------------------------------------------------------
  Widget _cabecera(GrupoMov g, ColorScheme cs) {
    final colapsado = colapsados.contains(g.clave);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() {
        if (!colapsados.remove(g.clave)) colapsados.add(g.clave);
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
            Icon(colapsado ? Icons.expand_more : Icons.expand_less),
          ]),
          Text('${g.items.length} ${g.items.length == 1 ? 'movimiento' : 'movimientos'}',
              style: TextStyle(fontSize: 12, color: cs.outline)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            Insignia(
              texto: 'Neto ${conSigno(g.neto)} \$',
              color: g.neto >= 0 ? Paleta.sube : Paleta.baja,
              icono: g.neto >= 0 ? Icons.trending_up : Icons.trending_down,
            ),
            if (g.ingresos > 0)
              Insignia(
                texto: 'Ingresos ${paraMostrar(g.ingresos)} \$',
                color: Paleta.sube,
                icono: Icons.south_west,
              ),
            if (g.gastos > 0)
              Insignia(
                texto: 'Gastos ${paraMostrar(g.gastos)} \$',
                color: Paleta.baja,
                icono: Icons.north_east,
              ),
          ]),
        ]),
      ),
    );
  }

  Widget _tarjetaMov(Movimiento m) {
    final cs = Theme.of(context).colorScheme;
    final color = m.tipo.esGasto ? Paleta.baja : Paleta.sube;
    final signo = m.tipo.esGasto ? '−' : '+';
    final nota = m.nota;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(m.tipo.esGasto ? Icons.north_east : Icons.south_west, color: color),
        ),
        title: Text(
          (m.etiqueta == null || m.etiqueta!.isEmpty) ? 'Sin etiqueta' : m.etiqueta!,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        isThreeLine: nota != null,
        subtitle: Text(
          '${fechaCorta(m.momento)} ${horaCorta(m.momento)} · ${m.cuentaNombre}'
          '${nota == null ? '' : '\n$nota'}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$signo${paraMostrar(m.monto)} ${m.moneda.etiqueta}',
                style: TextStyle(fontWeight: FontWeight.w800, color: color)),
            if (!m.moneda.esDolar)
              Text('≈ ${paraMostrar(m.valorUsd(enParalelo))} \$',
                  style: TextStyle(fontSize: 12, color: cs.outline)),
          ],
        ),
        onTap: () => _abrirForm(m),
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
        final todos = c.movimientos; // del más antiguo al más reciente

        final etiquetas = <String>[];
        for (final m in todos.reversed) {
          final e = m.etiqueta;
          if (e != null && e.isNotEmpty && !etiquetas.contains(e)) etiquetas.add(e);
        }
        final hayVacias = todos.any((m) => _claveEt(m) == _sin);
        filtro.removeWhere((e) => e != _sin && !etiquetas.contains(e));

        bool pasa(Movimiento m) =>
            (tipo == null || m.tipo == tipo) && (filtro.isEmpty || filtro.contains(_claveEt(m)));
        final baseSinRango = todos.where(pasa).toList();
        final visibles = baseSinRango.where((m) => rango.contiene(m.momento)).toList();
        final res = resumir(visibles, enParalelo, rango);
        final resBase = resumir(baseSinRango, enParalelo, RangoFechas.todo);

        final items = <_Item>[_Item.controles(), _Item.analisis()];
        if (visibles.isEmpty) {
          items.add(_Item.vacio());
        } else {
          for (final g in agruparMov(visibles, modo, enParalelo)) {
            if (modo != Agrupar.ninguno) items.add(_Item.grupo(g));
            if (!colapsados.contains(g.clave)) {
              for (final m in g.items) {
                items.add(_Item.mov(m));
              }
            }
          }
        }

        return Scaffold(
          appBar: AppBar(title: const Text('Movimientos')),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _abrirForm(),
            icon: const Icon(Icons.add),
            label: const Text('Registrar'),
          ),
          body: todos.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.receipt_long_outlined, size: 56, color: cs.primary),
                      const SizedBox(height: 12),
                      const Text(
                        'Aquí verás tus gastos e ingresos.\n'
                        'Puedes registrarlos de hoy o de cualquier fecha: la app busca la tasa de ese día.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Registrar el primero'),
                        onPressed: () => _abrirForm(),
                      ),
                    ]),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final it = items[i];
                    switch (it.tipo) {
                      case 0:
                        return _controles(etiquetas, hayVacias);
                      case 1:
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _resumen(res, cs),
                          _analisis(res, resBase, cs),
                        ]);
                      case 2:
                        return _cabecera(it.g!, cs);
                      case 3:
                        return _tarjetaMov(it.m!);
                      default:
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(children: [
                            Icon(Icons.filter_alt_off_outlined, size: 40, color: cs.outline),
                            const SizedBox(height: 8),
                            const Text('No hay movimientos con estos filtros.'),
                            TextButton(
                              onPressed: () => setState(() {
                                filtro.clear();
                                tipo = null;
                                preset = PresetRango.todo;
                                rango = RangoFechas.todo;
                              }),
                              child: const Text('Quitar filtros'),
                            ),
                          ]),
                        );
                    }
                  },
                ),
        );
      },
    );
  }
}
