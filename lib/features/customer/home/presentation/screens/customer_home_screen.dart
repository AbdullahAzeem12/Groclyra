import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/constants/app_colors.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';
import 'package:groclyra/shared/animations/staggered_list_animation.dart';
import 'package:groclyra/shared/widgets/badge_icon_button.dart';
import 'package:groclyra/shared/widgets/product_card_item.dart';
import 'package:groclyra/shared/widgets/theme_selector_bottom_sheet.dart';
import 'package:groclyra/shared/widgets/live_promo_banner_carousel.dart';
import 'package:groclyra/shared/widgets/live_deal_countdown_badge.dart';
import 'package:groclyra/features/catalog/domain/entities/category_entity.dart';
import 'package:groclyra/features/catalog/domain/entities/product_entity.dart';
import 'package:groclyra/features/catalog/data/repositories/catalog_repository.dart';
import 'package:groclyra/features/catalog/presentation/controllers/catalog_controller.dart';
import 'package:groclyra/features/admin/vendors/data/repositories/vendor_catalog_repository.dart';
import 'package:groclyra/features/customer/cart/presentation/controllers/cart_controller.dart';
import 'package:groclyra/features/notifications/presentation/widgets/notification_center_sheet.dart';
import 'package:groclyra/features/customer/addresses/presentation/controllers/address_controller.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';

class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  MainCategoryType? _activePillar;
  MainCategoryType? _selectedDealCategory;
  String? _selectedVendorId;
  String? _selectedVendorName;
  final TextEditingController _homeSearchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _homeSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final allProductsAsync = ref.watch(allProductsStreamProvider);
    final categoriesAsync = ref.watch(categoriesStreamProvider);
    final flashDealsAsync = ref.watch(flashDealsStreamProvider);
    final cartState = ref.watch(cartControllerProvider);
    final integrationsAsync = ref.watch(vendorIntegrationsStreamProvider);
    final vendors = integrationsAsync.value ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allProducts = allProductsAsync.value ?? [];
    final categories = categoriesAsync.value ?? [];
    final flashDeals = flashDealsAsync.value ?? [];

    final addressState = ref.watch(addressControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final defaultAddr = addressState.defaultAddress;
    final user = authState.user;

    // Build location words and coordinates
    final String addressTitle;
    final String coordsSubtitle;
    if (defaultAddr != null) {
      if (defaultAddr.houseOrFlat.isNotEmpty && defaultAddr.societyOrScheme != null && defaultAddr.societyOrScheme!.isNotEmpty) {
        addressTitle = '${defaultAddr.houseOrFlat} ${defaultAddr.societyOrScheme}, ${defaultAddr.city}';
      } else if (defaultAddr.shortDisplay.isNotEmpty) {
        addressTitle = '${defaultAddr.shortDisplay} • ${defaultAddr.label.displayName}';
      } else {
        addressTitle = defaultAddr.formattedAddress.isNotEmpty ? defaultAddr.formattedAddress : defaultAddr.city;
      }
      coordsSubtitle = '📍 ${defaultAddr.latitude.toStringAsFixed(4)}°N, ${defaultAddr.longitude.toStringAsFixed(4)}°E';
    } else if (user?.deliveryAddress?.isNotEmpty == true) {
      addressTitle = user!.deliveryAddress!;
      final loc = user.deliveryLocation;
      coordsSubtitle = (loc != null && loc.latitude != null && loc.longitude != null)
          ? '📍 ${loc.latitude!.toStringAsFixed(4)}°N, ${loc.longitude!.toStringAsFixed(4)}°E'
          : '📍 Tap to view or change pin';
    } else {
      addressTitle = 'Tap to Set Delivery Address';
      coordsSubtitle = '📍 Pakistan Wide Live Delivery Coverage';
    }

    var displayedProducts = _activePillar == null
        ? allProducts
        : allProducts.where((p) => p.categoryType == _activePillar).toList();

    if (_selectedVendorId != null) {
      displayedProducts = displayedProducts.where((p) {
        return p.sellerId == _selectedVendorId ||
            p.sourceVendorId == _selectedVendorId ||
            p.sellerName.toLowerCase().contains(_selectedVendorId!.toLowerCase());
      }).toList();
    }

    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase().trim();
      displayedProducts = displayedProducts.where((p) {
        return p.title.toLowerCase().contains(q) ||
            p.brand.toLowerCase().contains(q) ||
            p.categoryName.toLowerCase().contains(q) ||
            p.description.toLowerCase().contains(q) ||
            p.sellerName.toLowerCase().contains(q);
      }).toList();
    }

    // Compute aspect ratio so image+content always fits the grid cell on every
    // screen size. Content block height ~140dp (spec tag + title + rating + price).
    final sw = MediaQuery.of(context).size.width;
    const contentH = 140.0;
    // Grid: 16dp side padding each side = 32dp total, 12dp gap between columns
    final cardW = (sw - 32.0 - 12.0) / 2.0;
    final gridAspectRatio = cardW / (cardW / 1.1 + contentH);
    // Flash deals: fixed card width 170dp
    final flashListH = (170.0 / 1.1 + contentH + 8.0).ceilToDouble();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E17) : const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () => ref.read(catalogControllerProvider.notifier).loadCatalog(),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Custom Gradient Header Sliver
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 48, bottom: 20),
                decoration: BoxDecoration(
                  gradient: themeState.palette.linearGradient,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(AppDimensions.radiusLarge),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: themeState.palette.primaryColor.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Bar: Location & Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: SpringTouchScale(
                            onTap: () => context.push(RouteNames.customerAddresses),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Deliver To',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.8),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              addressTitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 18),
                                        ],
                                      ),
                                      Text(
                                        coordsSubtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.75),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Top Action Icons
                        Row(
                          children: [
                            const NotificationBellIconButton(
                              iconColor: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              tooltip: 'Gradient Themes',
                              icon: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.palette_outlined, color: Colors.white, size: 18),
                              ),
                              onPressed: () => ThemeSelectorBottomSheet.show(context),
                            ),
                            BadgeIconButton(
                              icon: Icons.shopping_bag_outlined,
                              count: cartState.totalItemCount,
                              onTap: () => context.go(RouteNames.customerCart),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Search Bar Box — High-contrast, pristine readable colors & transparent field
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.85),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.16),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.search_rounded, color: themeState.palette.primaryColor, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _homeSearchController,
                              decoration: const InputDecoration(
                                filled: false,
                                fillColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                hintText: 'Search Bone China, Basmati, Biryani, Milk...',
                                hintStyle: TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.normal,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _searchQuery = val;
                                });
                              },
                              onSubmitted: (val) {
                                context.push(RouteNames.customerSearch);
                              },
                            ),
                          ),
                          if (_searchQuery.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                              onPressed: () {
                                _homeSearchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                          else
                            IconButton(
                              icon: Icon(Icons.tune_rounded, color: themeState.palette.primaryColor, size: 18),
                              tooltip: 'Open Discovery Search',
                              onPressed: () => context.push(RouteNames.customerSearch),
                            ),
                        ],
                      ),
                    ),

                    // Quick Search Autocomplete Suggestions & Status Pill
                    if (_searchQuery.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                'Showing ${displayedProducts.length} matching products for "$_searchQuery"',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                _homeSearchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4.0),
                                child: Text(
                                  'Clear ✕',
                                  style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildQuickSearchPill(
                              label: 'Dinner Sets',
                              query: 'dinner',
                            ),
                            const SizedBox(width: 6),
                            _buildQuickSearchPill(
                              label: 'Basmati Rice',
                              query: 'rice',
                            ),
                            const SizedBox(width: 6),
                            _buildQuickSearchPill(
                              label: 'Olper\'s Milk',
                              query: 'milk',
                            ),
                            const SizedBox(width: 6),
                            _buildQuickSearchPill(
                              label: 'Crispy Burgers',
                              query: 'burger',
                            ),
                            const SizedBox(width: 6),
                            _buildQuickSearchPill(
                              label: 'Loaded Fries',
                              query: 'fries',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Auto-Sliding Real-Time Multi-Banner Carousel with Ads & Offers (Replaces Ramadan Mega Bazaar)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
                child: LivePromoBannerCarousel(
                  activePillar: _activePillar,
                  onBannerTap: (banner) {
                    if (banner.targetPillar != null) {
                      setState(() {
                        _activePillar = (_activePillar == banner.targetPillar) ? null : banner.targetPillar;
                        _selectedVendorId = null;
                        _selectedVendorName = null;
                      });
                    } else if (banner.promoCode != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('🎉 Promo code "${banner.promoCode}" active! Free delivery applies on Rs. 1,999+'),
                          backgroundColor: banner.gradientColors.first,
                          duration: const Duration(seconds: 3),
                          action: SnackBarAction(
                            label: 'View Cart',
                            textColor: Colors.amber,
                            onPressed: () => context.go(RouteNames.customerCart),
                          ),
                        ),
                      );
                    }
                  },
                ),
              ),
            ),

            // 4-Tab Pillar Switcher (Crockery / Grocery / Dairy & Bakery / Fast Food)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildPillarChip(
                        emoji: '🍽️', label: 'Crockery',
                        type: MainCategoryType.crockery,
                        activeColor: AppColors.crockeryPill, isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      _buildPillarChip(
                        emoji: '🛒', label: 'Grocery',
                        type: MainCategoryType.grocery,
                        activeColor: AppColors.groceryPill, isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      _buildPillarChip(
                        emoji: '🥛', label: 'Dairy & Bakery',
                        type: MainCategoryType.dairyBakery,
                        activeColor: const Color(0xFF10B981), isDark: isDark,
                      ),
                      const SizedBox(width: 10),
                      _buildPillarChip(
                        emoji: '🍔', label: 'Fast Food',
                        type: MainCategoryType.fastFood,
                        activeColor: const Color(0xFFFF6B35), isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Real-Time Verified Marts & Stores Strip
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: themeState.palette.linearGradient,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                          const Flexible(
                            child: Text(
                              'Verified Partner Marts & Stores',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.4), width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle, size: 8, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'Live Sync',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 110,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: vendors.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final vendor = vendors[index];
                    final isSelected = _selectedVendorId == vendor.vendorId;
                    final emoji = vendor.categoryType == MainCategoryType.crockery
                        ? '🍽️'
                        : vendor.categoryType == MainCategoryType.fastFood
                            ? '🍔'
                            : vendor.categoryType == MainCategoryType.dairyBakery
                                ? '🥖'
                                : '🛒';

                    return SpringTouchScale(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedVendorId = null;
                            _selectedVendorName = null;
                          } else {
                            _selectedVendorId = vendor.vendorId;
                            _selectedVendorName = vendor.vendorName.replaceAll(RegExp(r'\s*\([^)]*\)'), '');
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 170,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? themeState.palette.primaryColor.withValues(alpha: 0.12)
                              : (isDark ? const Color(0xFF181E2B) : Colors.white),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                          border: Border.all(
                            color: isSelected
                                ? themeState.palette.primaryColor
                                : (isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isSelected
                                  ? themeState.palette.primaryColor.withValues(alpha: 0.18)
                                  : Colors.black.withValues(alpha: 0.04),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(emoji, style: const TextStyle(fontSize: 22)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Verified', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green)),
                                ),
                              ],
                            ),
                            Text(
                              vendor.vendorName.replaceAll(RegExp(r'\s*\([^)]*\)'), ''),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? themeState.palette.primaryColor : null,
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 11, color: Colors.grey),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    vendor.city,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (_selectedVendorName != null) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: themeState.palette.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: themeState.palette.primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.filter_alt_rounded, size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Showing products from: $_selectedVendorName',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => setState(() {
                            _selectedVendorId = null;
                            _selectedVendorName = null;
                          }),
                          child: const Icon(Icons.close_rounded, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 10)),

            // Restaurant Strip: only shown when Fast Food tab is active
            if (_activePillar == MainCategoryType.fastFood) ...[  
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              gradient: themeState.palette.linearGradient,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.store_mall_directory_rounded, color: Colors.white, size: 16),
                          ),
                          const SizedBox(width: 8),
                          const Text('Restaurants Near You', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 100,
                  child: Builder(builder: (context) {
                    final restaurants = allProducts
                        .where((p) => p.categoryType == MainCategoryType.fastFood && p.restaurantName != null)
                        .map((p) => p.restaurantName!)
                        .toSet()
                        .toList();
                    restaurants.sort();
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: restaurants.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final name = restaurants[index];
                        final products = allProducts.where((p) => p.restaurantName == name).toList();
                        final emoji = products.isNotEmpty ? (products.first.restaurantType == 'bakery' ? '🎂' : '🍔') : '🍽️';
                        final cuisine = products.isNotEmpty ? (products.first.cuisineType ?? 'Restaurant') : 'Restaurant';
                        return SpringTouchScale(
                          onTap: () {
                            setState(() {
                              if (_searchQuery == name) {
                                _searchQuery = '';
                                _homeSearchController.clear();
                              } else {
                                _searchQuery = name;
                                _homeSearchController.text = name;
                              }
                            });
                          },
                          child: Container(
                            width: 130,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF181E2B) : Colors.white,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                              border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6)],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(emoji, style: const TextStyle(fontSize: 26)),
                                const SizedBox(height: 4),
                                Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text(cuisine, style: TextStyle(fontSize: 10, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ).animate(delay: (50 * index).ms).fadeIn().slideX(begin: 0.1, duration: 250.ms),
                        );
                      },
                    );
                  }),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // Bakery Specials horizontal section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          gradient: themeState.palette.linearGradient,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.cake_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 8),
                      const Text('Bakery Specials 🎂', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 240,
                  child: Builder(builder: (context) {
                    final bakeryItems = allProducts.where((p) =>
                        (p.isFastFood || p.categoryType == MainCategoryType.dairyBakery) &&
                        (p.restaurantType == 'bakery' ||
                            p.categoryName.toLowerCase().contains('bakery') ||
                            p.categoryName.toLowerCase().contains('cake') ||
                            p.categoryName.toLowerCase().contains('bread') ||
                            p.categoryName.toLowerCase().contains('croissant') ||
                            p.categoryName.toLowerCase().contains('biscuit') ||
                            p.categoryName.toLowerCase().contains('rusk'))).toList();
                    if (bakeryItems.isEmpty) return const SizedBox.shrink();
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: bakeryItems.length.clamp(0, 8),
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final p = bakeryItems[index];
                        return SizedBox(
                          width: 170,
                          child: ProductCardItem(
                            product: p,
                            onTap: () => context.push('${RouteNames.customerProductDetails}/${p.id}', extra: p),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],

            // Flash Deals Section with Real-Time Live Ticking Countdown & Multi-Category Filters
            if (flashDeals.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                gradient: themeState.palette.linearGradient,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 8),
                            const Flexible(
                              child: Text(
                                'Flash Sale Deals',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const LiveDealCountdownBadge(),
                    ],
                  ),
                ),
              ),

              // Multi-Category Deal Filters
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildDealCategoryChip(
                          label: 'All Deals (${flashDeals.length})',
                          isSelected: _selectedDealCategory == null,
                          onTap: () => setState(() => _selectedDealCategory = null),
                          isDark: isDark,
                          themeState: themeState,
                        ),
                        const SizedBox(width: 8),
                        _buildDealCategoryChip(
                          label: '🍽️ Crockery Deals',
                          isSelected: _selectedDealCategory == MainCategoryType.crockery,
                          onTap: () => setState(() => _selectedDealCategory = MainCategoryType.crockery),
                          isDark: isDark,
                          themeState: themeState,
                        ),
                        const SizedBox(width: 8),
                        _buildDealCategoryChip(
                          label: '🛒 Grocery Deals',
                          isSelected: _selectedDealCategory == MainCategoryType.grocery,
                          onTap: () => setState(() => _selectedDealCategory = MainCategoryType.grocery),
                          isDark: isDark,
                          themeState: themeState,
                        ),
                        const SizedBox(width: 8),
                        _buildDealCategoryChip(
                          label: '🥛 Dairy Deals',
                          isSelected: _selectedDealCategory == MainCategoryType.dairyBakery,
                          onTap: () => setState(() => _selectedDealCategory = MainCategoryType.dairyBakery),
                          isDark: isDark,
                          themeState: themeState,
                        ),
                        const SizedBox(width: 8),
                        _buildDealCategoryChip(
                          label: '🍔 Fast Food Deals',
                          isSelected: _selectedDealCategory == MainCategoryType.fastFood,
                          onTap: () => setState(() => _selectedDealCategory = MainCategoryType.fastFood),
                          isDark: isDark,
                          themeState: themeState,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: flashListH,
                  child: Builder(builder: (context) {
                    final categoryDeals = allProducts
                        .where((p) =>
                            (_selectedDealCategory == null || p.categoryType == _selectedDealCategory) &&
                            (p.isFlashDeal || p.discountPercentage > 0 || p.salePrice < p.basePrice))
                        .toList();
                    final displayedDeals = categoryDeals.isNotEmpty ? categoryDeals : flashDeals;

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: displayedDeals.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final p = displayedDeals[index];
                        return SizedBox(
                          width: 170,
                          child: ProductCardItem(
                            product: p,
                            onTap: () => context.push('${RouteNames.customerProductDetails}/${p.id}', extra: p),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ),
            ],

            // Categories Icon Grid
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Explore Categories',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.go(RouteNames.customerCategories),
                          child: Text(
                            'View All',
                            style: TextStyle(color: themeState.palette.primaryColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 105,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          return SpringTouchScale(
                            onTap: () => context.go(RouteNames.customerCategories),
                            child: SizedBox(
                              width: 72,
                              child: Column(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF181E2B) : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.04),
                                          blurRadius: 6,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(cat.iconEmoji, style: const TextStyle(fontSize: 26)),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    cat.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Four Dedicated Real-time Category Sections ───────────────────────
            if (_searchQuery.isEmpty && _activePillar == null) ...[
              SliverToBoxAdapter(
                child: _buildCategorySection(
                  title: 'Crockery & Dining Picks',
                  emoji: '🍽️',
                  categoryType: MainCategoryType.crockery,
                  products: allProducts
                      .where((p) => p.categoryType == MainCategoryType.crockery)
                      .toList(),
                  themeState: themeState,
                  cardHeight: flashListH,
                  isDark: isDark,
                ),
              ),
              SliverToBoxAdapter(
                child: _buildCategorySection(
                  title: 'Grocery & Staples Essentials',
                  emoji: '🛒',
                  categoryType: MainCategoryType.grocery,
                  products: allProducts
                      .where((p) => p.categoryType == MainCategoryType.grocery)
                      .toList(),
                  themeState: themeState,
                  cardHeight: flashListH,
                  isDark: isDark,
                ),
              ),
              SliverToBoxAdapter(
                child: _buildCategorySection(
                  title: 'Dairy & Fresh Bakery',
                  emoji: '🥛',
                  categoryType: MainCategoryType.dairyBakery,
                  products: allProducts
                      .where((p) => p.categoryType == MainCategoryType.dairyBakery)
                      .toList(),
                  themeState: themeState,
                  cardHeight: flashListH,
                  isDark: isDark,
                ),
              ),
              SliverToBoxAdapter(
                child: _buildCategorySection(
                  title: 'Fast Food & Bites',
                  emoji: '🍔',
                  categoryType: MainCategoryType.fastFood,
                  products: allProducts
                      .where((p) => p.categoryType == MainCategoryType.fastFood)
                      .toList(),
                  themeState: themeState,
                  cardHeight: flashListH,
                  isDark: isDark,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ],

            // Main Product Discovery Grid
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'Search Results (${displayedProducts.length})'
                            : (_activePillar == null
                                ? 'All Recommended Products'
                                : (_activePillar == MainCategoryType.crockery
                                    ? 'Fine Crockery & Tableware'
                                    : _activePillar == MainCategoryType.grocery
                                        ? 'Pantry Grocery Essentials'
                                        : _activePillar == MainCategoryType.dairyBakery
                                            ? 'Dairy & Fresh Bakery'
                                            : 'Restaurants & Fast Food')),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      TextButton(
                        onPressed: () {
                          _homeSearchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        child: const Text('Clear'),
                      ),
                  ],
                ),
              ),
            ),

            if (displayedProducts.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      const Icon(Icons.search_off_rounded, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No products matching "$_searchQuery"'
                            : 'No products available under this filter.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          _homeSearchController.clear();
                          setState(() {
                            _searchQuery = '';
                            _activePillar = null;
                            _selectedVendorId = null;
                            _selectedVendorName = null;
                          });
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Reset All Filters'),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(16.0),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: gridAspectRatio,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = displayedProducts[index];
                      return StaggeredListAnimation(
                        index: index,
                        child: ProductCardItem(
                          product: product,
                          onTap: () => context.push('${RouteNames.customerProductDetails}/${product.id}', extra: product),
                        ),
                      );
                    },
                    childCount: displayedProducts.length,
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection({
    required String title,
    required String emoji,
    required MainCategoryType categoryType,
    required List<ProductEntity> products,
    required ThemeState themeState,
    required double cardHeight,
    required bool isDark,
  }) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.go(RouteNames.customerCategories, extra: categoryType),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        color: themeState.palette.primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: themeState.palette.primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: cardHeight,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: products.length.clamp(0, 10),
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final p = products[index];
              return SizedBox(
                width: 170,
                child: ProductCardItem(
                  product: p,
                  onTap: () => context.push('${RouteNames.customerProductDetails}/${p.id}', extra: p),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPillarChip({
    required String emoji,
    required String label,
    required MainCategoryType type,
    required Color activeColor,
    required bool isDark,
  }) {
    final isActive = _activePillar == type;
    return SpringTouchScale(
      onTap: () => setState(() => _activePillar = isActive ? null : type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? activeColor : (isDark ? const Color(0xFF181E2B) : Colors.white),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
          border: Border.all(
            color: isActive ? Colors.transparent : (isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
            width: 1.5,
          ),
          boxShadow: isActive
              ? [BoxShadow(color: activeColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isActive ? Colors.white : null),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickSearchPill({required String label, required String query}) {
    return SpringTouchScale(
      onTap: () {
        setState(() {
          _searchQuery = query;
          _homeSearchController.text = query;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.35),
            width: 0.9,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDealCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
    required ThemeState themeState,
  }) {
    return SpringTouchScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? themeState.palette.primaryColor.withValues(alpha: 0.16)
              : (isDark ? const Color(0xFF181E2B) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? themeState.palette.primaryColor
                : (isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? themeState.palette.primaryColor
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }
}
