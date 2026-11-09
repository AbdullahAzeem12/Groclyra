import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/database/daos/home_banner_dao.dart';
import '../../features/catalog/domain/entities/category_entity.dart';
import '../animations/spring_touch_scale.dart';

class PromoBannerItem {
  final String id;
  final String tag;
  final String title;
  final String subtitle;
  final String badgeText;
  final String floatingEmojis;
  final List<Color> gradientColors;
  final MainCategoryType? targetPillar;
  final String? filterQuery;
  final String? promoCode;
  final String ctaText;

  const PromoBannerItem({
    required this.id,
    required this.tag,
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.floatingEmojis,
    required this.gradientColors,
    this.targetPillar,
    this.filterQuery,
    this.promoCode,
    this.ctaText = 'Shop Offer →',
  });
}

class LivePromoBannerCarousel extends ConsumerStatefulWidget {
  final ValueChanged<PromoBannerItem>? onBannerTap;
  final MainCategoryType? activePillar;

  const LivePromoBannerCarousel({
    super.key,
    this.onBannerTap,
    this.activePillar,
  });

  @override
  ConsumerState<LivePromoBannerCarousel> createState() => _LivePromoBannerCarouselState();
}

class _LivePromoBannerCarouselState extends ConsumerState<LivePromoBannerCarousel> {
  late final PageController _pageController;
  Timer? _autoSlideTimer;
  int _currentPage = 0;
  bool _isUserInteracting = false;
  int _bannerCount = 4;

  static const List<PromoBannerItem> _fallbackBanners = [
    PromoBannerItem(
      id: 'banner_crockery',
      tag: '✨ ROYAL CROCKERY FESTIVAL • 35% OFF',
      title: 'Imperial Bone China & Crystal Dining',
      subtitle: 'Luxury 72-Pc Dinner Sets, Opal Glassware & Noritake Porcelain',
      badgeText: 'VERIFIED LUXURY',
      floatingEmojis: '🍽️☕🥣',
      gradientColors: [Color(0xFF1E1B4B), Color(0xFF3730A3), Color(0xFF6366F1)],
      targetPillar: MainCategoryType.crockery,
      ctaText: 'Explore Sets →',
    ),
    PromoBannerItem(
      id: 'banner_grocery',
      tag: '🛒 MEGA PANTRY SAVINGS • FLAT 20% OFF',
      title: 'Monthly Grocery Super Saver Pantry',
      subtitle: 'Super Basmati Rice, Pure Canola Oil & Shan Gourmet Spices',
      badgeText: 'SAME DAY DISPATCH',
      floatingEmojis: '🌾🍚🧂',
      gradientColors: [Color(0xFF064E3B), Color(0xFF047857), Color(0xFF10B981)],
      targetPillar: MainCategoryType.grocery,
      ctaText: 'Stock Pantry →',
    ),
    PromoBannerItem(
      id: 'banner_dairy',
      tag: '🥛 100% PURE FARM FRESH • DAILY SPECIAL',
      title: 'Sunrise Dairy Milk & Artisan Bakes',
      subtitle: 'Pure Farm Milk, Free-Range Eggs & Dawn Fresh Artisan Breads',
      badgeText: 'FRESH MORNING STOCK',
      floatingEmojis: '🥛🧀🥖',
      gradientColors: [Color(0xFF78350F), Color(0xFFB45309), Color(0xFFF59E0B)],
      targetPillar: MainCategoryType.dairyBakery,
      ctaText: 'View Bakery →',
    ),
    PromoBannerItem(
      id: 'banner_fastfood',
      tag: '🔥 CRAVINGS EXPRESS • FLAT 25% OFF',
      title: 'Crispy Broast, Burgers & Loaded Fries',
      subtitle: "Hot & Fresh from K&N's Deli, OPTP Grill & Partner Kitchens",
      badgeText: 'HOT IN 25 MINS',
      floatingEmojis: '🍔🍟🍗',
      gradientColors: [Color(0xFF881337), Color(0xFFBE123C), Color(0xFFFF5722)],
      targetPillar: MainCategoryType.fastFood,
      ctaText: 'Order Food →',
    ),
  ];

  static PromoBannerItem _mapRowToPromoBanner(Map<String, dynamic> r) {
    List<Color> colors = [const Color(0xFF1E1B4B), const Color(0xFF3730A3), const Color(0xFF6366F1)];
    try {
      final rawColors = jsonDecode(r['gradientColorsJson']?.toString() ?? '[]') as List;
      if (rawColors.isNotEmpty) {
        colors = rawColors.map((c) => _hexToColor(c.toString())).toList();
      }
    } catch (_) {}

    MainCategoryType? pillar;
    final target = r['targetPillar']?.toString();
    if (target != null && target.isNotEmpty) {
      pillar = MainCategoryType.values.where((p) => p.name == target).firstOrNull;
    }

    return PromoBannerItem(
      id: r['id']?.toString() ?? '',
      tag: r['tag']?.toString() ?? '',
      title: r['title']?.toString() ?? '',
      subtitle: r['subtitle']?.toString() ?? '',
      badgeText: r['badgeText']?.toString() ?? '',
      floatingEmojis: r['floatingEmojis']?.toString() ?? '✨',
      gradientColors: colors,
      targetPillar: pillar,
      ctaText: r['ctaText']?.toString() ?? 'Shop Offer →',
    );
  }

  static Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return const Color(0xFF4F46E5);
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _autoSlideTimer?.cancel();
    _autoSlideTimer = Timer.periodic(const Duration(milliseconds: 4000), (_) {
      if (!_isUserInteracting && _pageController.hasClients && _bannerCount > 0) {
        final nextPage = (_currentPage + 1) % _bannerCount;
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bannersAsync = ref.watch(activeHomeBannersStreamProvider);
    final dbRows = bannersAsync.value ?? [];
    final banners = dbRows.isNotEmpty
        ? dbRows.map(_mapRowToPromoBanner).toList()
        : _fallbackBanners;
    _bannerCount = banners.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 156,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                _isUserInteracting = true;
              } else if (notification is ScrollEndNotification) {
                _isUserInteracting = false;
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: banners.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                final banner = banners[index];
                return AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double scale = 1.0;
                    if (_pageController.position.haveDimensions) {
                      final page = _pageController.page ?? 0.0;
                      final diff = (page - index).abs();
                      scale = (1.0 - (diff * 0.08)).clamp(0.92, 1.0);
                    }
                    return Transform.scale(
                      scale: scale,
                      child: child,
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: SpringTouchScale(
                      onTap: () {
                        if (widget.onBannerTap != null) {
                          widget.onBannerTap!(banner);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                          boxShadow: [
                            BoxShadow(
                              color: banner.gradientColors.first.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                          child: Stack(
                            children: [
                              // Background Gradient
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: banner.gradientColors,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                              ),

                              // Ambient Glassmorphic Layer
                              BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.16),
                                        Colors.white.withValues(alpha: 0.03),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.28),
                                      width: 1.2,
                                    ),
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                                  ),
                                ),
                              ),

                              // Floating Emojis Background Decor
                              Positioned(
                                right: -8,
                                bottom: -8,
                                child: Opacity(
                                  opacity: 0.16,
                                  child: Text(
                                    banner.floatingEmojis,
                                    style: const TextStyle(fontSize: 64, letterSpacing: -2),
                                  ),
                                ),
                              ),

                              // Content Overlay
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Top Row: Tag & Badge
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                              decoration: BoxDecoration(
                                                color: Colors.amber,
                                                borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.15),
                                                    blurRadius: 4,
                                                  ),
                                                ],
                                              ),
                                              child: Text(
                                                banner.tag,
                                                style: const TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.black,
                                                  letterSpacing: 0.3,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.4),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            banner.badgeText,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.4,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Main Title
                                    Text(
                                      banner.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w800,
                                        height: 1.15,
                                        letterSpacing: -0.2,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),

                                    // Subtitle
                                    Text(
                                      banner.subtitle,
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        height: 1.2,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),

                                    // Bottom CTA Row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.22),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(
                                              color: Colors.white.withValues(alpha: 0.4),
                                              width: 1,
                                            ),
                                          ),
                                          child: Text(
                                            banner.ctaText,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Flexible(
                                          child: Text(
                                            'Tap to apply offer',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.75),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Animated Smooth Indicator Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(banners.length, (index) {
            final isActive = _currentPage == index;
            final activeColor = banners[index].gradientColors.length > 1
                ? banners[index].gradientColors[1]
                : banners[index].gradientColors[0];
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isActive ? 22 : 6,
              height: 5.5,
              decoration: BoxDecoration(
                color: isActive
                    ? activeColor
                    : Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.5),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
            );
          }),
        ),
      ],
    );
  }
}
