// Importar el historial de saldos desde un archivo CSV: eliges el archivo y
// confirmas qué es cada columna.
import 'package:flutter/material.dart';

import '../../core/archivos.dart';
import '../../core/widgets/tarjeta_error.dart';
import 'finanzas_controller.dart';
import 'importador.dart';
import 'plantillas.dart';

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
  bool leyendo = false;

  Future<void> _plantilla() async {
    try {
      final ok = await guardarArchivo(nombre: 'plantilla_historial.csv', texto: plantillaHistorial());
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Plantilla guardada'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = 'No pude guardar la plantilla: $e');
    }
  }

  Future<void> _elegir() async {
    setState(() {
      leyendo = true;
      error = null;
    });
    try {
      final texto = await elegirArchivoTexto();
      if (!mounted) return;
      if (texto == null) {
        setState(() => leyendo = false);
        return;
      }
      final t = leerTabla(texto);
      setState(() {
        leyendo = false;
        if (t == null) {
          tabla = null;
          error = 'El archivo no tiene datos. La primera fila son los encabezados y debajo van tus filas. '
              'Descarga la plantilla para ver el formato.';
        } else {
          tabla = t;
          roles = adivinarRoles(t.encabezados);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        leyendo = false;
        tabla = null;
        error = 'No pude leer el archivo: $e';
      });
    }
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
      appBar: AppBar(title: const Text('Importar historial')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '1. Descarga la plantilla.\n'
            '2. Llénala en Excel (o pega tu propia hoja) y guárdala como CSV.\n'
            '3. Elige el archivo aquí.\n\n'
            'Fechas como dd/mm/aaaa y decimales con coma. En Excel: '
            'Guardar como > CSV UTF-8 (delimitado por comas).',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text('Descargar plantilla'),
            onPressed: _plantilla,
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            icon: const Icon(Icons.upload_file),
            label: const Text('Elegir archivo CSV'),
            onPressed: leyendo ? null : _elegir,
          ),
          const SizedBox(height: 12),
          if (error != null) TarjetaError(mensaje: error!),
          if (tabla != null) ..._mapeo(cs),
        ],
      ),
    );
  }
}
