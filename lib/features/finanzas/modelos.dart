// Modelos de datos de las finanzas. Todo es JSON-serializable para guardarlo.
enum Moneda { bs, usd, usdt }

extension MonedaX on Moneda {
  String get etiqueta => switch (this) {
        Moneda.bs => 'Bs',
        Moneda.usd => 'USD',
        Moneda.usdt => 'USDT',
      };

  /// USD y USDT se valoran 1:1 como dólares.
  bool get esDolar => this != Moneda.bs;
}

class Cuenta {
  Cuenta({required this.id, required this.nombre, required this.moneda, this.saldo = 0});

  final String id;
  final String nombre;
  final Moneda moneda;
  double saldo;

  Map<String, dynamic> toJson() =>
      {'id': id, 'nombre': nombre, 'moneda': moneda.name, 'saldo': saldo};

  factory Cuenta.fromJson(Map<String, dynamic> j) => Cuenta(
        id: j['id'] as String,
        nombre: j['nombre'] as String,
        moneda: Moneda.values.byName(j['moneda'] as String),
        saldo: (j['saldo'] as num).toDouble(),
      );
}

class Meta {
  Meta({required this.id, required this.nombre, required this.monto});

  final String id;
  final String nombre;
  final double monto; // en dólares

  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre, 'monto': monto};

  factory Meta.fromJson(Map<String, dynamic> j) => Meta(
        id: j['id'] as String,
        nombre: j['nombre'] as String,
        monto: (j['monto'] as num).toDouble(),
      );
}

/// Una "fila" de tu Excel: la foto de un momento. Puede haber varias por día.
class Cierre {
  Cierre({
    required this.id,
    required this.momento,
    required this.bcv,
    required this.paralelo,
    required this.totalBcv,
    required this.totalParalelo,
    required this.saldos,
    this.etiqueta,
  });

  final String id;
  final DateTime momento;
  final double bcv;
  final double paralelo;
  final double totalBcv;
  final double totalParalelo;
  final Map<String, double> saldos; // nombre de cuenta -> saldo
  String? etiqueta; // por qué: "Salida con amigos", "Compras de juegos"...

  Map<String, dynamic> toJson() => {
        'id': id,
        'momento': momento.toIso8601String(),
        'bcv': bcv,
        'paralelo': paralelo,
        'totalBcv': totalBcv,
        'totalParalelo': totalParalelo,
        'saldos': saldos,
        'etiqueta': etiqueta,
      };

  /// También lee cierres de versiones anteriores (solo fecha, sin id ni etiqueta).
  factory Cierre.fromJson(Map<String, dynamic> j) {
    final raw = (j['momento'] ?? j['fecha']) as String;
    return Cierre(
      id: (j['id'] as String?) ?? 'old_$raw',
      momento: DateTime.parse(raw),
      bcv: (j['bcv'] as num).toDouble(),
      paralelo: (j['paralelo'] as num).toDouble(),
      totalBcv: (j['totalBcv'] as num).toDouble(),
      totalParalelo: (j['totalParalelo'] as num).toDouble(),
      saldos: (j['saldos'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble())),
      etiqueta: j['etiqueta'] as String?,
    );
  }
}
