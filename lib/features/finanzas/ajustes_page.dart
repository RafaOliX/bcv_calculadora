// Ajustes: importar, exportar, copias de seguridad y registro de errores.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/errores.dart';
import '../../core/widgets/dialogos.dart';
import '../../core/widgets/tarjeta_error.dart';
import 'finanzas_controller.dart';
import 'importar_page.dart';

class AjustesPage extends StatelessWidget {
  const AjustesPage({super.key, required this.c});

  final FinanzasController c;

  void _aviso(BuildContext context, String texto) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texto), behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final suave = Theme.of(context).colorScheme.outline;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text('Datos', style: TextStyle(color: suave, fontWeight: FontWeight.w600)),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Importar desde Excel'),
            subtitle: const Text('Pega tu hoja y elige qué es cada columna'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ImportarPage(c: c)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.table_view),
            title: const Text('Exportar historial'),
            subtitle: const Text('Copia una tabla para pegarla en Excel'),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: c.exportarTabla()));
              if (context.mounted) {
                _aviso(context, 'Copiado (${c.cierres.length} filas). Pégalo en Excel.');
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Copia de seguridad'),
            subtitle: const Text('Copia todos tus datos como texto. Guárdala en un lugar seguro'),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: c.exportarJson()));
              if (context.mounted) _aviso(context, 'Copia de seguridad copiada al portapapeles.');
            },
          ),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restaurar copia'),
            subtitle: const Text('Pega una copia de seguridad (reemplaza tus datos)'),
            onTap: () async {
              final ok = await confirmar(
                context,
                'Esto reemplaza tus cuentas, metas e historial actuales por los de la copia. ¿Continuar?',
                accion: 'Restaurar',
              );
              if (!ok) return;
              final d = await Clipboard.getData('text/plain');
              final texto = d?.text ?? '';
              if (!context.mounted) return;
              if (texto.trim().isEmpty) {
                _aviso(context, 'El portapapeles está vacío.');
                return;
              }
              _aviso(context, c.restaurarJson(texto) ?? 'Copia restaurada.');
            },
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
