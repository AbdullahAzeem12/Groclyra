class RouteNames {
  // Auth & Onboarding
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String roleSelection = '/role-selection';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String emailVerification = '/email-verification';
  static const String accountPending = '/account-pending';
  static const String otp = '/otp';
  static const String unauthorized = '/unauthorized';
  static const String roleSelectionSwitch = '/role-selection-switch';
  static const String riderLocationPicker = '/rider-location-picker';

  // Customer Shell
  static const String customerHome = '/customer';
  static const String customerCategories = '/customer/categories';
  static const String customerSearch = '/customer/search';
  static const String customerCart = '/customer/cart';
  static const String customerCheckout = '/customer/checkout';
  static const String customerOrders = '/customer/orders';
  static const String customerTracking = '/customer/tracking';
  static const String customerProductDetails = '/customer/product';
  static const String customerProfile = '/customer/profile';
  static const String editProfile = '/customer/profile/edit';
  static const String customerAddresses = '/customer/addresses';
  static const String customerAddressAddEdit = '/customer/addresses/edit';
  static const String customerWishlist = '/customer/wishlist';
  static const String customerNotifications = '/customer/notifications';
  static const String customerSupport = '/customer/support';
  static const String security2fa = '/customer/security/2fa';
  static const String deviceSessions = '/customer/security/sessions';
  static const String databaseBackup = '/customer/security/backup';

  // Seller Shell
  static const String sellerDashboard = '/seller';
  static const String sellerProducts = '/seller/products';
  static const String sellerAddProduct = '/seller/add-product';
  static const String sellerInventory = '/seller/inventory';
  static const String sellerOrders = '/seller/orders';
  static const String sellerAnalytics = '/seller/analytics';
  static const String sellerStore = '/seller/store';

  // Rider Shell
  static const String riderDashboard = '/rider';
  static const String riderDeliveries = '/rider/deliveries';
  static const String riderNavigate = '/rider/navigate';
  static const String riderPod = '/rider/pod';
  static const String riderCod = '/rider/cod';
  static const String riderEarnings = '/rider/earnings';
  static const String riderScanner = '/rider/scanner';

  // Admin Shell
  static const String adminDashboard = '/admin';
  static const String adminKyc = '/admin/kyc';
  static const String adminRiderKyc = '/admin/kyc-riders';
  static const String adminCatalog = '/admin/catalog';
  static const String adminVendors = '/admin/vendors';
  static const String adminOrders = '/admin/orders';
  static const String adminTelemetry = '/admin/telemetry';
}
