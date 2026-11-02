// Hoja que compara dos cierres: tasas, totales y cada cuenta.
import 'package:flutter/material.dart';

import '../../core/colores.dart';
import '../../core/formato.dart';
import '../../core/tema.dart';
import '../../core/widgets/visuales.dart';
import 'modelos.dart';

class HojaComparacion extends StatelessWidget {
  const HojaComparacion({super.key, required this.a, required this.b});

  final Cierre a; // el más antiguo
  final Cierre b; // el más reciente

  String _cuando(DateTime d) => '${fechaCorta(d)} ${horaCorta(d)}';

  Widget _celda(String t, {bool derecha = true, bool negrita = false, Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Text(
          t,
          textAlign: derecha ? TextAlign.right : TextAlign.left,
          style: TextStyle(fontWeight: negrita ? FontWeight.w700 : FontWeight.normal, color: color),
        ),
      );

  TableRow _fila(String nombre, double? va, double? vb) {
    final d = (va != null && vb != null) ? vb - va : null;
    return TableRow(children: [
      _celda(nombre, derecha: false),
      _celda(va == null ? '—' : paraMostrar(va)),
      _celda(vb == null ? '—' : paraMostrar(vb)),
      _celda(
        d == null ? '—' : conSigno(d),
        negrita: true,
        color: d == null ? null : (d >= 0 ? Paleta.sube : Paleta.baja),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final nombres = <String>{...a.saldos.keys, ...b.saldos.keys}.toList();
    final dif = b.momento.difference(a.momento);
    final duracion = dif.inDays >= 1 ? '${dif.inDays} días' : '${dif.inHours} h';
    final dTot = b.totalBcv - a.totalBcv;
    final pct = a.totalBcv == 0 ? null : (b.totalBcv / a.totalBcv - 1) * 100;
    final dPar = b.totalParalelo - a.totalParalelo;
    final base = ColoresApp.instancia.principal;
    const blanco = TextStyle(color: Colors.white);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Comparación', style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              Text('${_cuando(a.momento)}  →  ${_cuando(b.momento)}  ·  $duracion',
                  style: TextStyle(color: cs.outline)),
              const SizedBox(height: 12),
              TarjetaDegradado(
                colores: [Color.lerp(base, Colors.black, 0.35)!, base],
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Total en dólares (BCV)', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text('${paraMostrar(a.totalBcv)} \$', style: blanco.copyWith(fontSize: 16)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, color: Colors.white70, size: 18),
                    ),
                    Text('${paraMostrar(b.totalBcv)} \$', style: blanco.copyWith(fontSize: 16)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    '${conSigno(dTot)} \$  (${pct == null ? '—' : conSigno(pct)}%)',
                    style: blanco.copyWith(fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  Text('A paralelo: ${conSigno(dPar)} \$',
                      style: blanco.copyWith(fontSize: 13)),
                ]),
              ),
              const SizedBox(height: 16),
              Table(
                columnWidths: const {
                  0: FlexColumnWidth(2.4),
                  1: FlexColumnWidth(1.7),
                  2: FlexColumnWidth(1.7),
                  3: FlexColumnWidth(1.7),
                },
                border: TableBorder(horizontalInside: BorderSide(color: cs.outlineVariant)),
                children: [
                  TableRow(children: [
                    _celda('', derecha: false),
                    _celda('Antes', negrita: true),
                    _celda('Después', negrita: true),
                    _celda('Cambio', negrita: true),
                  ]),
                  _fila('Tasa BCV', a.bcv, b.bcv),
                  _fila('Tasa paralelo', a.paralelo, b.paralelo),
                  _fila('Total BCV', a.totalBcv, b.totalBcv),
                  _fila('Total paralelo', a.totalParalelo, b.totalParalelo),
                  for (final n in nombres) _fila(n, a.saldos[n], b.saldos[n]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
