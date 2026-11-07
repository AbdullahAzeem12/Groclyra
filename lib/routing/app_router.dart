import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'route_names.dart';
import '../features/auth/domain/entities/user_entity.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/presentation/screens/splash_screen.dart';
import '../features/auth/presentation/screens/onboarding_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/auth/presentation/screens/registration_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/auth/presentation/screens/email_verification_screen.dart';
import '../features/auth/presentation/screens/account_pending_screen.dart';
import '../features/auth/presentation/screens/otp_verification_screen.dart';
import '../features/auth/presentation/screens/unauthorized_screen.dart';
import '../features/auth/presentation/screens/role_selection_switch_screen.dart';
import '../features/auth/presentation/screens/rider_location_picker_screen.dart';

// Customer Screens
import '../features/customer/customer_shell_screen.dart';
import '../features/customer/home/presentation/screens/customer_home_screen.dart';
import '../features/customer/categories/presentation/screens/categories_catalog_screen.dart';
import '../features/customer/search/presentation/screens/search_discovery_screen.dart';
import '../features/customer/product_details/presentation/screens/product_details_screen.dart';
import '../features/catalog/domain/entities/category_entity.dart';
import '../features/catalog/domain/entities/product_entity.dart';
import '../features/customer/cart/domain/entities/cart_item_entity.dart';
import '../features/customer/cart/presentation/screens/cart_screen.dart';
import '../features/customer/checkout/presentation/screens/checkout_screen.dart';
import '../features/customer/orders/presentation/screens/orders_history_screen.dart';
import '../features/customer/tracking/presentation/screens/live_order_tracking_screen.dart';
import '../features/customer/profile/presentation/screens/customer_profile_screen.dart';
import '../features/customer/profile/presentation/screens/edit_profile_screen.dart';
import '../features/customer/addresses/presentation/screens/saved_addresses_screen.dart';
import '../features/customer/addresses/presentation/screens/add_edit_address_screen.dart';
import '../features/customer/addresses/domain/entities/delivery_address_entity.dart';
import '../features/customer/wishlist/presentation/screens/wishlist_screen.dart';
import '../features/customer/notifications/presentation/screens/notification_center_screen.dart';
import '../features/customer/support/presentation/screens/ai_customer_support_screen.dart';

// Seller Screens
import '../features/seller/seller_shell_screen.dart';
import '../features/seller/dashboard/presentation/screens/seller_dashboard_screen.dart';
import '../features/seller/products/presentation/screens/seller_product_list_screen.dart';
import '../features/seller/products/presentation/screens/add_product_wizard_screen.dart';
import '../features/seller/inventory/presentation/screens/inventory_management_screen.dart';
import '../features/seller/orders/presentation/screens/seller_orders_fulfillment_screen.dart';
import '../features/seller/profile/presentation/screens/seller_profile_screen.dart';

// Rider Screens
import '../features/rider/rider_shell_screen.dart';
import '../features/rider/dashboard/presentation/screens/rider_dashboard_screen.dart';
import '../features/rider/deliveries/presentation/screens/active_delivery_queue_screen.dart';
import '../features/rider/navigation/presentation/screens/rider_route_navigation_screen.dart';
import '../features/rider/proof_of_delivery/presentation/screens/pod_verification_screen.dart';
import '../features/rider/cod/presentation/screens/cod_cash_reconciliation_screen.dart';

// Admin Screens
import '../features/admin/admin_shell_screen.dart';
import '../features/admin/dashboard/presentation/screens/admin_dashboard_screen.dart';
import '../features/admin/sellers/presentation/screens/seller_kyc_approval_screen.dart';
import '../features/admin/riders/presentation/screens/rider_kyc_approval_screen.dart';
import '../features/admin/catalog/presentation/screens/catalog_moderation_screen.dart';
import '../features/admin/vendors/presentation/screens/vendor_integrations_screen.dart';
import '../features/admin/health/presentation/screens/system_health_telemetry_screen.dart';

// ─── Dedicated Navigator Keys for Shell & Root Routing ───────────────────────
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'rootNav',
);
final GlobalKey<NavigatorState> customerShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'customerShellNav');
final GlobalKey<NavigatorState> sellerShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'sellerShellNav');
final GlobalKey<NavigatorState> riderShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'riderShellNav');
final GlobalKey<NavigatorState> adminShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'adminShellNav');

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (previous?.isAuthenticated != next.isAuthenticated ||
          previous?.user?.id != next.user?.id ||
          previous?.user?.role != next.user?.role ||
          previous?.isPending != next.isPending) {
        notifyListeners();
      }
    });
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.read(routerNotifierProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouteNames.splash,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final loc = state.uri.toString();
      final isAuthRoute =
          loc == RouteNames.splash ||
          loc == RouteNames.onboarding ||
          loc == RouteNames.roleSelection ||
          loc == RouteNames.login ||
          loc == RouteNames.register ||
          loc == RouteNames.forgotPassword ||
          loc == RouteNames.emailVerification ||
          loc == RouteNames.accountPending ||
          loc == RouteNames.otp ||
          loc == RouteNames.unauthorized ||
          loc.startsWith(RouteNames.roleSelectionSwitch);

      if (loc == RouteNames.roleSelection) {
        return RouteNames.login;
      }

      if (!authState.isAuthenticated) {
        if (!isAuthRoute) return RouteNames.login;
        return null;
      }

      // Check account approval status
      if (authState.isPending) {
        if (loc != RouteNames.accountPending && !isAuthRoute) {
          return RouteNames.accountPending;
        }
      }

      final role = authState.user?.role;
      if (role == null) return null;

      // Hard Role Isolation Guards
      if (loc.startsWith('/seller') &&
          role != UserRole.seller &&
          role != UserRole.admin) {
        return RouteNames.unauthorized;
      }
      if (loc.startsWith('/rider') &&
          role != UserRole.rider &&
          role != UserRole.admin) {
        return RouteNames.unauthorized;
      }
      if (loc.startsWith('/admin') && role != UserRole.admin) {
        return RouteNames.unauthorized;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: RouteNames.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: RouteNames.roleSelection,
        redirect: (context, state) => RouteNames.login,
      ),
      GoRoute(
        path: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: RouteNames.register,
        builder: (context, state) => const RegistrationScreen(),
      ),
      GoRoute(
        path: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: RouteNames.emailVerification,
        builder: (context, state) => const EmailVerificationScreen(),
      ),
      GoRoute(
        path: RouteNames.accountPending,
        builder: (context, state) => const AccountPendingScreen(),
      ),
      GoRoute(
        path: RouteNames.otp,
        builder: (context, state) => const OtpVerificationScreen(),
      ),
      GoRoute(
        path: RouteNames.unauthorized,
        builder: (context, state) => const UnauthorizedScreen(),
      ),
      GoRoute(
        path: RouteNames.roleSelectionSwitch,
        builder: (context, state) {
          final roleString = state.uri.queryParameters['role'];
          final role = UserRole.fromString(roleString);
          return RoleSelectionSwitchScreen(targetRole: role);
        },
      ),
      GoRoute(
        path: RouteNames.riderLocationPicker,
        builder: (context, state) => const RiderLocationPickerScreen(),
      ),

      // 1. Customer Shell
      ShellRoute(
        navigatorKey: customerShellNavigatorKey,
        builder: (context, state, child) => CustomerShellScreen(child: child),
        routes: [
          GoRoute(
            path: RouteNames.customerHome,
            builder: (context, state) => const CustomerHomeScreen(),
          ),
          GoRoute(
            path: RouteNames.customerCategories,
            builder: (context, state) {
              final initialCategory = state.extra as MainCategoryType?;
              return CategoriesCatalogScreen(initialCategory: initialCategory);
            },
          ),
          GoRoute(
            path: RouteNames.customerSearch,
            builder: (context, state) => const SearchDiscoveryScreen(),
          ),
          GoRoute(
            path: RouteNames.customerCart,
            builder: (context, state) => const CartScreen(),
          ),
          GoRoute(
            path: RouteNames.customerOrders,
            builder: (context, state) => const OrdersHistoryScreen(),
          ),
          GoRoute(
            path: RouteNames.customerProfile,
            builder: (context, state) => const CustomerProfileScreen(),
          ),
        ],
      ),
      // Customer Subroutes (Outside bottom navigation shell, mounted to rootNavigatorKey)
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '${RouteNames.customerProductDetails}/:id',
        pageBuilder: (context, state) {
          final id = state.pathParameters['id'] ?? 'prod_crock_01';
          final product = state.extra is ProductEntity
              ? state.extra as ProductEntity
              : null;
          return MaterialPage<void>(
            key: ObjectKey(state),
            name: state.name ?? state.matchedLocation,
            child: ProductDetailsScreen(productId: id, initialProduct: product),
          );
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: RouteNames.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: RouteNames.customerCheckout,
        builder: (context, state) {
          final directItem = state.extra is CartItemEntity
              ? state.extra as CartItemEntity
              : null;
          return CheckoutScreen(directItem: directItem);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '${RouteNames.customerTracking}/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? 'ord_sample_9021';
          return LiveOrderTrackingScreen(orderId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: RouteNames.customerAddresses,
        builder: (context, state) => const SavedAddressesScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: RouteNames.customerAddressAddEdit,
        builder: (context, state) => AddEditAddressScreen(
          existingAddress: state.extra as DeliveryAddressEntity?,
        ),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: RouteNames.customerWishlist,
        builder: (context, state) => const WishlistScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: RouteNames.customerNotifications,
        builder: (context, state) => const NotificationCenterScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: RouteNames.customerSupport,
        builder: (context, state) => const AiCustomerSupportScreen(),
      ),

      // 2. Seller Shell
      ShellRoute(
        navigatorKey: sellerShellNavigatorKey,
        builder: (context, state, child) => SellerShellScreen(child: child),
        routes: [
          GoRoute(
            path: RouteNames.sellerDashboard,
            builder: (context, state) => const SellerDashboardScreen(),
          ),
          GoRoute(
            path: RouteNames.sellerProducts,
            builder: (context, state) => const SellerProductListScreen(),
          ),
          GoRoute(
            path: RouteNames.sellerInventory,
            builder: (context, state) => const InventoryManagementScreen(),
          ),
          GoRoute(
            path: RouteNames.sellerOrders,
            builder: (context, state) => const SellerOrdersFulfillmentScreen(),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: RouteNames.sellerAddProduct,
        builder: (context, state) => const AddProductWizardScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: RouteNames.sellerStore,
        builder: (context, state) => const SellerProfileScreen(),
      ),

      // 3. Rider Shell
      ShellRoute(
        navigatorKey: riderShellNavigatorKey,
        builder: (context, state, child) => RiderShellScreen(child: child),
        routes: [
          GoRoute(
            path: RouteNames.riderDashboard,
            builder: (context, state) => const RiderDashboardScreen(),
          ),
          GoRoute(
            path: RouteNames.riderDeliveries,
            builder: (context, state) => const ActiveDeliveryQueueScreen(),
          ),
          GoRoute(
            path: RouteNames.riderCod,
            builder: (context, state) => const CodCashReconciliationScreen(),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '${RouteNames.riderNavigate}/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? 'task_01';
          return RiderRouteNavigationScreen(taskId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: '${RouteNames.riderPod}/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? 'task_01';
          return PodVerificationScreen(taskId: id);
        },
      ),

      // 4. Admin Shell
      ShellRoute(
        navigatorKey: adminShellNavigatorKey,
        builder: (context, state, child) => AdminShellScreen(child: child),
        routes: [
          GoRoute(
            path: RouteNames.adminDashboard,
            builder: (context, state) => const AdminDashboardScreen(),
          ),
          GoRoute(
            path: RouteNames.adminKyc,
            builder: (context, state) => const SellerKycApprovalScreen(),
          ),
          GoRoute(
            path: RouteNames.adminRiderKyc,
            builder: (context, state) => const RiderKycApprovalScreen(),
          ),
          GoRoute(
            path: RouteNames.adminCatalog,
            builder: (context, state) => const CatalogModerationScreen(),
          ),
          GoRoute(
            path: RouteNames.adminVendors,
            builder: (context, state) => const VendorIntegrationsScreen(),
          ),
          GoRoute(
            path: RouteNames.adminTelemetry,
            builder: (context, state) => const SystemHealthTelemetryScreen(),
          ),
        ],
      ),
    ],
  );
});
