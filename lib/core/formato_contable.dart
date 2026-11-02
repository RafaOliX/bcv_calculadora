// Formato contable mientras se escribe: 18500,45 -> 18.500,45
// El punto o la coma que teclee el usuario cuentan como separador decimal.
import 'package:flutter/services.dart';

class FormatoContable extends TextInputFormatter {
  FormatoContable({this.decimales = 2});

  final int decimales;

  static String _digitos(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue anterior, TextEditingValue nuevo) {
    var t = nuevo.text;
    var pos = nuevo.selection.baseOffset;
    if (pos < 0 || pos > t.length) pos = t.length;
    final a = anterior.text;

    // Retroceso sobre un punto de miles: borra también el dígito de su izquierda.
    if (pos > 0 &&
        a.length == t.length + 1 &&
        pos < a.length &&
        a[pos] == '.' &&
        a.substring(0, pos) + a.substring(pos + 1) == t) {
      t = t.substring(0, pos - 1) + t.substring(pos);
      pos -= 1;
    }

    final tecleoSeparador = pos > 0 &&
        t.length == a.length + 1 &&
        (t[pos - 1] == '.' || t[pos - 1] == ',');

    String ent;
    String? dec;
    if (tecleoSeparador) {
      if (a.contains(',')) return anterior; // ya hay decimales
      ent = _digitos(t.substring(0, pos - 1));
      dec = _digitos(t.substring(pos));
    } else if (t.contains(',')) {
      final i = t.indexOf(',');
      ent = _digitos(t.substring(0, i));
      dec = _digitos(t.substring(i + 1));
    } else if (t.length - a.length > 1 && RegExp(r'^\d+\.\d{1,2}$').hasMatch(t)) {
      // Pegado tipo "1234.56"
      final i = t.indexOf('.');
      ent = _digitos(t.substring(0, i));
      dec = _digitos(t.substring(i + 1));
    } else {
      ent = _digitos(t);
    }

    if (decimales == 0) dec = null;
    if (dec != null && dec.length > decimales) dec = dec.substring(0, decimales);
    ent = ent.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (ent.isEmpty && dec == null) return const TextEditingValue();
    if (ent.isEmpty) ent = '0';

    final miles = ent.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    final r = dec == null ? miles : '$miles,$dec';

    // Mantiene el cursor junto a los mismos dígitos que tenía a su derecha.
    var derecha = 0;
    for (var i = pos; i < t.length; i++) {
      final u = t.codeUnitAt(i);
      if (u == 44 || (u >= 48 && u <= 57)) derecha++;
    }
    var off = r.length;
    var resto = derecha;
    while (resto > 0 && off > 0) {
      off--;
      if (r[off] != '.') resto--;
    }
    return TextEditingValue(text: r, selection: TextSelection.collapsed(offset: off));
  }
}
