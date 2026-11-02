// Hoja para registrar o editar un movimiento. Si la fecha no es hoy, busca la
// tasa de ese día (BCV y paralelo); siempre se puede corregir a mano.
import 'package:flutter/material.dart';

import '../../core/formato.dart';
import '../../core/hora_venezuela.dart';
import '../../core/tema.dart';
import '../../core/widgets/campo_numerico.dart';
import '../../core/widgets/dialogos.dart';
import '../finanzas/finanzas_controller.dart';
import '../finanzas/modelos.dart';
import '../tasas/tasas_historicas.dart';
import 'movimiento.dart';

class MovimientoForm extends StatefulWidget {
  const MovimientoForm({super.key, required this.c, this.editar});

  final FinanzasController c;
  final Movimiento? editar;

  @override
  State<MovimientoForm> createState() => _MovimientoFormState();
}

class _MovimientoFormState extends State<MovimientoForm> {
  FinanzasController get c => widget.c;

  TipoMov tipo = TipoMov.gasto;
  final montoCtrl = TextEditingController();
  final bcvCtrl = TextEditingController();
  final parCtrl = TextEditingController();
  final etiquetaCtrl = TextEditingController();
  final notaCtrl = TextEditingController();
  Cuenta? cuenta;
  late DateTime fecha;
  late TimeOfDay hora;
  bool ajustar = true;
  bool cargando = false;
  String? aviso;
  String? error;

  Cuenta? _buscar(String id) {
    for (final x in c.cuentas) {
      if (x.id == id) return x;
    }
    return null;
  }

  bool _esHoy(DateTime d) {
    final n = hoyVzla();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  Color _color(Moneda m) => switch (m) {
        Moneda.bs => Paleta.bs,
        Moneda.usd => Paleta.usd,
        Moneda.usdt => Paleta.usdt,
      };

  @override
  void initState() {
    super.initState();
    final e = widget.editar;
    final ahora = DateTime.now();
    if (e != null) {
      tipo = e.tipo;
      montoCtrl.text = paraCampo(e.monto);
      bcvCtrl.text = e.bcv > 0 ? paraCampo(e.bcv, 4) : '';
      parCtrl.text = e.paralelo == null ? '' : paraCampo(e.paralelo!, 4);
      etiquetaCtrl.text = e.etiqueta ?? '';
      notaCtrl.text = e.nota ?? '';
      fecha = DateTime(e.momento.year, e.momento.month, e.momento.day);
      hora = TimeOfDay(hour: e.momento.hour, minute: e.momento.minute);
      ajustar = e.ajustoSaldo;
      cuenta = _buscar(e.cuentaId) ?? (c.cuentas.isEmpty ? null : c.cuentas.first);
    } else {
      fecha = DateTime(ahora.year, ahora.month, ahora.day);
      hora = TimeOfDay.fromDateTime(ahora);
      cuenta = c.cuentas.isEmpty ? null : c.cuentas.first;
      _cargarTasas();
    }
  }

  @override
  void dispose() {
    montoCtrl.dispose();
    bcvCtrl.dispose();
    parCtrl.dispose();
    etiquetaCtrl.dispose();
    notaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarTasas() async {
    final f = fecha;
    setState(() {
      cargando = true;
      aviso = null;
    });
    double? b, p;
    if (_esHoy(f)) {
      b = c.bcv;
      p = c.paralelo;
    }
    if (b == null || p == null) {
      final r = await TasasHistoricas.instancia.deDia(f);
      b ??= r.bcv;
      p ??= r.paralelo;
    }
    if (!mounted || f != fecha) return; // cambió la fecha mientras se consultaba
    setState(() {
      cargando = false;
      bcvCtrl.text = b == null ? '' : paraCampo(b, 4);
      parCtrl.text = p == null ? '' : paraCampo(p, 4);
      aviso = b == null
          ? 'No encontré la tasa de ese día. Escríbela tú.'
          : 'Tasas tomadas del historial para el ${fechaCorta(f)}. Puedes corregirlas.';
    });
  }

  Future<void> _elegirFecha() async {
    final r = await showDatePicker(
      context: context,
      initialDate: fecha,
      firstDate: DateTime(2018),
      lastDate: DateTime.now(),
    );
    if (r == null) return;
    setState(() {
      fecha = DateTime(r.year, r.month, r.day);
      ajustar = _esHoy(fecha); // un movimiento pasado normalmente ya está en tu saldo
    });
    _cargarTasas();
  }

  Future<void> _elegirHora() async {
    final r = await showTimePicker(context: context, initialTime: hora);
    if (r != null) setState(() => hora = r);
  }

  void _guardar() {
    final cu = cuenta;
    final monto = parsear(montoCtrl.text);
    final bcv = parsear(bcvCtrl.text);
    final par = parsear(parCtrl.text);
    if (cu == null) {
      setState(() => error = 'Elige una cuenta.');
      return;
    }
    if (monto == null || monto <= 0) {
      setState(() => error = 'Escribe un monto mayor a 0.');
      return;
    }
    if (!cu.moneda.esDolar && (bcv == null || bcv <= 0)) {
      setState(() => error = 'Falta la tasa BCV de ese día.');
      return;
    }
    final et = etiquetaCtrl.text.trim();
    final nota = notaCtrl.text.trim();
    c.guardarMovimiento(
      Movimiento(
        id: widget.editar?.id ?? c.nuevoId(),
        momento: DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute),
        tipo: tipo,
        cuentaId: cu.id,
        cuentaNombre: cu.nombre,
        moneda: cu.moneda,
        monto: monto,
        bcv: (bcv != null && bcv > 0) ? bcv : 0,
        paralelo: (par != null && par > 0) ? par : null,
        etiqueta: et.isEmpty ? null : et,
        nota: nota.isEmpty ? null : nota,
        ajustoSaldo: ajustar,
      ),
      anterior: widget.editar,
    );
    Navigator.pop(context);
  }

  Future<void> _eliminar() async {
    final e = widget.editar!;
    final msg = e.ajustoSaldo
        ? '¿Eliminar este movimiento? También se revertirá el cambio en el saldo de ${e.cuentaNombre}.'
        : '¿Eliminar este movimiento?';
    if (await confirmar(context, msg)) {
      c.eliminarMovimiento(e);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final cu = cuenta;
    final monto = parsear(montoCtrl.text);
    final b = parsear(bcvCtrl.text);
    final p = parsear(parCtrl.text);
    final colorTipo = tipo.esGasto ? Paleta.baja : Paleta.sube;

    String? equivalente;
    if (cu != null && !cu.moneda.esDolar && monto != null && b != null && b > 0) {
      equivalente = '≈ ${paraMostrar(monto / b)} \$ a BCV'
          '${(p != null && p > 0) ? '  ·  ${paraMostrar(monto / p)} \$ a paralelo' : ''}';
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            widget.editar == null ? 'Nuevo movimiento' : 'Editar movimiento',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          SegmentedButton<TipoMov>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: TipoMov.gasto, label: Text('Gasto'), icon: Icon(Icons.north_east)),
              ButtonSegment(
                  value: TipoMov.ingreso, label: Text('Ingreso'), icon: Icon(Icons.south_west)),
            ],
            selected: {tipo},
            onSelectionChanged: (s) => setState(() => tipo = s.first),
          ),
          const SizedBox(height: 12),
          if (c.cuentas.isEmpty)
            const Text('Primero agrega una cuenta en la pestaña Finanzas.')
          else ...[
            CampoNumerico(
              controller: montoCtrl,
              label: 'Monto',
              sufijo: cu?.moneda.etiqueta,
              autoenfocar: widget.editar == null,
              icono: tipo.esGasto ? Icons.north_east : Icons.south_west,
              color: colorTipo,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            Text('Cuenta', style: tt.labelLarge),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final x in c.cuentas)
                ChoiceChip(
                  avatar: Icon(Icons.circle, size: 12, color: _color(x.moneda)),
                  label: Text('${x.nombre} (${x.moneda.etiqueta})'),
                  selected: cuenta?.id == x.id,
                  onSelected: (_) => setState(() => cuenta = x),
                ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(fechaCorta(fecha)),
                  onPressed: _elegirFecha,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(hora.format(context)),
                  onPressed: _elegirHora,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.history_toggle_off, size: 18, color: cs.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Tasas del ${fechaCorta(fecha)}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                    if (cargando)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: CampoNumerico(
                        controller: bcvCtrl,
                        label: 'BCV',
                        sufijo: 'Bs',
                        decimales: 4,
                        estilo: tt.titleMedium,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: CampoNumerico(
                        controller: parCtrl,
                        label: 'Paralelo',
                        sufijo: 'Bs',
                        decimales: 4,
                        estilo: tt.titleMedium,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ]),
                  if (aviso != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(aviso!, style: TextStyle(fontSize: 12, color: cs.outline)),
                    ),
                  if (equivalente != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(equivalente, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: etiquetaCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Etiqueta (opcional)',
                prefixIcon: const Icon(Icons.label_outline),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final s in c.etiquetasSugeridasMov)
                ActionChip(
                  label: Text(s),
                  onPressed: () => setState(() {
                    etiquetaCtrl.text = s;
                    etiquetaCtrl.selection = TextSelection.collapsed(offset: s.length);
                  }),
                ),
            ]),
            const SizedBox(height: 12),
            TextField(
              controller: notaCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nota (opcional)',
                prefixIcon: const Icon(Icons.notes),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Actualizar el saldo de la cuenta'),
              subtitle: Text(ajustar
                  ? 'El saldo de ${cu?.nombre ?? 'la cuenta'} ${tipo.esGasto ? 'bajará' : 'subirá'}'
                      '${monto == null ? '' : ' ${paraMostrar(monto)} ${cu?.moneda.etiqueta ?? ''}'}.'
                  : 'Solo queda en el historial; el saldo no cambia.'),
              value: ajustar,
              onChanged: (v) => setState(() => ajustar = v),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(error!, style: TextStyle(color: cs.error)),
              ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: colorTipo,
              ),
              icon: const Icon(Icons.check),
              label: Text(widget.editar == null ? 'Guardar movimiento' : 'Guardar cambios'),
              onPressed: _guardar,
            ),
            if (widget.editar != null)
              TextButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Eliminar movimiento'),
                onPressed: _eliminar,
              ),
          ],
        ]),
      ),
    );
  }
}
