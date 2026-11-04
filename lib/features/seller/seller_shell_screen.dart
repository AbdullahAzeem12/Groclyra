import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../routing/route_names.dart';

class SellerShellScreen extends ConsumerWidget {
  final Widget child;

  const SellerShellScreen({
    super.key,
    required this.child,
  });

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(RouteNames.sellerProducts)) return 1;
    if (location.startsWith(RouteNames.sellerInventory)) return 2;
    if (location.startsWith(RouteNames.sellerOrders)) return 3;
    return 0; // Dashboard
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(RouteNames.sellerDashboard);
        break;
      case 1:
        context.go(RouteNames.sellerProducts);
        break;
      case 2:
        context.go(RouteNames.sellerInventory);
        break;
      case 3:
        context.go(RouteNames.sellerOrders);
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
              top: BorderSide(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
            ),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (idx) => _onItemTapped(idx, context),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Overview',
              ),
              NavigationDestination(
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2_rounded),
                label: 'Products',
              ),
              NavigationDestination(
                icon: Icon(Icons.warehouse_outlined),
                selectedIcon: Icon(Icons.warehouse_rounded),
                label: 'Stock',
              ),
              NavigationDestination(
                icon: Icon(Icons.local_shipping_outlined),
                selectedIcon: Icon(Icons.local_shipping_rounded),
                label: 'Fulfillment',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
