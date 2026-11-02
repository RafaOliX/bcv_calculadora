// Lectura y escritura de CSV compatible con Excel en español:
// separador ";" y UTF-8 con BOM al escribir; al leer detecta ; , o tabulación.

/// Convierte filas en texto CSV (con BOM para que Excel respete los acentos).
String escribirCsv(List<List<String>> filas) {
  String celda(String c) {
    if (c.contains(';') || c.contains('"') || c.contains('\n') || c.contains('\r')) {
      return '"${c.replaceAll('"', '""')}"';
    }
    return c;
  }

  return '\uFEFF${filas.map((f) => f.map(celda).join(';')).join('\r\n')}\r\n';
}

/// Lee texto CSV y devuelve sus filas (ignora las vacías). Admite comillas.
List<List<String>> leerCsv(String texto) {
  var t = texto;
  if (t.startsWith('\uFEFF')) t = t.substring(1);

  final lineas = t.split(RegExp(r'\r?\n'));
  var primera = '';
  for (final l in lineas) {
    if (l.trim().isNotEmpty) {
      primera = l;
      break;
    }
  }
  final sep = primera.contains('\t') ? '\t' : (primera.contains(';') ? ';' : ',');

  final filas = <List<String>>[];
  var fila = <String>[];
  final sb = StringBuffer();
  var enComillas = false;

  void cerrarCelda() {
    fila.add(sb.toString().trim());
    sb.clear();
  }

  void cerrarFila() {
    cerrarCelda();
    if (fila.any((c) => c.isNotEmpty)) filas.add(fila);
    fila = <String>[];
  }

  for (var i = 0; i < t.length; i++) {
    final ch = t[i];
    if (enComillas) {
      if (ch == '"') {
        if (i + 1 < t.length && t[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          enComillas = false;
        }
      } else {
        sb.write(ch);
      }
    } else if (ch == '"') {
      enComillas = true;
    } else if (ch == sep) {
      cerrarCelda();
    } else if (ch == '\n') {
      cerrarFila();
    } else if (ch != '\r') {
      sb.write(ch);
    }
  }
  if (sb.isNotEmpty || fila.isNotEmpty) cerrarFila();
  return filas;
}
