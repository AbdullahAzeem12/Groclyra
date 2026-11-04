import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/gradient_palette.dart';

/// Ultra-premium 3D aesthetic icon widget for the onboarding slides.
///
/// Features:
/// - 3D perspective tilt reacting to page scroll parallax
/// - Smooth sine-wave continuous levitation
/// - Rotating multi-ring chromatic ambient glow aura
/// - Specular highlight light sweep across the surface
/// - Layered vector-sculpted 3D objects with realistic specular highlights,
///   ceramic reflections, metallic bevels, and drop shadows.
class Onboarding3DIcon extends StatefulWidget {
  final int pageIndex;
  final double scrollOffset; // Relative scroll delta (-1.0 to 1.0)
  final AppThemePalette palette;
  final bool isDark;

  const Onboarding3DIcon({
    super.key,
    required this.pageIndex,
    required this.scrollOffset,
    required this.palette,
    required this.isDark,
  });

  @override
  State<Onboarding3DIcon> createState() => _Onboarding3DIconState();
}

class _Onboarding3DIconState extends State<Onboarding3DIcon>
    with TickerProviderStateMixin {
  late final AnimationController _levitateController;
  late final AnimationController _shimmerController;
  late final AnimationController _haloRotateController;

  @override
  void initState() {
    super.initState();
    // Continuous floating/levitation animation
    _levitateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat(reverse: true);

    // Specular light sweep
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat();

    // Ambient halo slow rotation
    _haloRotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
  }

  @override
  void dispose() {
    _levitateController.dispose();
    _shimmerController.dispose();
    _haloRotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.palette.primaryColor;
    final secondary = widget.palette.secondaryColor;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _levitateController,
        _shimmerController,
        _haloRotateController,
      ]),
      builder: (context, _) {
        final levVal = _levitateController.value;
        // Smooth sine-wave vertical float (-6 to +6 px)
        final floatDy = math.sin(levVal * math.pi) * 8.0;
        final floatScale = 1.0 + math.sin(levVal * math.pi) * 0.02;

        // 3D perspective rotation based on page swipe parallax
        final tiltY = (widget.scrollOffset * 0.55).clamp(-0.6, 0.6);
        final tiltX = (-widget.scrollOffset.abs() * 0.25) +
            (math.sin(levVal * math.pi) * 0.04);

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0018) // 3D Perspective depth
            ..rotateY(tiltY)
            ..rotateX(tiltX)
            ..setTranslationRaw(0.0, floatDy, 0.0),
          child: Transform.scale(
            scale: floatScale,
            child: SizedBox(
              width: 195,
              height: 195,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // 1. Multi-Layer Outer Ambient Glow & Rotating Halo
                  _buildAmbientHalo(primary, secondary),

                  // 2. Base Sphere / 3D Orb Pod
                  _buildMainOrb(primary, secondary),

                  // 3. Realistic 3D Centerpiece
                  _buildCenterpiece(primary, secondary),

                  // 4. Specular Gleam Sweep (Glossy Reflection Effect)
                  _buildSpecularGleam(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Ambient multi-layer halo and back-illumination
  Widget _buildAmbientHalo(Color primary, Color secondary) {
    return Positioned.fill(
      child: Transform.rotate(
        angle: _haloRotateController.value * 2 * math.pi,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                primary.withValues(alpha: 0.0),
                primary.withValues(alpha: 0.35),
                secondary.withValues(alpha: 0.45),
                primary.withValues(alpha: 0.0),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: widget.isDark ? 0.35 : 0.22),
                blurRadius: 42,
                spreadRadius: 8,
              ),
              BoxShadow(
                color: secondary.withValues(alpha: widget.isDark ? 0.25 : 0.15),
                blurRadius: 55,
                spreadRadius: 12,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Core 3D circular orb with glossy edge-lighting and depth
  Widget _buildMainOrb(Color primary, Color secondary) {
    return Container(
      width: 172,
      height: 172,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary,
            secondary,
            widget.isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ],
          stops: const [0.0, 0.65, 1.0],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.45),
          width: 2.2,
        ),
        boxShadow: [
          // Inner core depth shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
          // Colored specular glow
          BoxShadow(
            color: primary.withValues(alpha: 0.40),
            blurRadius: 30,
            offset: const Offset(0, 8),
          ),
        ],
      ),
    );
  }

  /// Centerpiece based on the slide index
  Widget _buildCenterpiece(Color primary, Color secondary) {
    switch (widget.pageIndex) {
      case 0:
        return _buildCrockeryCenterpiece();
      case 1:
        return _buildGroceryCenterpiece();
      case 2:
      default:
        return _buildRocketPortalsCenterpiece(primary, secondary);
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SLIDE 0: EXQUISITE CROCKERY (3D Bone China Plate & Polished Cutlery)
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildCrockeryCenterpiece() {
    return SizedBox(
      width: 135,
      height: 135,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Ceramic Plate Outer Shadow
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.38),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
          ),

          // 2. Ceramic Porcelain Plate Base (concentric depth rings)
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-0.25, -0.25),
                radius: 0.85,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFF1F5F9),
                  Color(0xFFCBD5E1),
                ],
              ),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                width: 2.5,
              ),
            ),
            child: Center(
              // Inner Rim Cavity
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    center: Alignment(0.2, 0.2),
                    radius: 0.9,
                    colors: [
                      Color(0xFFE2E8F0),
                      Color(0xFFF8FAFC),
                      Color(0xFFFFFFFF),
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFFCBD5E1).withValues(alpha: 0.7),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  // Inner Plate Center Medallion
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                        width: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Polished Metallic Silver Fork (Left)
          Positioned(
            left: 6,
            child: _build3DFork(),
          ),

          // 4. Polished Metallic Silver Knife (Right)
          Positioned(
            right: 6,
            child: _build3DKnife(),
          ),

          // 5. Sparkling Crystal Glints (✨)
          Positioned(
            top: 14,
            right: 28,
            child: _buildSparkle(size: 14, color: Colors.amber.shade200),
          ),
          Positioned(
            bottom: 18,
            left: 24,
            child: _buildSparkle(size: 10, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// 3D Silver Fork with 4 tines and metallic reflections
  Widget _build3DFork() {
    return Container(
      width: 18,
      height: 64,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 6,
            offset: const Offset(2, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Fork Tines (4 prongs)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              4,
              (i) => Container(
                width: 2.2,
                height: 18,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFFFFF), Color(0xFF94A3B8)],
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          ),
          // Fork Neck
          Container(
            width: 9,
            height: 10,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFF1F5F9), Color(0xFF64748B)],
              ),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(3)),
            ),
          ),
          // Fork Handle
          Expanded(
            child: Container(
              width: 4.5,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFFFFFFFF), Color(0xFF94A3B8), Color(0xFF475569)],
                ),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3D Silver Knife with bevelled blade and metallic reflections
  Widget _build3DKnife() {
    return Container(
      width: 14,
      height: 64,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 6,
            offset: const Offset(-2, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Knife Blade
          Container(
            width: 8,
            height: 28,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFCBD5E1), Color(0xFF64748B)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(2),
              ),
            ),
          ),
          // Knife Handle
          Expanded(
            child: Container(
              width: 5.5,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFFFFFFFF), Color(0xFF94A3B8), Color(0xFF334155)],
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SLIDE 1: FRESH DAILY GROCERY (3D Shopping Cart & Organic Produce)
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildGroceryCenterpiece() {
    return SizedBox(
      width: 135,
      height: 135,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Fresh Bounty Items Inside Cart (Floating Produce Layer)
          Positioned(
            top: 24,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Emerald Fresh Leaf
                Transform.rotate(
                  angle: -0.25,
                  child: Container(
                    width: 22,
                    height: 26,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4ADE80), Color(0xFF15803D)],
                      ),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF15803D).withValues(alpha: 0.4),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Ripe Ruby Apple / Fruit
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.3, -0.3),
                      radius: 0.8,
                      colors: [Color(0xFFFF6B6B), Color(0xFFDC2626), Color(0xFF991B1B)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Align(
                    alignment: const Alignment(-0.4, -0.4),
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Golden Organic Grain / Baguette
                Transform.rotate(
                  angle: 0.28,
                  child: Container(
                    width: 16,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFDE047), Color(0xFFD97706)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD97706).withValues(alpha: 0.35),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. 3D Shopping Cart Body
          Positioned(
            top: 42,
            child: Container(
              width: 78,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFFAA00),
                    Color(0xFFFF7700),
                    Color(0xFFDD5500),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(10),
                  bottomRight: Radius.circular(6),
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Lattice grid bars
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      4,
                      (i) => Container(
                        width: 2.5,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Cart Handle & Push Frame
          Positioned(
            top: 36,
            right: 18,
            child: Container(
              width: 14,
              height: 48,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFF97316), width: 3.5),
                  right: BorderSide(color: Color(0xFF94A3B8), width: 3.5),
                ),
              ),
            ),
          ),

          // 4. Cart Chassis Wheels (Dual Chrome Wheels)
          Positioned(
            bottom: 22,
            left: 36,
            child: _buildCartWheel(),
          ),
          Positioned(
            bottom: 22,
            right: 36,
            child: _buildCartWheel(),
          ),

          // 5. Floating Discount / Organic Badge
          Positioned(
            top: 10,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.eco_rounded, color: Colors.white, size: 10),
                  SizedBox(width: 2),
                  Text('100% Fresh', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 3D Wheel with chrome hubcap
  Widget _buildCartWheel() {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF334155),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 5,
          height: 5,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // SLIDE 2: 4 UNIFIED PORTALS, 1 APP (3D Rocket Ship & 4 Revolving Portals)
  // ═════════════════════════════════════════════════════════════════════════
  Widget _buildRocketPortalsCenterpiece(Color primary, Color secondary) {
    return SizedBox(
      width: 145,
      height: 145,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Orbital Ring (Tilted 3D Ellipse)
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.002)
              ..rotateX(1.1)
              ..rotateZ(-0.4),
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyan.withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),

          // 2. 4 Revolving Orbital Portal Badges
          // Portal 1: Customer (🛍️)
          Positioned(
            top: 14,
            left: 20,
            child: _buildPortalBadge('🛍️', const Color(0xFF10B981)),
          ),
          // Portal 2: Seller (🏪)
          Positioned(
            top: 20,
            right: 14,
            child: _buildPortalBadge('🏪', const Color(0xFF8B5CF6)),
          ),
          // Portal 3: Express Rider (🛵)
          Positioned(
            bottom: 24,
            left: 14,
            child: _buildPortalBadge('🛵', const Color(0xFFF59E0B)),
          ),
          // Portal 4: Admin Governance (🛡️)
          Positioned(
            bottom: 16,
            right: 22,
            child: _buildPortalBadge('🛡️', const Color(0xFF007DFE)),
          ),

          // 3. Central 3D Aerodynamic Rocket Ship
          Transform.rotate(
            angle: -math.pi / 4.2, // 45 degree launch angle
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Rocket Nose Cone & Fuselage
                Container(
                  width: 32,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFFFFFFF),
                        Color(0xFFF1F5F9),
                        Color(0xFFCBD5E1),
                      ],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                      bottom: Radius.circular(8),
                    ),
                    border: Border.all(color: Colors.white, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(4, 6),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Red Cockpit Nose Cap
                      Positioned(
                        top: 0,
                        child: Container(
                          width: 24,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                          ),
                        ),
                      ),
                      // Cyan Visor Dome
                      Positioned(
                        top: 20,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                            ),
                            border: Border.all(color: Colors.white, width: 1.2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Rocket Thruster Fire Flame (Layered Animated Exhaust)
                _buildThrusterFlame(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Portal Badge mini orb
  Widget _buildPortalBadge(String emoji, Color glowColor) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.isDark ? const Color(0xFF0F172A) : Colors.white,
        border: Border.all(color: glowColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: 0.55),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  /// Animated Rocket Flame
  Widget _buildThrusterFlame() {
    final flameScale = 0.85 + math.sin(_levitateController.value * math.pi * 3) * 0.18;
    return Transform.scale(
      scaleY: flameScale,
      child: Container(
        width: 16,
        height: 20,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFDE047), // Intense yellow core
              Color(0xFFFB923C), // Amber
              Color(0xFFEF4444), // Fiery red
              Colors.transparent,
            ],
            stops: [0.0, 0.4, 0.8, 1.0],
          ),
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
        ),
      ),
    );
  }

  /// Specular highlight sweep across the 3D surface
  Widget _buildSpecularGleam() {
    final t = _shimmerController.value;
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipOval(
          child: Transform.translate(
            offset: Offset((t * 360) - 180, (t * 360) - 180),
            child: Transform.rotate(
              angle: math.pi / 4,
              child: Container(
                width: 45,
                height: 240,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.35),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Sparkling star accent
  Widget _buildSparkle({required double size, required Color color}) {
    return Icon(
      Icons.auto_awesome,
      size: size,
      color: color,
    );
  }
}
