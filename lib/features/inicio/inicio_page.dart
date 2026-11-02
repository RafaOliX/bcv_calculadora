// Contenedor con la barra de navegación inferior. Crea el controlador de
// finanzas una sola vez y lo comparte entre Finanzas y Movimientos.
import 'package:flutter/material.dart';

import '../../core/hora_venezuela.dart';
import '../conversor/conversor_page.dart';
import '../finanzas/finanzas_controller.dart';
import '../finanzas/finanzas_page.dart';
import '../finanzas/finanzas_repositorio.dart';
import '../movimientos/movimientos_page.dart';
import '../tasas/tasas_repositorio.dart';

class InicioPage extends StatefulWidget {
  const InicioPage({super.key});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> with WidgetsBindingObserver {
  int _i = 0;
  late final FinanzasController fin =
      FinanzasController(FinanzasRepositorio(), TasasRepositorio());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    fin.dispose();
    super.dispose();
  }

  // Al volver a la app: si cambió el día en Venezuela, toma la tasa que ya rige.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) RelojVzla.instancia.alReanudar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _i,
        children: [const ConversorPage(), FinanzasPage(c: fin), MovimientosPage(c: fin)],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (i) => setState(() => _i = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.currency_exchange), label: 'Conversor'),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Finanzas',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Movimientos',
          ),
        ],
      ),
    );
  }
}
