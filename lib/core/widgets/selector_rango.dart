// Fila de chips para elegir un rango de fechas (o un rango propio con calendario).
import 'package:flutter/material.dart';

import '../rango_fechas.dart';

class SelectorRango extends StatelessWidget {
  const SelectorRango({
    super.key,
    required this.preset,
    required this.rango,
    required this.onCambio,
  });

  final PresetRango preset;
  final RangoFechas rango;
  final void Function(PresetRango, RangoFechas) onCambio;

  Future<void> _elegir(BuildContext context) async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2018),
      lastDate: DateTime(DateTime.now().year + 1, 12, 31),
      initialDateRange: (rango.desde != null && rango.hasta != null)
          ? DateTimeRange(start: rango.desde!, end: rango.hasta!)
          : null,
    );
    if (r == null) return;
    onCambio(
      PresetRango.personalizado,
      RangoFechas(
        DateTime(r.start.year, r.start.month, r.start.day),
        DateTime(r.end.year, r.end.month, r.end.day),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final p in PresetRango.values)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: p == PresetRango.personalizado ? const Icon(Icons.date_range, size: 18) : null,
              label: Text(p == PresetRango.personalizado && preset == p ? rango.etiqueta : p.nombre),
              selected: preset == p,
              onSelected: (_) {
                if (p == PresetRango.personalizado) {
                  _elegir(context);
                } else {
                  onCambio(p, RangoFechas.preset(p));
                }
              },
            ),
          ),
      ]),
    );
  }
}
