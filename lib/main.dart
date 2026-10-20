import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const BcvApp());

class BcvApp extends StatelessWidget {
  const BcvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tasa BCV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: const Conversor(),
    );
  }
}

// ---------------------------------------------------------------------------
// Obtención de tasas: scraping del BCV y dolarapi como respaldo
// ---------------------------------------------------------------------------
class Oficial {
  Oficial(this.usd, this.eur, this.fecha);
  final double usd;
  final double eur;
  final DateTime? fecha;
}

class TasaServicio {
  static const _bcv = 'https://www.bcv.org.ve/';
  static const _apiUsd = 'https://ve.dolarapi.com/v1/dolares/oficial';
  static const _apiEur = 'https://ve.dolarapi.com/v1/euros/oficial';
  static const _ua = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0 Safari/537.36';

  static double _num(String s) =>
      double.parse(s.trim().replaceAll('.', '').replaceAll(',', '.'));

  static Future<Oficial> bcv() async {
    final io = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = _ua
      ..badCertificateCallback = (cert, host, port) => host.endsWith('bcv.org.ve');
    final client = IOClient(io);
    try {
      final r = await client.get(Uri.parse(_bcv), headers: {
        'User-Agent': _ua,
        'Accept-Language': 'es-VE,es;q=0.9,en;q=0.8',
      }).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) throw 'HTTP ${r.statusCode}';
      final doc = html.parse(r.body);

      double leer(String id) {
        final t = doc.querySelector('#$id strong')?.text;
        if (t == null) throw 'no se encontró #$id';
        final v = _num(t);
        if (v <= 0) throw 'tasa inválida en #$id';
        return v;
      }

      final f = doc.querySelector('.date-display-single')?.attributes['content'];
      return Oficial(leer('dolar'), leer('euro'), f == null ? null : DateTime.tryParse(f));
    } finally {
      client.close();
    }
  }

  static Future<Oficial> api() async {
    final rs = await Future.wait([_apiUsd, _apiEur].map(
      (u) => http.get(Uri.parse(u)).timeout(const Duration(seconds: 10)),
    ));
    final datos = <Map<String, dynamic>>[];
    for (final r in rs) {
      if (r.statusCode != 200) throw 'HTTP ${r.statusCode}';
      datos.add(jsonDecode(r.body) as Map<String, dynamic>);
    }
    final f = datos.first['fechaActualizacion'] as String?;
    return Oficial(
      (datos[0]['promedio'] as num).toDouble(),
      (datos[1]['promedio'] as num).toDouble(),
      f == null ? null : DateTime.tryParse(f),
    );
  }

  static Future<Oficial> obtener() async {
    final errores = <String>[];
    try {
      return await bcv();
    } catch (e) {
      errores.add('BCV: $e');
    }
    try {
      return await api();
    } catch (e) {
      errores.add('API: $e');
    }
    throw errores.join('\n');
  }
}

// Caché opcional: si el plugin falla, la app sigue funcionando sin ella.
class Cache {
  static Future<Oficial?> leer() async {
    try {
      final p = await SharedPreferences.getInstance();
      final usd = p.getDouble('usd');
      final eur = p.getDouble('eur');
      if (usd == null || eur == null) return null;
      return Oficial(usd, eur, DateTime.tryParse(p.getString('fecha') ?? ''));
    } catch (_) {
      return null;
    }
  }

  static Future<void> guardar(Oficial o) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble('usd', o.usd);
      await p.setDouble('eur', o.eur);
      if (o.fecha != null) await p.setString('fecha', o.fecha!.toIso8601String());
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Pantalla
// ---------------------------------------------------------------------------
enum Fuente { usd, eur }

class Conversor extends StatefulWidget {
  const Conversor({super.key});

  @override
  State<Conversor> createState() => _ConversorState();
}

class _ConversorState extends State<Conversor> {
  final _tasaCtrl = TextEditingController();
  final _bsCtrl = TextEditingController();
  final _divisaCtrl = TextEditingController();

  Oficial? _oficial;
  Fuente _fuente = Fuente.usd;
  double? _custom; // tasa escrita por el usuario; null = usar la oficial
  bool _editadoBs = true;
  bool _cargando = false;
  String? _aviso;
  String? _detalle;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  @override
  void dispose() {
    _tasaCtrl.dispose();
    _bsCtrl.dispose();
    _divisaCtrl.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    final c = await Cache.leer();
    if (c != null && mounted) setState(() => _oficial = c);
    await _cargar();
  }

  Future<void> _cargar() async {
    if (_cargando) return;
    setState(() {
      _cargando = true;
      _aviso = null;
      _detalle = null;
    });
    try {
      final o = await TasaServicio.obtener();
      Cache.guardar(o);
      if (!mounted) return;
      setState(() {
        _oficial = o;
        _recalcular();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aviso = _oficial == null
            ? 'No se pudo obtener la tasa.'
            : 'Sin conexión: mostrando la última tasa guardada.';
        _detalle = e.toString();
      });
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  // ---- Lógica -------------------------------------------------------------
  double? get _oficialActual => _fuente == Fuente.usd ? _oficial?.usd : _oficial?.eur;
  double? get _tasa => _custom ?? _oficialActual;
  String get _simbolo => _fuente == Fuente.usd ? 'USD' : 'EUR';

  void _recalcular() {
    final t = _tasa;
    if (t == null || t <= 0) return;
    if (_editadoBs) {
      final bs = _parsear(_bsCtrl.text);
      _divisaCtrl.text = bs == null ? '' : _input(bs / t);
    } else {
      final d = _parsear(_divisaCtrl.text);
      _bsCtrl.text = d == null ? '' : _input(d * t);
    }
  }

  void _cambiarFuente(Fuente f) {
    HapticFeedback.selectionClick();
    setState(() {
      _fuente = f;
      _custom = null;
      _tasaCtrl.clear();
      _recalcular();
    });
  }

  void _usarOficial() => setState(() {
        _custom = null;
        _tasaCtrl.clear();
        _recalcular();
      });

  void _limpiarMontos() => setState(() {
        _bsCtrl.clear();
        _divisaCtrl.clear();
      });

  void _copiar(String texto) {
    Clipboard.setData(ClipboardData(text: texto));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('Copiado'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ));
  }

  // ---- Formato ------------------------------------------------------------
  double? _parsear(String texto) {
    var t = texto.trim().replaceAll(' ', '');
    if (t.isEmpty) return null;
    if (t.contains(',')) t = t.replaceAll('.', '').replaceAll(',', '.');
    return double.tryParse(t);
  }

  String _input(double v, [int dec = 2]) => v.toStringAsFixed(dec).replaceAll('.', ',');

  String _formato(double v, {int dec = 2}) {
    final partes = v.toStringAsFixed(dec).split('.');
    final entero = partes[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
    return dec == 0 ? entero : '$entero,${partes[1]}';
  }

  String _fecha(DateTime? d) {
    if (d == null) return '';
    String dos(int n) => n.toString().padLeft(2, '0');
    return '${dos(d.day)}/${dos(d.month)}/${d.year}';
  }

  // ---- UI -----------------------------------------------------------------
  InputDecoration _deco(String label, String sufijo, {String? hint, String? helper, Widget? icono}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      suffixText: sufijo,
      suffixIcon: icono,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _campoMonto(TextEditingController c, String label, String sufijo, bool esBs) {
    return TextField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      style: Theme.of(context).textTheme.headlineSmall,
      onChanged: (_) => setState(() {
        _editadoBs = esBs;
        _recalcular();
      }),
      decoration: _deco(
        label,
        sufijo,
        icono: c.text.isEmpty
            ? null
            : Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'Copiar',
                  icon: const Icon(Icons.copy, size: 20),
                  onPressed: () => _copiar(c.text),
                ),
                IconButton(
                  tooltip: 'Limpiar',
                  icon: const Icon(Icons.clear),
                  onPressed: _limpiarMontos,
                ),
              ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sutil = Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.outline);
    final oficial = _oficialActual;
    final esCustom = _custom != null;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Conversor BCV'),
          actions: [
            IconButton(
              tooltip: 'Actualizar tasa',
              onPressed: _cargando ? null : _cargar,
              icon: _cargando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _cargar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                // Tasa oficial (cita sutil)
                Text('Tasa oficial', style: sutil),
                Text('USD:  ${_oficial == null ? '—' : _formato(_oficial!.usd, dec: 4)}',
                    style: sutil),
                Text('EUR:  ${_oficial == null ? '—' : _formato(_oficial!.eur, dec: 4)}',
                    style: sutil),
                if (_oficial?.fecha != null)
                  Text(_fecha(_oficial!.fecha), style: sutil?.copyWith(fontSize: 12)),

                if (_aviso != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    elevation: 0,
                    color: cs.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.wifi_off, size: 18, color: cs.onErrorContainer),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_aviso!, style: TextStyle(color: cs.onErrorContainer)),
                            ),
                            TextButton(onPressed: _cargar, child: const Text('Reintentar')),
                          ]),
                          if (_detalle != null)
                            SelectableText(
                              _detalle!,
                              style: TextStyle(color: cs.onErrorContainer, fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // Campo 1: elegir tasa
                SegmentedButton<Fuente>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: Fuente.usd, label: Text('USD')),
                    ButtonSegment(value: Fuente.eur, label: Text('EUR')),
                  ],
                  selected: {_fuente},
                  onSelectionChanged: (s) => _cambiarFuente(s.first),
                ),
                const SizedBox(height: 12),

                // Tasa: placeholder = oficial; si el usuario escribe, es personalizada
                TextField(
                  controller: _tasaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                  style: Theme.of(context).textTheme.titleLarge,
                  onChanged: (t) => setState(() {
                    final v = _parsear(t);
                    _custom = (v != null && v > 0) ? v : null;
                    _recalcular();
                  }),
                  decoration: _deco(
                    esCustom ? 'Tasa personalizada' : 'Tasa $_simbolo',
                    'Bs',
                    hint: oficial == null ? null : _formato(oficial, dec: 4),
                    helper: esCustom
                        ? 'Usando tu tasa. Toca ✕ para volver a la oficial.'
                        : 'Escribe aquí para usar otra tasa.',
                    icono: _tasaCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Usar tasa oficial',
                            icon: const Icon(Icons.clear),
                            onPressed: _usarOficial,
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // Campo 2: Bs
                _campoMonto(_bsCtrl, 'Monto en Bs', 'Bs', true),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Icon(Icons.swap_vert, color: cs.outline),
                ),

                // Campo 3: USD / EUR
                _campoMonto(_divisaCtrl, 'Monto en $_simbolo', _simbolo, false),
              ],
            ),
          ),
        ),
      ),
    );
  }
}