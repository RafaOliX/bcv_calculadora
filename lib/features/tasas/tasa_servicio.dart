// Capa de red: obtiene las tasas del BCV (scraping) y, si falla, de dolarapi.
import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'oficial.dart';

class TasaServicio {
  static const _bcv = 'https://www.bcv.org.ve/';
  static const _apiUsd = 'https://ve.dolarapi.com/v1/dolares/oficial';
  static const _apiEur = 'https://ve.dolarapi.com/v1/euros/oficial';
  static const _apiParalelo = 'https://ve.dolarapi.com/v1/dolares/paralelo';
  static const _ua = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0 Safari/537.36';

  // "875,65050000" -> 875.6505
  static double _num(String s) =>
      double.parse(s.trim().replaceAll('.', '').replaceAll(',', '.'));

  static Future<Oficial> bcv() async {
    final io = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..userAgent = _ua
      // El BCV suele tener problemas de certificado: solo se tolera para su dominio.
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
      return Oficial(
        usd: leer('dolar'),
        eur: leer('euro'),
        fecha: f == null ? null : DateTime.tryParse(f),
      );
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
      usd: (datos[0]['promedio'] as num).toDouble(),
      eur: (datos[1]['promedio'] as num).toDouble(),
      fecha: f == null ? null : DateTime.tryParse(f),
    );
  }

  /// Tasa paralelo (mejor esfuerzo): devuelve null si no se puede obtener.
  static Future<double?> paralelo() async {
    try {
      final r = await http.get(Uri.parse(_apiParalelo)).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final v = (jsonDecode(r.body) as Map<String, dynamic>)['promedio'];
      return (v is num && v > 0) ? v.toDouble() : null;
    } catch (_) {
      return null;
    }
  }

  /// BCV primero; si falla, la API. Si ambos fallan, lanza el detalle de cada uno.
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
