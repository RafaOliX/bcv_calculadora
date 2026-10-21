// Funciones puras de formato y lectura de números. Sin dependencias de Flutter,
// así se pueden probar fácilmente y usar en cualquier pantalla.

/// Acepta "1234.56", "1234,56" o "1.234,56".
double? parsear(String texto) {
  var t = texto.trim().replaceAll(' ', '');
  if (t.isEmpty) return null;
  if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(t);
}

/// Para campos editables: sin separador de miles, con coma decimal.
String paraInput(double v, [int dec = 2]) => v.toStringAsFixed(dec).replaceAll('.', ',');

/// Para mostrar: 1234567.8 -> 1.234.567,80
String paraMostrar(double v, {int dec = 2}) {
  final partes = v.toStringAsFixed(dec).split('.');
  final entero = partes[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return dec == 0 ? entero : '$entero,${partes[1]}';
}

String fechaCorta(DateTime? d) {
  if (d == null) return '';
  String dos(int n) => n.toString().padLeft(2, '0');
  return '${dos(d.day)}/${dos(d.month)}/${d.year}';
}
