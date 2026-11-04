import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/route_names.dart';

class RiderShellScreen extends ConsumerWidget {
  final Widget child;

  const RiderShellScreen({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(RouteNames.riderDeliveries)) return 1;
    if (location.startsWith(RouteNames.riderCod)) return 2;
    return 0; // Dashboard
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(RouteNames.riderDashboard);
        break;
      case 1:
        context.go(RouteNames.riderDeliveries);
        break;
      case 2:
        context.go(RouteNames.riderCod);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedIndex = _calculateSelectedIndex(context);

    return PopScope(
      canPop: selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (selectedIndex != 0) {
          _onItemTapped(0, context);
        }
      },
      child: Scaffold(
        body: child,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121722) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark
                    ? const Color(0xFF262E3D)
                    : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (idx) => _onItemTapped(idx, context),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.two_wheeler_outlined),
                selectedIcon: Icon(Icons.two_wheeler_rounded),
                label: 'Duty Hub',
              ),
              NavigationDestination(
                icon: Icon(Icons.route_outlined),
                selectedIcon: Icon(Icons.route_rounded),
                label: 'Tasks',
              ),
              NavigationDestination(
                icon: Icon(Icons.monetization_on_outlined),
                selectedIcon: Icon(Icons.monetization_on_rounded),
                label: 'COD Ledger',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
