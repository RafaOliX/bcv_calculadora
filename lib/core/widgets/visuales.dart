// Piezas visuales reutilizables: tarjeta con degradado, número animado,
// aparición suave y etiqueta de color.
import 'package:flutter/material.dart';

class TarjetaDegradado extends StatelessWidget {
  const TarjetaDegradado({
    super.key,
    required this.child,
    required this.colores,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final List<Color> colores;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colores,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colores.first.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Un número que "cuenta" hasta su valor y se anima cada vez que cambia.
class NumeroAnimado extends StatelessWidget {
  const NumeroAnimado({super.key, required this.valor, required this.formato, this.estilo});

  final double? valor;
  final String Function(double) formato;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) {
    final v = valor;
    if (v == null) return Text('—', style: estilo);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: v),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (_, x, __) => Text(formato(x), style: estilo),
    );
  }
}

/// Aparece con un fundido y un pequeño desplazamiento hacia arriba.
/// `retraso` (ms) hace que los elementos de una lista entren en cascada.
class Aparecer extends StatelessWidget {
  const Aparecer({super.key, required this.child, this.retraso = 0});

  final Widget child;
  final int retraso;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 450 + retraso),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: c),
      ),
    );
  }
}

/// Etiqueta de color suave, con icono opcional.
class Insignia extends StatelessWidget {
  const Insignia({super.key, required this.texto, required this.color, this.icono});

  final String texto;
  final Color color;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icono != null) ...[
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            texto,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ),
      ]),
    );
  }
}

/// Mini gráfica de línea (sin paquetes externos).
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.valores, required this.color, this.alto = 56});

  final List<double> valores;
  final Color color;
  final double alto;

  @override
  Widget build(BuildContext context) {
    if (valores.length < 2) {
      return SizedBox(
        height: alto,
        child: Center(
          child: Text(
            'Se necesitan al menos 2 cierres para la gráfica',
            style: TextStyle(color: Theme.of(context).colorScheme.outline, fontSize: 12),
          ),
        ),
      );
    }
    var v = valores;
    if (v.length > 120) {
      final paso = v.length / 120;
      v = [for (var i = 0; i < 120; i++) valores[(i * paso).floor()], valores.last];
    }
    return SizedBox(
      height: alto,
      width: double.infinity,
      child: CustomPaint(painter: _SparkPainter(v, color)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.v, this.color);

  final List<double> v;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    var mn = v.first, mx = v.first;
    for (final x in v) {
      if (x < mn) mn = x;
      if (x > mx) mx = x;
    }
    final rango = (mx - mn) == 0 ? 1.0 : mx - mn;
    Offset punto(int i) => Offset(
          size.width * i / (v.length - 1),
          size.height - 4 - (size.height - 8) * (v[i] - mn) / rango,
        );

    final linea = Path()..moveTo(punto(0).dx, punto(0).dy);
    for (var i = 1; i < v.length; i++) {
      final p = punto(i);
      linea.lineTo(p.dx, p.dy);
    }
    final area = Path.from(linea)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      linea,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(punto(v.length - 1), 4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.v != v || old.color != color;
}
