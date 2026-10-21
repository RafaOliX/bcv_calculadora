// Importar el historial desde Excel: pegas la hoja y eliges qué es cada columna.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/tarjeta_error.dart';
import 'finanzas_controller.dart';
import 'importador.dart';

class ImportarPage extends StatefulWidget {
  const ImportarPage({super.key, required this.c});

  final FinanzasController c;

  @override
  State<ImportarPage> createState() => _ImportarPageState();
}

class _ImportarPageState extends State<ImportarPage> {
  TablaImportada? tabla;
  List<Rol> roles = [];
  String? error;

  Future<void> _pegar() async {
    final d = await Clipboard.getData('text/plain');
    final t = leerTabla(d?.text ?? '');
    setState(() {
      if (t == null) {
        tabla = null;
        error = 'No encontré una tabla. En Excel, selecciona desde la fila de encabezados '
            'hasta la última fila, copia (Ctrl+C) y vuelve a tocar Pegar.';
      } else {
        error = null;
        tabla = t;
        roles = adivinarRoles(t.encabezados);
      }
    });
  }

  List<Widget> _mapeo(ColorScheme cs) {
    final t = tabla!;
    final res = construir(t, roles);
    final faltan = !roles.contains(Rol.fecha) || !roles.contains(Rol.bcv) ||
        !roles.any((r) => r.esCuenta);
    return [
      const SizedBox(height: 16),
      Text('Columnas (${t.filas.length} filas)', style: Theme.of(context).textTheme.titleMedium),
      const Text('Revisa qué es cada una. Ajusta las que no estén bien.'),
      const SizedBox(height: 8),
      for (var i = 0; i < roles.length; i++)
        Row(children: [
          Expanded(
            child: Text(
              t.encabezados[i].isEmpty ? '(sin nombre)' : t.encabezados[i],
              overflow: TextOverflow.ellipsis,
            ),
          ),
          DropdownButton<Rol>(
            value: roles[i],
            onChanged: (r) => setState(() => roles[i] = r!),
            items: [
              for (final r in Rol.values) DropdownMenuItem(value: r, child: Text(r.nombre)),
            ],
          ),
        ]),
      const Divider(height: 24),
      if (faltan)
        Text(
          'Falta asignar al menos la columna Fecha, la Tasa BCV y una cuenta.',
          style: TextStyle(color: cs.error),
        )
      else ...[
        Text('${res.cierres.length} filas válidas · ${res.omitidas} omitidas (sin fecha o sin tasa BCV).'),
        const SizedBox(height: 4),
        Text('Cuentas: ${res.cuentas.map((e) => '${e.nombre} (${e.moneda.name})').join(', ')}'),
      ],
      const SizedBox(height: 12),
      FilledButton(
        onPressed: res.cierres.isEmpty
            ? null
            : () {
                final msg = ScaffoldMessenger.of(context);
                final n = widget.c.importar(res);
                Navigator.pop(context);
                msg.showSnackBar(SnackBar(
                  content: Text('Importados $n cierres'),
                  behavior: SnackBarBehavior.floating,
                ));
              },
        child: Text('Importar ${res.cierres.length} cierres'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Importar desde Excel')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '1. En Excel selecciona tu tabla, desde la fila de encabezados hasta el final.\n'
            '2. Copia (Ctrl+C).\n'
            '3. Aquí toca Pegar.\n\n'
            'Fechas como dd/mm/aaaa y decimales con coma, como en tu hoja.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.content_paste),
            label: const Text('Pegar desde el portapapeles'),
            onPressed: _pegar,
          ),
          const SizedBox(height: 12),
          if (error != null) TarjetaError(mensaje: error!),
          if (tabla != null) ..._mapeo(cs),
        ],
      ),
    );
  }
}
