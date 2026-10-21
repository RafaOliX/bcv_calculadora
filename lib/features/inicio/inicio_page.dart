// Contenedor con la barra de navegación inferior.
import 'package:flutter/material.dart';

import '../conversor/conversor_page.dart';
import '../finanzas/finanzas_page.dart';

class InicioPage extends StatefulWidget {
  const InicioPage({super.key});

  @override
  State<InicioPage> createState() => _InicioPageState();
}

class _InicioPageState extends State<InicioPage> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _i,
        children: const [ConversorPage(), FinanzasPage()],
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
        ],
      ),
    );
  }
}
