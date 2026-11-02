// Plantillas CSV de ejemplo: así deben verse los datos para importarlos.
import '../../core/csv.dart';

/// Historial de saldos: una fila por cierre. Cada cuenta es una columna;
/// entre paréntesis va su moneda: (Bs), (USD) o (USDT).
String plantillaHistorial() => escribirCsv([
      [
        'Fecha', 'Hora', 'Etiqueta', 'Tasa BCV', 'Tasa paralelo',
        'Provincial (Bs)', 'Bancamiga Bs (Bs)', 'Bancamiga \$ (USD)', 'Efectivo \$ (USD)', 'Binance (USDT)',
      ],
      ['20/10/2026', '08:00', 'Inicio de semana', '881,87', '988', '54870,51', '5818', '0,21', '10', '0'],
      ['21/10/2026', '20:30', 'Salida con amigos', '883,40', '990', '50120', '5818', '0,21', '10', '0'],
    ]);

/// Movimientos: una fila por gasto o ingreso. Si dejas vacías las tasas, la app
/// busca la de cada fecha. Tipo: Gasto o Ingreso. Moneda: Bs, USD o USDT.
String plantillaMovimientos() => escribirCsv([
      [
        'Fecha', 'Hora', 'Tipo', 'Etiqueta', 'Cuenta', 'Moneda', 'Monto',
        'Tasa BCV', 'Tasa paralelo', 'Nota',
      ],
      ['20/10/2026', '18:30', 'Gasto', 'Comida', 'Provincial', 'Bs', '1250,50', '', '', 'Almuerzo'],
      ['21/10/2026', '09:00', 'Ingreso', 'Sueldo', 'Bancamiga \$', 'USD', '150', '', '', 'Quincena'],
      ['22/10/2026', '21:15', 'Gasto', 'Salida con amigos', 'Efectivo \$', 'USD', '12', '', '', ''],
    ]);
