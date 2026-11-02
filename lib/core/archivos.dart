// Abrir y guardar archivos con el selector del teléfono. Es el ÚNICO archivo
// que usa el plugin file_picker: si cambia su API, solo hay que tocar este.
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'errores.dart';

String _decodificar(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } catch (_) {
    return latin1.decode(bytes); // CSV viejos guardados sin UTF-8
  }
}

/// Abre el selector, deja elegir un archivo y devuelve su texto.
/// Devuelve null si el usuario cancela; lanza si no se pudo leer.
Future<String?> elegirArchivoTexto() async {
  try {
    final dynamic r = await FilePicker.pickFiles(allowMultiple: false);
    if (r == null) return null;
    final dynamic archivo = r is List ? (r.isEmpty ? null : r.first) : (r as dynamic).files.first;
    if (archivo == null) return null;
    Uint8List? bytes;
    try {
      bytes = await archivo.readAsBytes();
    } catch (_) {
      bytes = archivo.bytes;
    }
    if (bytes == null) throw 'No se pudo leer el archivo.';
    return _decodificar(bytes);
  } catch (e, st) {
    RegistroErrores.instancia.registrar('Elegir archivo', e, st);
    rethrow;
  }
}

/// Abre el cuadro "Guardar como" y escribe el texto en el archivo elegido.
/// Devuelve false si el usuario cancela; lanza si falla.
Future<bool> guardarArchivo({required String nombre, required String texto}) async {
  try {
    final bytes = Uint8List.fromList(utf8.encode(texto));
    final dynamic ruta = await FilePicker.saveFile(fileName: nombre, bytes: bytes);
    return ruta != null;
  } catch (e, st) {
    RegistroErrores.instancia.registrar('Guardar archivo', e, st);
    rethrow;
  }
}
