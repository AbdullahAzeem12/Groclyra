import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/route_names.dart';

class AdminShellScreen extends ConsumerWidget {
  final Widget child;

  const AdminShellScreen({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(RouteNames.adminKyc) ||
        location.startsWith(RouteNames.adminRiderKyc)) {
      return 1;
    }
    if (location.startsWith(RouteNames.adminCatalog)) {
      return 2;
    }
    if (location.startsWith(RouteNames.adminVendors)) {
      return 3;
    }
    if (location.startsWith(RouteNames.adminTelemetry)) {
      return 4;
    }
    return 0; // Dashboard
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(RouteNames.adminDashboard);
        break;
      case 1:
        context.go(RouteNames.adminKyc);
        break;
      case 2:
        context.go(RouteNames.adminCatalog);
        break;
      case 3:
        context.go(RouteNames.adminVendors);
        break;
      case 4:
        context.go(RouteNames.adminTelemetry);
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
                icon: Icon(Icons.analytics_outlined),
                selectedIcon: Icon(Icons.analytics_rounded),
                label: 'Platform',
              ),
              NavigationDestination(
                icon: Icon(Icons.verified_user_outlined),
                selectedIcon: Icon(Icons.verified_user_rounded),
                label: 'KYC Queue',
              ),
              NavigationDestination(
                icon: Icon(Icons.checklist_rtl_rounded),
                selectedIcon: Icon(Icons.checklist_rtl_rounded),
                label: 'Catalog Mod',
              ),
              NavigationDestination(
                icon: Icon(Icons.hub_outlined),
                selectedIcon: Icon(Icons.hub_rounded),
                label: 'Live Marts',
              ),
              NavigationDestination(
                icon: Icon(Icons.monitor_heart_outlined),
                selectedIcon: Icon(Icons.monitor_heart_rounded),
                label: 'Telemetry',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
