// Importar movimientos desde un archivo CSV (con la plantilla).
import 'package:flutter/material.dart';

import '../../core/archivos.dart';
import '../../core/csv.dart';
import '../../core/widgets/tarjeta_error.dart';
import '../finanzas/finanzas_controller.dart';
import '../finanzas/plantillas.dart';
import '../tasas/tasas_historicas.dart';
import 'importador_mov.dart';

class ImportarMovimientosPage extends StatefulWidget {
  const ImportarMovimientosPage({super.key, required this.c});

  final FinanzasController c;

  @override
  State<ImportarMovimientosPage> createState() => _ImportarMovimientosPageState();
}

class _ImportarMovimientosPageState extends State<ImportarMovimientosPage> {
  ResultadoMov? res;
  String? error;
  bool trabajando = false;

  Future<void> _plantilla() async {
    try {
      final ok = await guardarArchivo(nombre: 'plantilla_movimientos.csv', texto: plantillaMovimientos());
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
      trabajando = true;
      error = null;
      res = null;
    });
    try {
      final texto = await elegirArchivoTexto();
      if (texto == null) {
        if (mounted) setState(() => trabajando = false);
        return;
      }
      final r = await construirMovimientos(
        filas: leerCsv(texto),
        existentes: widget.c.cuentas,
        nuevoId: widget.c.nuevoId,
        tasaDelDia: TasasHistoricas.instancia.deDia,
      );
      if (!mounted) return;
      setState(() {
        trabajando = false;
        res = r;
        error = r.error;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        trabajando = false;
        error = 'No pude leer el archivo: $e';
      });
    }
  }

  List<Widget> _resumen(ResultadoMov r) {
    return [
      const SizedBox(height: 16),
      Text('${r.movimientos.length} movimientos listos para importar',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 6),
      if (r.tasasBuscadas > 0) Text('• ${r.tasasBuscadas} con la tasa buscada por su fecha.'),
      if (r.cuentasNuevas.isNotEmpty)
        Text('• Se crearán cuentas nuevas: ${r.cuentasNuevas.map((e) => '${e.nombre} (${e.moneda.name})').join(', ')}.'),
      if (r.omitidas > 0) Text('• ${r.omitidas} filas omitidas (fecha, tipo, cuenta o monto inválidos).'),
      if (r.sinTasa > 0) Text('• ${r.sinTasa} omitidas por no encontrar la tasa BCV de su fecha.'),
      const Text('• No cambian los saldos de tus cuentas.'),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: r.movimientos.isEmpty
            ? null
            : () {
                final msg = ScaffoldMessenger.of(context);
                final n = widget.c.importarMovimientos(r);
                Navigator.pop(context);
                msg.showSnackBar(SnackBar(
                  content: Text('Importados $n movimientos'),
                  behavior: SnackBarBehavior.floating,
                ));
              },
        child: Text('Importar ${r.movimientos.length} movimientos'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final r = res;
    return Scaffold(
      appBar: AppBar(title: const Text('Importar movimientos')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '1. Descarga la plantilla.\n'
            '2. Llénala en Excel (una fila por gasto o ingreso) y guárdala como CSV.\n'
            '3. Elige el archivo aquí.\n\n'
            'Si dejas vacías las tasas, la app busca la de cada fecha.',
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
            onPressed: trabajando ? null : _elegir,
          ),
          if (trabajando)
            const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          const SizedBox(height: 12),
          if (error != null) TarjetaError(mensaje: error!),
          if (r != null && r.error == null) ..._resumen(r),
        ],
      ),
    );
  }
}
