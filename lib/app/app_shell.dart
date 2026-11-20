import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/session_controller.dart';
import '../features/auth/domain/account.dart';

/// Ramas de la barra inferior, en el orden en que se declaran en el router.
abstract final class ShellBranch {
  static const explore = 0;
  static const map = 1;
  static const myMerchant = 2;
  static const myEvents = 3;
}

class _Tab {
  const _Tab(this.branch, this.icon, this.selectedIcon, this.label);

  final int branch;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Barra de navegación inferior del Figma. Cada pestaña conserva su estado al cambiar de una a
/// otra (el mapa no se recarga). Las pestañas dependen del rol: la persona que descubre planes y
/// el comercio que los organiza ven secciones distintas.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _userTabs = [
    _Tab(ShellBranch.explore, Icons.explore_outlined, Icons.explore, 'Explorar'),
    _Tab(ShellBranch.map, Icons.place_outlined, Icons.place, 'Mapa'),
  ];

  static const _merchantTabs = [
    _Tab(ShellBranch.myEvents, Icons.event_note_outlined, Icons.event_note, 'Mis eventos'),
    _Tab(ShellBranch.map, Icons.place_outlined, Icons.place, 'Mapa'),
    _Tab(ShellBranch.myMerchant, Icons.storefront_outlined, Icons.storefront, 'Mi comercio'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(sessionControllerProvider.select((session) => session.value?.role));
    final tabs = role == Role.merchant ? _merchantTabs : _userTabs;
    final selected = tabs.indexWhere((tab) => tab.branch == navigationShell.currentIndex);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected < 0 ? 0 : selected,
        onDestinationSelected: (index) {
          final branch = tabs[index].branch;
          navigationShell.goBranch(branch, initialLocation: branch == navigationShell.currentIndex);
        },
        destinations: [
          for (final tab in tabs)
            NavigationDestination(icon: Icon(tab.icon), selectedIcon: Icon(tab.selectedIcon), label: tab.label),
        ],
      ),
    );
  }
}
