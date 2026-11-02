// Punto único de acceso a las tasas. Sabe cuál rige HOY en Venezuela y cuál
// viene después, aunque el BCV ya haya publicado la del día siguiente.
import '../../core/hora_venezuela.dart';
import 'oficial.dart';
import 'tasa_cache.dart';
import 'tasa_servicio.dart';

class TasasRepositorio {
  /// La que rige hoy: la más reciente cuya fecha valor ya llegó. Si todas son
  /// futuras (primera vez, de noche), devuelve la más cercana.
  Oficial? _vigente(List<Oficial> lista) {
    if (lista.isEmpty) return null;
    final hoy = hoyVzla();
    Oficial? r;
    for (final o in lista) {
      if (!o.fecha!.isAfter(hoy)) r = o;
    }
    return r ?? lista.first;
  }

  Future<Oficial?> leerGuardada() async => _vigente(await TasaCache.leerTodas());

  /// La tasa ya publicada que empieza a regir en un día futuro, si hay.
  Future<Oficial?> proxima() async {
    final hoy = hoyVzla();
    for (final o in await TasaCache.leerTodas()) {
      if (o.fecha!.isAfter(hoy)) return o;
    }
    return null;
  }

  Future<double?> paralelo() => TasaServicio.paralelo();

  /// Consulta el BCV, guarda la tasa con su fecha valor y devuelve la que rige hoy.
  Future<Oficial> actualizar() async {
    final o = await TasaServicio.obtener();
    await TasaCache.guardar(o);
    return _vigente(await TasaCache.leerTodas()) ?? o;
  }
}
