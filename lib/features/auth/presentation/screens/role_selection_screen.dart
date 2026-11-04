import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../routing/route_names.dart';
import '../../../../shared/animations/spring_touch_scale.dart';
import '../../../../shared/animations/rotating_border_glow_card.dart';
import '../../domain/entities/user_entity.dart';
import '../controllers/auth_controller.dart';
import '../widgets/floating_background.dart';

class RoleSelectionScreen extends ConsumerStatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  ConsumerState<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends ConsumerState<RoleSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _glowRotateController;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    )..forward();
    _glowRotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _glowRotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final palette = themeState.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final roles = [
      {
        'role': UserRole.customer,
        'title': 'Customer Portal',
        'badge': 'B2C & Grocery',
        'desc': 'Shop high-end Crockery & fresh Daily Grocery with live order tracking.',
        'color': const Color(0xFF10B981),
        'secondaryColor': const Color(0xFF06D6A0),
        'icon': Icons.shopping_bag_rounded,
      },
      {
        'role': UserRole.seller,
        'title': 'Seller Center',
        'badge': 'Store & Catalog',
        'desc': 'List tableware & food products, manage stock, and monitor sales.',
        'color': const Color(0xFF8B5CF6),
        'secondaryColor': const Color(0xFFA855F7),
        'icon': Icons.storefront_rounded,
      },
      {
        'role': UserRole.rider,
        'title': 'Express Rider Hub',
        'badge': 'Fulfillment & GPS',
        'desc': 'Accept delivery tasks, navigate GPS routes, and complete OTP proof.',
        'color': const Color(0xFFF59E0B),
        'secondaryColor': const Color(0xFFFF7A00),
        'icon': Icons.two_wheeler_rounded,
      },
      {
        'role': UserRole.admin,
        'title': 'Admin Console',
        'badge': 'Control & Audit',
        'desc': 'Platform governance, KYC verification, catalog control & telemetry.',
        'color': const Color(0xFF007DFE),
        'secondaryColor': const Color(0xFF00D2FF),
        'icon': Icons.admin_panel_settings_rounded,
      },
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF8F9FD),
      body: Stack(
        children: [
          FloatingBackground(palette: palette, isDark: isDark),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.p24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          gradient: palette.linearGradient,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                          boxShadow: [BoxShadow(color: palette.startColor.withValues(alpha: 0.38), blurRadius: 14, offset: const Offset(0, 4))],
                        ),
                        child: const Center(child: Text('GL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5))),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (isDark ? const Color(0xFF1E293B) : Colors.white).withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: palette.startColor, boxShadow: [BoxShadow(color: palette.startColor.withValues(alpha: 0.8), blurRadius: 4)])),
                          const SizedBox(width: 6),
                          Text('Unified Marketplace', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155))),
                        ]),
                      ),
                    ]),
                  ]),
                  const SizedBox(height: 18),
                  Text('Welcome to Groclyra', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  const SizedBox(height: 4),
                  Text('Select your portal to continue into the unified marketplace:', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), height: 1.4)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      itemCount: roles.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final item = roles[index];
                        final role = item['role'] as UserRole;
                        final color = item['color'] as Color;
                        final secondaryColor = item['secondaryColor'] as Color;
                        final icon = item['icon'] as IconData;
                        final title = item['title'] as String;
                        final badge = item['badge'] as String;
                        final desc = item['desc'] as String;
                        final startInterval = (index * 0.12).clamp(0.0, 1.0);
                        final endInterval = (startInterval + 0.55).clamp(0.0, 1.0);
                        final cardAnim = CurvedAnimation(parent: _entranceController, curve: Interval(startInterval, endInterval, curve: Curves.easeOutBack));
                        final phaseOffset = index * 0.25;
                        return AnimatedBuilder(
                          animation: cardAnim,
                          builder: (context, child) => Opacity(opacity: cardAnim.value.clamp(0.0, 1.0), child: Transform.translate(offset: Offset(0, (1.0 - cardAnim.value) * 35), child: child)),
                          child: RotatingBorderGlowCard(
                            rotateController: _glowRotateController,
                            color: color, secondaryColor: secondaryColor,
                            phaseOffset: phaseOffset, isDark: isDark,
                            borderRadius: AppDimensions.radiusLarge,
                            child: SpringTouchScale(
                              navigationDelayMs: 165,
                              onTap: () {
                                ref.read(authControllerProvider.notifier).selectRole(role);
                                final auth = ref.read(authControllerProvider);
                                try {
                                  if (auth.isAuthenticated && auth.user != null) {
                                    final currentRole = auth.user!.role;
                                    if (currentRole == UserRole.admin || currentRole == role) {
                                      switch (role) {
                                        case UserRole.customer:
                                          context.go(RouteNames.customerHome);
                                          break;
                                        case UserRole.seller:
                                          context.go(RouteNames.sellerDashboard);
                                          break;
                                        case UserRole.rider:
                                          context.go(RouteNames.riderDashboard);
                                          break;
                                        case UserRole.admin:
                                          context.go(RouteNames.adminDashboard);
                                          break;
                                      }
                                      return;
                                    } else {
                                      context.push('?role=');
                                      return;
                                    }
                                  }
                                  context.push(RouteNames.login);
                                } catch (_) {}
                              },
                              scaleFactor: 0.93, pressDepth: 4.0, enableRipple: true,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                              splashColor: color.withValues(alpha: 0.22),
                              highlightColor: color.withValues(alpha: 0.10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                                    colors: isDark ? [color.withValues(alpha: 0.18), const Color(0xFF131A29).withValues(alpha: 0.90), const Color(0xFF0B101D).withValues(alpha: 0.95)]
                                              : [color.withValues(alpha: 0.08), Colors.white, Colors.white.withValues(alpha: 0.95)]),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
                                  border: Border.all(color: Colors.transparent, width: 0.0),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06), blurRadius: 18, offset: const Offset(0, 8))],
                                ),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                                  Container(width: 52, height: 52,
                                    decoration: BoxDecoration(
                                      gradient: RadialGradient(center: const Alignment(-0.3, -0.3), radius: 0.9, colors: [color.withValues(alpha: 0.35), secondaryColor.withValues(alpha: 0.10)]),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: color.withValues(alpha: 0.45), width: 1.4),
                                      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.30), blurRadius: 10, offset: const Offset(0, 3))],
                                    ),
                                    child: Center(child: Icon(icon, color: isDark ? Colors.white : color, size: 26))),
                                  const SizedBox(width: 16),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                                    Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
                                      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A), letterSpacing: -0.2)),
                                      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.35), width: 1.0)),
                                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                                          Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.8), blurRadius: 4)])),
                                          const SizedBox(width: 5),
                                          Text(badge, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
                                        ])),
                                    ]),
                                    const SizedBox(height: 5),
                                    Text(desc, style: TextStyle(fontSize: 12, height: 1.35, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                  ])),
                                  const SizedBox(width: 10),
                                  Container(width: 34, height: 34,
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: isDark ? 0.15 : 0.08),
                                      border: Border.all(color: color.withValues(alpha: isDark ? 0.35 : 0.2), width: 1.0),
                                      boxShadow: [BoxShadow(color: color.withValues(alpha: 0.20), blurRadius: 6, offset: const Offset(0, 2))]),
                                    child: Center(child: Icon(Icons.arrow_forward_ios_rounded, size: 13, color: color))),
                                ]),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFF131A29) : Colors.white).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isDark ? const Color(0xFF26334D) : const Color(0xFFE2E8F0)),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04), blurRadius: 10, offset: const Offset(0, 2))],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Already have an account?', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      const SizedBox(width: 4),
                      SpringTouchScale(navigationDelayMs: 140, onTap: () { try { context.push(RouteNames.login); } catch (_) {} }, scaleFactor: 0.90, pressDepth: 1.5,
                        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text('Sign In', style: TextStyle(color: palette.startColor, fontWeight: FontWeight.w800, fontSize: 12)))),
                      Text('*', style: TextStyle(color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8))),
                      SpringTouchScale(navigationDelayMs: 140, onTap: () { try { context.push(RouteNames.register); } catch (_) {} }, scaleFactor: 0.90, pressDepth: 1.5,
                        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Text('Register', style: TextStyle(color: palette.startColor, fontWeight: FontWeight.w800, fontSize: 12)))),
                    ]),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
