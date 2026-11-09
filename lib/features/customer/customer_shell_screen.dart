import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/services/in_app_notification_alert_service.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/features/customer/cart/presentation/controllers/cart_controller.dart';

class CustomerShellScreen extends ConsumerStatefulWidget {
  final Widget child;

  const CustomerShellScreen({super.key, required this.child});

  @override
  ConsumerState<CustomerShellScreen> createState() => _CustomerShellScreenState();
}

class _CustomerShellScreenState extends ConsumerState<CustomerShellScreen> {
  String? _listeningUserId;

  @override
  void initState() {
    super.initState();
    InAppNotificationAlertService.instance.init();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNotificationListener();
    });
  }

  void _setupNotificationListener() {
    final user = ref.read(authControllerProvider).user;
    if (user != null && user.id.isNotEmpty && _listeningUserId != user.id) {
      _listeningUserId = user.id;
      InAppNotificationAlertService.instance.startListening(context, user.id);
    }
  }

  @override
  void dispose() {
    InAppNotificationAlertService.instance.stop();
    super.dispose();
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.toString();
    if (location.startsWith(RouteNames.customerCategories)) return 1;
    if (location.startsWith(RouteNames.customerSearch)) return 2;
    if (location.startsWith(RouteNames.customerCart)) return 3;
    if (location.startsWith(RouteNames.customerOrders)) return 4;
    if (location.startsWith(RouteNames.customerProfile)) return 5;
    return 0; // Home
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(RouteNames.customerHome);
        break;
      case 1:
        context.go(RouteNames.customerCategories);
        break;
      case 2:
        context.go(RouteNames.customerSearch);
        break;
      case 3:
        context.go(RouteNames.customerCart);
        break;
      case 4:
        context.go(RouteNames.customerOrders);
        break;
      case 5:
        context.go(RouteNames.customerProfile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (prev, next) {
      final user = next.user;
      if (user != null && user.id.isNotEmpty && _listeningUserId != user.id) {
        _listeningUserId = user.id;
        InAppNotificationAlertService.instance.startListening(context, user.id);
      }
    });

    final cartState = ref.watch(cartControllerProvider);
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
        body: widget.child,
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (idx) => _onItemTapped(idx, context),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront_rounded),
                label: 'Shop',
              ),
              const NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: 'Catalog',
              ),
              const NavigationDestination(
                icon: Icon(Icons.search_rounded),
                selectedIcon: Icon(Icons.search_rounded),
                label: 'Search',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: cartState.totalItemCount > 0,
                  label: Text(cartState.totalItemCount.toString()),
                  child: const Icon(Icons.shopping_bag_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: cartState.totalItemCount > 0,
                  label: Text(cartState.totalItemCount.toString()),
                  child: const Icon(Icons.shopping_bag_rounded),
                ),
                label: 'Cart',
              ),
              const NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Orders',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Account',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
