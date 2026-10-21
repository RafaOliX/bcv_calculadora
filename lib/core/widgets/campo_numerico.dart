// Campo de texto numérico reutilizable (tasas, montos, saldos...).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CampoNumerico extends StatelessWidget {
  const CampoNumerico({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.sufijo,
    this.hint,
    this.ayuda,
    this.acciones = const [],
    this.estilo,
    this.autoenfocar = false,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;
  final String? sufijo;
  final String? hint;
  final String? ayuda;
  final List<Widget> acciones;
  final TextStyle? estilo;
  final bool autoenfocar;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autoenfocar,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      style: estilo ?? Theme.of(context).textTheme.headlineSmall,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: ayuda,
        suffixText: sufijo,
        suffixIcon: acciones.isEmpty ? null : Row(mainAxisSize: MainAxisSize.min, children: acciones),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
