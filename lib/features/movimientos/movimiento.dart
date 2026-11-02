// Un gasto o un ingreso, con la tasa del día en que ocurrió.
import '../finanzas/modelos.dart';

enum TipoMov {
  gasto('Gasto'),
  ingreso('Ingreso');

  const TipoMov(this.nombre);
  final String nombre;
  bool get esGasto => this == gasto;
}

class Movimiento {
  Movimiento({
    required this.id,
    required this.momento,
    required this.tipo,
    required this.cuentaId,
    required this.cuentaNombre,
    required this.moneda,
    required this.monto,
    required this.bcv,
    this.paralelo,
    this.etiqueta,
    this.nota,
    this.ajustoSaldo = false,
  });

  final String id;
  final DateTime momento;
  final TipoMov tipo;
  final String cuentaId;
  final String cuentaNombre; // se guarda por si la cuenta se elimina
  final Moneda moneda;
  final double monto; // en la moneda de la cuenta, siempre positivo
  final double bcv; // Bs por dólar ese día (0 si no se conocía y la cuenta era en dólares)
  final double? paralelo;
  final String? etiqueta;
  final String? nota;
  final bool ajustoSaldo; // si este movimiento modificó el saldo de la cuenta

  /// Valor en dólares a tasa BCV (o paralelo) del día del movimiento.
  double valorUsd(bool enParalelo) {
    if (moneda.esDolar) return monto;
    final t = enParalelo ? (paralelo ?? bcv) : bcv;
    return t > 0 ? monto / t : 0;
  }

  /// Igual que valorUsd pero negativo si es un gasto.
  double firmado(bool enParalelo) => tipo.esGasto ? -valorUsd(enParalelo) : valorUsd(enParalelo);

  Map<String, dynamic> toJson() => {
        'id': id,
        'momento': momento.toIso8601String(),
        'tipo': tipo.name,
        'cuentaId': cuentaId,
        'cuentaNombre': cuentaNombre,
        'moneda': moneda.name,
        'monto': monto,
        'bcv': bcv,
        'paralelo': paralelo,
        'etiqueta': etiqueta,
        'nota': nota,
        'ajustoSaldo': ajustoSaldo,
      };

  factory Movimiento.fromJson(Map<String, dynamic> j) => Movimiento(
        id: j['id'] as String,
        momento: DateTime.parse(j['momento'] as String),
        tipo: TipoMov.values.byName(j['tipo'] as String),
        cuentaId: j['cuentaId'] as String,
        cuentaNombre: j['cuentaNombre'] as String,
        moneda: Moneda.values.byName(j['moneda'] as String),
        monto: (j['monto'] as num).toDouble(),
        bcv: (j['bcv'] as num).toDouble(),
        paralelo: (j['paralelo'] as num?)?.toDouble(),
        etiqueta: j['etiqueta'] as String?,
        nota: j['nota'] as String?,
        ajustoSaldo: (j['ajustoSaldo'] as bool?) ?? false,
      );
}
