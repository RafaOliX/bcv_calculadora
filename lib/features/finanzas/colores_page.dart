// Personalizar colores de las monedas, el color principal y el modo claro/oscuro.
import 'package:flutter/material.dart';

import '../../core/colores.dart';
import '../../core/widgets/visuales.dart';

const _muestras = [
  Color(0xFF2E9E6B), Color(0xFF3F6FE0), Color(0xFFE8A33D), Color(0xFF1FA39A),
  Color(0xFF8E5CD9), Color(0xFFE0524D), Color(0xFFEC6FA8), Color(0xFFF2811D),
  Color(0xFF0F8F7E), Color(0xFF1B5FB5), Color(0xFF6B7A8F), Color(0xFF7CB342),
];

class ColoresPage extends StatelessWidget {
  const ColoresPage({super.key});

  Future<void> _personalizado(BuildContext context, ClaveColor k) async {
    final actual = ColoresApp.instancia.de(k);
    final r = await showDialog<Color>(
      context: context,
      builder: (ctx) {
        var hsv = HSVColor.fromColor(actual);
        Widget deslizador(String t, double v, double min, double max, ValueChanged<double> f) =>
            Row(children: [
              SizedBox(width: 84, child: Text(t)),
              Expanded(
                child: Slider(value: v.clamp(min, max).toDouble(), min: min, max: max, onChanged: f),
              ),
            ]);
        return StatefulBuilder(
          builder: (ctx, setS) => AlertDialog(
            title: Text(k.nombre),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: hsv.toColor(),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(height: 12),
              deslizador('Tono', hsv.hue, 0, 360, (v) => setS(() => hsv = hsv.withHue(v))),
              deslizador('Intensidad', hsv.saturation, 0, 1,
                  (v) => setS(() => hsv = hsv.withSaturation(v))),
              deslizador('Brillo', hsv.value, 0, 1, (v) => setS(() => hsv = hsv.withValue(v))),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, hsv.toColor()),
                child: const Text('Usar'),
              ),
            ],
          ),
        );
      },
    );
    if (r != null) ColoresApp.instancia.elegir(k, r);
  }

  Widget _muestra(BuildContext context, Color color, bool seleccionado, VoidCallback onTap,
      {IconData? icono}) {
    final borde = Theme.of(context).colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: icono == null ? color : null,
          gradient: icono == null
              ? null
              : const SweepGradient(colors: [
                  Colors.red, Colors.yellow, Colors.green, Colors.cyan, Colors.blue,
                  Colors.purple, Colors.red,
                ]),
          shape: BoxShape.circle,
          border: Border.all(color: seleccionado ? borde : Colors.transparent, width: 3),
        ),
        child: seleccionado
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : (icono == null ? null : Icon(icono, color: Colors.white, size: 18)),
      ),
    );
  }

  Widget _bloque(BuildContext context, ClaveColor k) {
    final col = ColoresApp.instancia;
    final actual = col.de(k);
    final esPersonal = !_muestras.contains(actual);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(color: actual, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(k.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final m in _muestras) _muestra(context, m, m == actual, () => col.elegir(k, m)),
          _muestra(context, actual, esPersonal, () => _personalizado(context, k),
              icono: Icons.colorize),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ColoresApp.instancia,
      builder: (context, _) {
        final col = ColoresApp.instancia;
        final cs = Theme.of(context).colorScheme;
        final base = col.principal;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Colores y apariencia'),
            actions: [TextButton(onPressed: col.restablecer, child: const Text('Restablecer'))],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TarjetaDegradado(
                colores: [Color.lerp(base, Colors.black, 0.35)!, base],
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Vista previa', style: TextStyle(color: Colors.white70)),
                  SizedBox(height: 4),
                  Text('1.234,56 \$',
                      style: TextStyle(
                          color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800)),
                ]),
              ),
              const SizedBox(height: 10),
              Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    Insignia(texto: 'USD', color: col.de(ClaveColor.usd), icono: Icons.attach_money),
                    Insignia(texto: 'EUR', color: col.de(ClaveColor.eur), icono: Icons.euro),
                    Insignia(
                        texto: 'Bs', color: col.de(ClaveColor.bs), icono: Icons.payments_outlined),
                    Insignia(
                        texto: 'USDT', color: col.de(ClaveColor.usdt), icono: Icons.currency_bitcoin),
                    Insignia(
                        texto: 'Paralelo',
                        color: col.de(ClaveColor.paralelo),
                        icono: Icons.trending_up),
                    Insignia(
                        texto: '+25,00 \$',
                        color: col.de(ClaveColor.sube),
                        icono: Icons.arrow_upward),
                    Insignia(
                        texto: '−12,00 \$',
                        color: col.de(ClaveColor.baja),
                        icono: Icons.arrow_downward),
                  ]),
                ),
              ),
              const SizedBox(height: 20),
              Text('Modo', style: TextStyle(color: cs.outline, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.system, label: Text('Sistema'), icon: Icon(Icons.brightness_auto)),
                  ButtonSegment(
                      value: ThemeMode.light, label: Text('Claro'), icon: Icon(Icons.light_mode)),
                  ButtonSegment(
                      value: ThemeMode.dark, label: Text('Oscuro'), icon: Icon(Icons.dark_mode)),
                ],
                selected: {col.modo},
                onSelectionChanged: (s) => col.cambiarModo(s.first),
              ),
              const SizedBox(height: 24),
              for (final k in ClaveColor.values) _bloque(context, k),
            ],
          ),
        );
      },
    );
  }
}
