import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/gradient_palette.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../routing/route_names.dart';
import '../../../../shared/widgets/gradient_button.dart';
import '../widgets/onboarding_3d_icon.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late final AnimationController _bgAmbientController;

  final List<Map<String, String>> _pages = const [
    {
      'emoji': '🍽️',
      'title': 'Exquisite Crockery',
      'subtitle':
          'Discover authentic Bone China dinner sets, crystal glassware, porcelain plates & artisanal bowls for elegant living.',
    },
    {
      'emoji': '🛒',
      'title': 'Fresh Daily Grocery',
      'subtitle':
          'Stock your kitchen pantry with premium aged Basmati rice, cold-pressed cooking oils, organic spices & everyday essentials.',
    },
    {
      'emoji': '🚀',
      'title': '4 Unified Portals, 1 App',
      'subtitle':
          'Seamless isolated shells for Customers, Verified Sellers, Express Riders, and Administrative Platform Governance.',
    },
  ];

  @override
  void initState() {
    super.initState();
    _bgAmbientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bgAmbientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final palette = themeState.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF090D16)
          : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // 1. Ultra-Premium Ambient Background Theme (Glow Orbs & Light Mesh)
          _buildAmbientBackground(size, palette, isDark),

          // 2. Main Safe Area Content
          SafeArea(
            child: Column(
              children: [
                // Top Bar: Brand Logo & Skip Button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 10.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Glowing Brand Header
                      Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: palette.linearGradient,
                              borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSmall,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: palette.primaryColor.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Text(
                                'GL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'GROCLYRA',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 19,
                              letterSpacing: 2.0,
                              color: palette.primaryColor,
                            ),
                          ),
                        ],
                      ),

                      // Skip Button with Touch Feedback
                      Container(
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextButton(
                          onPressed: () => context.go(RouteNames.login),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            foregroundColor: isDark
                                ? Colors.white70
                                : Colors.black87,
                            minimumSize: const Size(0, 32),
                          ),
                          child: const Text(
                            'Skip',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Page View with 3D Centerpieces and Smooth Parallax
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (idx) => setState(() => _currentPage = idx),
                    itemBuilder: (context, index) {
                      return AnimatedBuilder(
                        animation: _pageController,
                        builder: (context, child) {
                          double pageDelta = 0.0;
                          if (_pageController.position.haveDimensions) {
                            pageDelta = (_pageController.page ?? 0.0) - index;
                          }
                          final isCurrentPage = _currentPage == index;

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            child: Center(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(height: 12),

                                    // 3D Aesthetic Centerpiece Icon
                                    Onboarding3DIcon(
                                      pageIndex: index,
                                      scrollOffset: pageDelta,
                                      palette: palette,
                                      isDark: isDark,
                                    ),

                                    const SizedBox(height: 42),

                                    // Slide Title (Bold, High Contrast, Anti-Overflow)
                                    AnimatedOpacity(
                                      duration: const Duration(
                                        milliseconds: 350,
                                      ),
                                      opacity: isCurrentPage ? 1.0 : 0.4,
                                      child: AnimatedSlide(
                                        duration: const Duration(
                                          milliseconds: 350,
                                        ),
                                        offset: isCurrentPage
                                            ? Offset.zero
                                            : const Offset(0, 0.08),
                                        child: Text(
                                          _pages[index]['title']!,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 27,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.4,
                                            height: 1.25,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 14),

                                    // Slide Subtitle with Refined Line Height
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 360,
                                      ),
                                      child: AnimatedOpacity(
                                        duration: const Duration(
                                          milliseconds: 350,
                                        ),
                                        opacity: isCurrentPage ? 1.0 : 0.4,
                                        child: AnimatedSlide(
                                          duration: const Duration(
                                            milliseconds: 350,
                                          ),
                                          offset: isCurrentPage
                                              ? Offset.zero
                                              : const Offset(0, 0.08),
                                          child: Text(
                                            _pages[index]['subtitle']!,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 14.5,
                                              color: isDark
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF64748B),
                                              height: 1.55,
                                              letterSpacing: 0.1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 24),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),

                // Indicator Dots (Elongated Active Pill with Glow)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_pages.length, (index) {
                    final isActive = _currentPage == index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 34 : 9,
                      height: 9,
                      decoration: BoxDecoration(
                        gradient: isActive ? palette.linearGradient : null,
                        color: isActive
                            ? null
                            : (isDark
                                  ? Colors.white.withValues(alpha: 0.20)
                                  : Colors.black.withValues(alpha: 0.15)),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: palette.primaryColor.withValues(
                                    alpha: 0.55,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),

                const SizedBox(height: 28),

                // Bottom CTA Button (GradientButton with Shimmer & Spring Ripple)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.p24,
                    vertical: 12,
                  ),
                  child: GradientButton(
                    text: _currentPage == _pages.length - 1
                        ? 'Get Started'
                        : 'Continue',
                    icon: _currentPage == _pages.length - 1
                        ? Icons.rocket_launch_rounded
                        : Icons.arrow_forward_rounded,
                    onPressed: () {
                      if (_currentPage < _pages.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOutQuint,
                        );
                      } else {
                        context.go(RouteNames.login);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Ambient Animated Mesh & Glowing Orbs Background
  Widget _buildAmbientBackground(
    Size size,
    AppThemePalette palette,
    bool isDark,
  ) {
    final primary = palette.primaryColor;
    final secondary = palette.secondaryColor;
    final opacity = isDark ? 0.16 : 0.08;

    return AnimatedBuilder(
      animation: _bgAmbientController,
      builder: (context, _) {
        final t = _bgAmbientController.value;
        final dy1 = math.sin(t * 2 * math.pi) * 35;
        final dx1 = math.cos(t * 2 * math.pi) * 30;
        final dy2 = -math.cos(t * 2 * math.pi) * 40;
        final dx2 = math.sin(t * 2 * math.pi) * 35;

        return Stack(
          children: [
            // Top Orb
            Positioned(
              top: -60 + dy1,
              right: -50 + dx1,
              child: Container(
                width: size.width * 0.8,
                height: size.width * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primary.withValues(alpha: opacity * 1.6),
                      primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Middle Ambient Accent
            Positioned(
              top: size.height * 0.35 + dy2,
              left: -70 + dx2,
              child: Container(
                width: size.width * 0.7,
                height: size.width * 0.7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      secondary.withValues(alpha: opacity * 1.4),
                      secondary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Accent
            Positioned(
              bottom: -80 - dy1,
              right: size.width * 0.1 + dx1,
              child: Container(
                width: size.width * 0.75,
                height: size.width * 0.75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primary.withValues(alpha: opacity * 1.3),
                      primary.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
