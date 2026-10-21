// Modelo: las tasas oficiales de un momento dado.
class Oficial {
  const Oficial({required this.usd, required this.eur, this.fecha});

  final double usd;
  final double eur;
  final DateTime? fecha;
}
