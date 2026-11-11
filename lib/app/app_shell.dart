import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Barra de navegación inferior del Figma. Cada pestaña conserva su estado al cambiar de una a
/// otra (el mapa no se recarga). «Mis planes» y «Perfil» se agregan con sus historias.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: navigationShell,
    bottomNavigationBar: NavigationBar(
      selectedIndex: navigationShell.currentIndex,
      onDestinationSelected: (index) =>
          navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Explorar'),
        NavigationDestination(icon: Icon(Icons.place_outlined), selectedIcon: Icon(Icons.place), label: 'Mapa'),
      ],
    ),
  );
}
