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

/// Una "fila" de tu Excel: la foto de un día.
class Cierre {
  Cierre({
    required this.fecha,
    required this.bcv,
    required this.paralelo,
    required this.p2p,
    required this.totalBcv,
    required this.totalParalelo,
    required this.saldos,
  });

  final String fecha; // yyyy-MM-dd
  final double bcv;
  final double paralelo;
  final double p2p;
  final double totalBcv;
  final double totalParalelo;
  final Map<String, double> saldos; // nombre de cuenta -> saldo

  DateTime get fechaDate => DateTime.parse(fecha);

  Map<String, dynamic> toJson() => {
        'fecha': fecha,
        'bcv': bcv,
        'paralelo': paralelo,
        'p2p': p2p,
        'totalBcv': totalBcv,
        'totalParalelo': totalParalelo,
        'saldos': saldos,
      };

  factory Cierre.fromJson(Map<String, dynamic> j) => Cierre(
        fecha: j['fecha'] as String,
        bcv: (j['bcv'] as num).toDouble(),
        paralelo: (j['paralelo'] as num).toDouble(),
        p2p: (j['p2p'] as num).toDouble(),
        totalBcv: (j['totalBcv'] as num).toDouble(),
        totalParalelo: (j['totalParalelo'] as num).toDouble(),
        saldos: (j['saldos'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
      );
}
