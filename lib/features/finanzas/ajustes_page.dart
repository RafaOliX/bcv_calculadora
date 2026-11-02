// Ajustes: importar y exportar con archivos, plantillas, copias de seguridad,
// colores y registro de errores.
import 'package:flutter/material.dart';

import '../../core/archivos.dart';
import '../../core/errores.dart';
import '../../core/widgets/dialogos.dart';
import '../../core/widgets/tarjeta_error.dart';
import '../movimientos/importar_mov_page.dart';
import 'colores_page.dart';
import 'finanzas_controller.dart';
import 'importar_page.dart';
import 'plantillas.dart';

class AjustesPage extends StatelessWidget {
  const AjustesPage({super.key, required this.c});

  final FinanzasController c;

  String _sello() {
    final n = DateTime.now();
    String dos(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${dos(n.month)}-${dos(n.day)}';
  }

  void _aviso(BuildContext context, String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto), behavior: SnackBarBehavior.floating));
  }

  Future<void> _guardar(BuildContext context, String nombre, String texto, String ok) async {
    try {
      final guardado = await guardarArchivo(nombre: nombre, texto: texto);
      if (context.mounted && guardado) _aviso(context, ok);
    } catch (e) {
      if (context.mounted) mostrarDetalleError(context, 'No se pudo guardar el archivo.\n\n$e');
    }
  }

  Future<void> _restaurar(BuildContext context) async {
    try {
      final ok = await confirmar(
        context,
        'Esto reemplaza tus cuentas, metas, movimientos e historial actuales por los de la copia. ¿Continuar?',
        accion: 'Restaurar',
      );
      if (!ok || !context.mounted) return;
      final texto = await elegirArchivoTexto();
      if (texto == null || !context.mounted) return;
      _aviso(context, c.restaurarJson(texto) ?? 'Copia restaurada.');
    } catch (e) {
      if (context.mounted) mostrarDetalleError(context, 'No se pudo abrir el archivo.\n\n$e');
    }
  }

  Widget _titulo(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(t,
            style: TextStyle(
                color: Theme.of(context).colorScheme.outline, fontWeight: FontWeight.w600)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Colores y apariencia'),
            subtitle: const Text('Cambia los colores de las monedas y el modo oscuro'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ColoresPage()),
            ),
          ),
          const Divider(),
          _titulo(context, 'Importar (archivo CSV)'),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Importar historial de saldos'),
            subtitle: const Text('Tu hoja de Excel guardada como CSV'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ImportarPage(c: c)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('Importar movimientos'),
            subtitle: const Text('Gastos e ingresos; busca la tasa de cada fecha'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ImportarMovimientosPage(c: c)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Plantilla de historial'),
            subtitle: const Text('Descarga un CSV de ejemplo para llenar'),
            onTap: () => _guardar(context, 'plantilla_historial.csv', plantillaHistorial(),
                'Plantilla guardada.'),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Plantilla de movimientos'),
            subtitle: const Text('Descarga un CSV de ejemplo para llenar'),
            onTap: () => _guardar(context, 'plantilla_movimientos.csv', plantillaMovimientos(),
                'Plantilla guardada.'),
          ),
          _titulo(context, 'Exportar (archivo CSV, abre en Excel)'),
          ListTile(
            leading: const Icon(Icons.table_view),
            title: const Text('Exportar historial'),
            subtitle: const Text('Un archivo con todos tus cierres'),
            onTap: () => _guardar(context, 'historial_${_sello()}.csv', c.csvHistorial(),
                'Historial guardado (${c.cierres.length} filas).'),
          ),
          ListTile(
            leading: const Icon(Icons.table_chart_outlined),
            title: const Text('Exportar movimientos'),
            subtitle: const Text('Un archivo con tus gastos e ingresos y sus tasas'),
            onTap: () => _guardar(context, 'movimientos_${_sello()}.csv', c.csvMovimientos(),
                'Movimientos guardados (${c.movimientos.length} filas).'),
          ),
          _titulo(context, 'Copia de seguridad'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Guardar copia de seguridad'),
            subtitle: const Text('Un archivo con todos tus datos. Guárdalo fuera del teléfono'),
            onTap: () => _guardar(context, 'copia_finanzas_${_sello()}.json', c.exportarJson(),
                'Copia de seguridad guardada.'),
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restaurar copia'),
            subtitle: const Text('Elige un archivo de copia (reemplaza tus datos)'),
            onTap: () => _restaurar(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Registro de errores'),
            subtitle: const Text('Ver y copiar los errores de la app'),
            onTap: () => mostrarDetalleError(context, RegistroErrores.instancia.texto),
          ),
        ],
      ),
    );
  }
}
