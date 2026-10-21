// Punto único de acceso a las tasas. Las pantallas no saben si vienen de la
// red o del caché; mañana aquí se guardará también el historial diario.
import 'oficial.dart';
import 'tasa_cache.dart';
import 'tasa_servicio.dart';

class TasasRepositorio {
  Future<Oficial?> leerGuardada() => TasaCache.leer();

  Future<double?> paralelo() => TasaServicio.paralelo();

  Future<Oficial> actualizar() async {
    final o = await TasaServicio.obtener();
    await TasaCache.guardar(o);
    return o;
  }
}
