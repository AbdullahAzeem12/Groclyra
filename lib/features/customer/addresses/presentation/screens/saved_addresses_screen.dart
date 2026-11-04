import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';
import 'package:groclyra/shared/widgets/app_toggle_message.dart';

import 'package:groclyra/features/customer/addresses/domain/entities/delivery_address_entity.dart';
import 'package:groclyra/features/customer/addresses/presentation/controllers/address_controller.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Saved Addresses Screen — Premium 3D Animated List with real-time Firestore sync
// ─────────────────────────────────────────────────────────────────────────────
class SavedAddressesScreen extends ConsumerStatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  ConsumerState<SavedAddressesScreen> createState() =>
      _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends ConsumerState<SavedAddressesScreen>
    with TickerProviderStateMixin {
  late AnimationController _emptyStateController;
  late Animation<double> _emptyPulse;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _emptyStateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _emptyPulse = Tween<double>(begin: 0.94, end: 1.06).animate(
      CurvedAnimation(parent: _emptyStateController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _emptyStateController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final addressState = ref.watch(addressControllerProvider);
    final isDark = themeState.isDark;
    final primary = themeState.palette.primaryColor;
    final secondary = themeState.palette.secondaryColor;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF4F6FB),
      appBar: GradientAppBar(
        title: 'Saved Delivery Addresses',
        subtitle: 'Manage Pakistan Delivery Locations',
        showBack: true,
        showThemePicker: false,
        actions: [
          SpringTouchScale(
            onTap: () async {
              HapticFeedback.lightImpact();
              await ref.read(addressControllerProvider.notifier).refresh();
            },
            scaleFactor: 0.85,
            pressDepth: 3,
            enableRipple: true,
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.sync_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
          SpringTouchScale(
            onTap: () => context.push(RouteNames.customerAddressAddEdit),
            scaleFactor: 0.85,
            pressDepth: 3,
            enableRipple: false,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_location_alt_rounded,
                  color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: addressState.isLoading
            ? _buildShimmerLoader(isDark, primary)
            : addressState.addresses.isEmpty
                ? _buildEmptyState(context, isDark, primary, secondary)
                : _buildAddressList(
                    context,
                    ref,
                    addressState.addresses,
                    isDark,
                    primary,
                    secondary,
                  ),
      ),
      floatingActionButton: _PremiumFAB(
        primaryColor: primary,
        secondaryColor: secondary,
        onPressed: () => context.push(RouteNames.customerAddressAddEdit),
      ),
    );
  }

  // ── Shimmer Loading State ──────────────────────────────────────────────────
  Widget _buildShimmerLoader(bool isDark, Color primary) {
    return ListView.builder(
      key: const ValueKey('shimmer'),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
      itemCount: 3,
      itemBuilder: (_, index) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 180,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141923) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: _ShimmerBox(isDark: isDark)
            .animate(delay: (80 * index).ms)
            .fadeIn(duration: 350.ms)
            .shimmer(
              duration: 1200.ms,
              color: primary.withValues(alpha: 0.08),
            ),
      ),
    );
  }

  // ── Empty State ────────────────────────────────────────────────────────────
  Widget _buildEmptyState(
    BuildContext context,
    bool isDark,
    Color primary,
    Color secondary,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
        await ref.read(addressControllerProvider.notifier).refresh();
      },
      color: primary,
      child: SingleChildScrollView(
        key: const ValueKey('empty'),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated 3D pin icon with pulsing glow
            AnimatedBuilder(
              animation: _emptyPulse,
              builder: (_, child) => Transform.scale(
                scale: _emptyPulse.value,
                child: child,
              ),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primary.withValues(alpha: 0.25),
                      primary.withValues(alpha: 0.06),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.3),
                      blurRadius: 32,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.location_off_rounded,
                  size: 56,
                  color: primary,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'No Saved Addresses Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1A1F36),
                letterSpacing: -0.3,
              ),
            )
                .animate()
                .fadeIn(delay: 100.ms, duration: 400.ms)
                .slideY(begin: 0.15, end: 0),
            const SizedBox(height: 12),
            Text(
              'Add your home, office or apartment anywhere across Pakistan with precise pin placement and live delivery coverage.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                height: 1.6,
              ),
            )
                .animate()
                .fadeIn(delay: 180.ms, duration: 400.ms)
                .slideY(begin: 0.15, end: 0),
            const SizedBox(height: 36),
            SpringTouchScale(
              onTap: () => context.push(RouteNames.customerAddressAddEdit),
              scaleFactor: 0.92,
              pressDepth: 4,
              enableRipple: true,
              borderRadius: BorderRadius.circular(20),
              splashColor: Colors.white.withValues(alpha: 0.25),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, secondary],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.45),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_location_alt_rounded,
                        color: Colors.white, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Add Delivery Address',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 260.ms, duration: 400.ms)
                .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  // ── Animated Address List ──────────────────────────────────────────────────
  Widget _buildAddressList(
    BuildContext context,
    WidgetRef ref,
    List<DeliveryAddressEntity> addresses,
    bool isDark,
    Color primary,
    Color secondary,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
        await ref.read(addressControllerProvider.notifier).refresh();
      },
      color: primary,
      child: CustomScrollView(
        key: const ValueKey('list'),
        controller: _scrollController,
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
      slivers: [
        // Count header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primary.withValues(alpha: 0.15),
                        secondary.withValues(alpha: 0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_rounded,
                          size: 14, color: primary),
                      const SizedBox(width: 5),
                      Text(
                        '${addresses.length} ${addresses.length == 1 ? 'Address' : 'Addresses'} Saved',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.1),
                const Spacer(),
                // Live sync indicator
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF10B981),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFF10B981).withValues(alpha: 0.6),
                            blurRadius: 6,
                          )
                        ],
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .scaleXY(
                            begin: 0.7,
                            end: 1.3,
                            duration: 900.ms,
                            curve: Curves.easeInOut)
                        .then()
                        .scaleXY(
                            begin: 1.3,
                            end: 0.7,
                            duration: 900.ms,
                            curve: Curves.easeInOut),
                    const SizedBox(width: 5),
                    Text(
                      'Live Sync',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 300.ms),
              ],
            ),
          ),
        ),

        // Address cards
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final address = addresses[index];
                return _AddressCard(
                  key: ValueKey(address.id),
                  address: address,
                  index: index,
                  isDark: isDark,
                  primaryColor: primary,
                  secondaryColor: secondary,
                  onSetDefault: () => _onSetDefault(context, ref, address),
                  onEdit: () =>
                      context.push(RouteNames.customerAddressAddEdit,
                          extra: address),
                  onDelete: () =>
                      _showPremiumDeleteDialog(context, ref, address, isDark,
                          primary),
                );
              },
              childCount: addresses.length,
            ),
          ),
        ),
      ],
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────────────
  void _onSetDefault(
    BuildContext context,
    WidgetRef ref,
    DeliveryAddressEntity address,
  ) {
    HapticFeedback.mediumImpact();
    ref.read(addressControllerProvider.notifier).setDefaultAddress(address.id);
    AppToggleMessage.success(
      context,
      '"${address.shortDisplay}" set as default delivery address.',
      title: 'Default Address Updated',
    );
  }

  void _showPremiumDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    DeliveryAddressEntity address,
    bool isDark,
    Color primary,
  ) {
    HapticFeedback.heavyImpact();
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      barrierDismissible: true,
      barrierLabel: 'Close',
      transitionDuration: const Duration(milliseconds: 380),
      transitionBuilder: (_, anim, __, child) {
        final curved =
            CurvedAnimation(parent: anim, curve: Curves.elasticOut);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.7, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: anim,
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, _, __) => _PremiumDeleteDialog(
        address: address,
        isDark: isDark,
        primaryColor: primary,
        onDelete: () {
          Navigator.pop(ctx);
          HapticFeedback.heavyImpact();
          ref
              .read(addressControllerProvider.notifier)
              .deleteAddress(address.id);
          AppToggleMessage.error(
            context,
            'Address deleted successfully.',
            title: 'Address Removed',
          );
        },
        onCancel: () => Navigator.pop(ctx),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3D Address Card Widget
// ─────────────────────────────────────────────────────────────────────────────
class _AddressCard extends StatefulWidget {
  final DeliveryAddressEntity address;
  final int index;
  final bool isDark;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onSetDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AddressCard({
    super.key,
    required this.address,
    required this.index,
    required this.isDark,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onSetDefault,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_AddressCard> createState() => _AddressCardState();
}

class _AddressCardState extends State<_AddressCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handlePress(bool down) {
    if (down) {
      HapticFeedback.selectionClick();
      _pressController.forward();
    } else {
      _pressController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final addr = widget.address;
    final isDark = widget.isDark;
    final primary = widget.primaryColor;
    final secondary = widget.secondaryColor;

    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor = addr.isDefault
        ? primary
        : (isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB));

    return AnimatedBuilder(
      animation: _pressController,
      builder: (_, child) {
        final scale = 1.0 - (_pressController.value * 0.025);
        final elevation = (1 - _pressController.value) * 12;
        return Transform.scale(
          scale: scale,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: borderColor, width: addr.isDefault ? 2.0 : 1.2),
              boxShadow: [
                BoxShadow(
                  color: addr.isDefault
                      ? primary.withValues(alpha: 0.22)
                      : Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
                  blurRadius: addr.isDefault ? 24 : elevation,
                  offset: Offset(0, addr.isDefault ? 8 : 4),
                  spreadRadius: addr.isDefault ? 1 : 0,
                ),
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTapDown: (_) => _handlePress(true),
        onTapUp: (_) {
          _handlePress(false);
          setState(() => _expanded = !_expanded);
        },
        onTapCancel: () => _handlePress(false),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Column(
            children: [
              // ── Gradient Header Strip ────────────────────────────────────
              if (addr.isDefault)
                Container(
                  height: 3,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [primary, secondary],
                    ),
                  ),
                ),

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Top Row ────────────────────────────────────────────
                    Row(
                      children: [
                        // Label icon
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primary.withValues(alpha: 0.18),
                                secondary.withValues(alpha: 0.12),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: primary.withValues(alpha: 0.2)),
                          ),
                          child: Center(
                            child: Text(
                              addr.label.icon,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    addr.label.displayName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF111827),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  if (addr.isDefault)
                                    _DefaultBadge(primary: primary),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                addr.recipientName.isNotEmpty
                                    ? '${addr.recipientName} • ${addr.recipientPhone}'
                                    : addr.recipientPhone,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Expand toggle
                        AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: isDark
                                ? Colors.grey[500]
                                : Colors.grey[400],
                          ),
                        ),
                        // Action menu
                        _ActionMenu(
                          address: addr,
                          primaryColor: primary,
                          isDark: isDark,
                          onSetDefault: widget.onSetDefault,
                          onEdit: widget.onEdit,
                          onDelete: widget.onDelete,
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Address Preview ─────────────────────────────────────
                    _AddressPreviewRow(
                      address: addr,
                      isDark: isDark,
                      primaryColor: primary,
                    ),

                    // ── Expanded Details ─────────────────────────────────────
                    AnimatedCrossFade(
                      firstChild: const SizedBox.shrink(),
                      secondChild: _ExpandedDetails(
                        address: addr,
                        isDark: isDark,
                        primaryColor: primary,
                        secondaryColor: secondary,
                      ),
                      crossFadeState: _expanded
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 300),
                      sizeCurve: Curves.easeInOutCubic,
                    ),
                  ],
                ),
              ),

              // ── Bottom Action Tray (always visible) ──────────────────────
              _BottomActionTray(
                address: addr,
                isDark: isDark,
                primaryColor: primary,
                secondaryColor: secondary,
                onSetDefault: widget.onSetDefault,
                onEdit: widget.onEdit,
                onDelete: widget.onDelete,
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: (60 * (widget.index % 8)).ms)
        .fadeIn(duration: 380.ms, curve: Curves.easeOut)
        .slideY(begin: 0.14, end: 0, duration: 380.ms, curve: Curves.easeOutCubic)
        .scale(
          begin: const Offset(0.96, 0.96),
          end: const Offset(1, 1),
          duration: 380.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Address Preview Row (compact address line + pin coordinates)
// ─────────────────────────────────────────────────────────────────────────────
class _AddressPreviewRow extends StatelessWidget {
  final DeliveryAddressEntity address;
  final bool isDark;
  final Color primaryColor;

  const _AddressPreviewRow({
    required this.address,
    required this.isDark,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final formattedAddr = address.formattedAddress.isNotEmpty
        ? address.formattedAddress
        : '${address.houseOrFlat}, ${address.street}, ${address.city}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.location_on_rounded, size: 14, color: primaryColor),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                formattedAddr,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: isDark
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF374151),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Coordinates badge
        _CoordinatesBadge(address: address, isDark: isDark),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Expanded Details Panel
// ─────────────────────────────────────────────────────────────────────────────
class _ExpandedDetails extends StatelessWidget {
  final DeliveryAddressEntity address;
  final bool isDark;
  final Color primaryColor;
  final Color secondaryColor;

  const _ExpandedDetails({
    required this.address,
    required this.isDark,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 14),
        Divider(
          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB),
          height: 1,
        ),
        const SizedBox(height: 14),

        // Full details grid
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (address.city.isNotEmpty)
              _DetailChip(
                icon: Icons.location_city_rounded,
                label: address.city,
                color: primaryColor,
                isDark: isDark,
              ),
            if (address.province.isNotEmpty && address.province != address.city)
              _DetailChip(
                icon: Icons.map_rounded,
                label: address.province,
                color: primaryColor,
                isDark: isDark,
              ),
            if (address.societyOrArea?.isNotEmpty == true)
              _DetailChip(
                icon: Icons.holiday_village_rounded,
                label: address.societyOrArea!,
                color: primaryColor,
                isDark: isDark,
              ),
            if (address.sectorOrBlock?.isNotEmpty == true)
              _DetailChip(
                icon: Icons.grid_view_rounded,
                label: address.sectorOrBlock!,
                color: primaryColor,
                isDark: isDark,
              ),
          ],
        ),

        if (address.nearestLandmark?.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.flag_outlined, size: 13, color: primaryColor.withValues(alpha: 0.7)),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Near: ${address.nearestLandmark}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],

        if (address.deliveryInstructions?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.sticky_note_2_outlined,
                    size: 14, color: primaryColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    address.deliveryInstructions!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.grey[300]
                          : const Color(0xFF374151),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 12),

        // Serviceability tier
        _ServiceabilityTile(address: address),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Action Tray
// ─────────────────────────────────────────────────────────────────────────────
class _BottomActionTray extends StatelessWidget {
  final DeliveryAddressEntity address;
  final bool isDark;
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onSetDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BottomActionTray({
    required this.address,
    required this.isDark,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onSetDefault,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF9FAFB);
    final dividerColor =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: dividerColor, width: 1)),
      ),
      child: Row(
        children: [
          if (!address.isDefault)
            _TrayButton(
              icon: Icons.check_circle_outline_rounded,
              label: 'Set Default',
              color: const Color(0xFF10B981),
              isDark: isDark,
              onTap: onSetDefault,
            ),
          if (!address.isDefault)
            Container(width: 1, height: 40, color: dividerColor),
          _TrayButton(
            icon: Icons.edit_location_alt_rounded,
            label: 'Edit',
            color: primaryColor,
            isDark: isDark,
            onTap: onEdit,
          ),
          Container(width: 1, height: 40, color: dividerColor),
          _TrayButton(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: const Color(0xFFEF4444),
            isDark: isDark,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

class _TrayButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _TrayButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          splashColor: color.withValues(alpha: 0.12),
          highlightColor: color.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Menu (three-dot popup)
// ─────────────────────────────────────────────────────────────────────────────
class _ActionMenu extends StatelessWidget {
  final DeliveryAddressEntity address;
  final Color primaryColor;
  final bool isDark;
  final VoidCallback onSetDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ActionMenu({
    required this.address,
    required this.primaryColor,
    required this.isDark,
    required this.onSetDefault,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(
        Icons.more_vert_rounded,
        size: 20,
        color: isDark ? Colors.grey[500] : Colors.grey[500],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDark ? const Color(0xFF1F2937) : Colors.white,
      elevation: 12,
      offset: const Offset(-8, 8),
      onSelected: (val) {
        HapticFeedback.selectionClick();
        switch (val) {
          case 'default':
            onSetDefault();
          case 'edit':
            onEdit();
          case 'delete':
            onDelete();
        }
      },
      itemBuilder: (_) => [
        if (!address.isDefault)
          const PopupMenuItem(
            value: 'default',
            child: _MenuRow(
              icon: Icons.check_circle_rounded,
              label: 'Set as Default',
              color: Color(0xFF10B981),
            ),
          ),
        PopupMenuItem(
          value: 'edit',
          child: _MenuRow(
            icon: Icons.edit_location_alt_rounded,
            label: 'Edit Address',
            color: primaryColor,
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: _MenuRow(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: Color(0xFFEF4444),
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Default Badge
// ─────────────────────────────────────────────────────────────────────────────
class _DefaultBadge extends StatelessWidget {
  final Color primary;

  const _DefaultBadge({required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade600, Colors.orange.shade400],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 10, color: Colors.white),
          SizedBox(width: 3),
          Text(
            'DEFAULT',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Coordinates Badge
// ─────────────────────────────────────────────────────────────────────────────
class _CoordinatesBadge extends StatelessWidget {
  final DeliveryAddressEntity address;
  final bool isDark;

  const _CoordinatesBadge({required this.address, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (address.latitude == 0 && address.longitude == 0) {
      return const SizedBox.shrink();
    }
    final coordText = address.coordinatesFormatted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? const Color(0xFF1E3A5F)
              : const Color(0xFFBAE6FD),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pin_drop_rounded, size: 11, color: Color(0xFFEF4444)),
          const SizedBox(width: 4),
          Text(
            '📍 $coordText',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail Chip
// ─────────────────────────────────────────────────────────────────────────────
class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;

  const _DetailChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: isDark
                  ? color.withValues(alpha: 0.85)
                  : color.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Serviceability Tile
// ─────────────────────────────────────────────────────────────────────────────
class _ServiceabilityTile extends StatelessWidget {
  final DeliveryAddressEntity address;

  const _ServiceabilityTile({required this.address});

  @override
  Widget build(BuildContext context) {
    final status = address.serviceabilityStatus;
    final color = Color(status.colorValue);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            status == ServiceabilityStatus.expressAvailable
                ? Icons.bolt_rounded
                : status == ServiceabilityStatus.standardOnly
                    ? Icons.local_shipping_rounded
                    : Icons.cancel_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              status.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Delete Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumDeleteDialog extends StatefulWidget {
  final DeliveryAddressEntity address;
  final bool isDark;
  final Color primaryColor;
  final VoidCallback onDelete;
  final VoidCallback onCancel;

  const _PremiumDeleteDialog({
    required this.address,
    required this.isDark,
    required this.primaryColor,
    required this.onDelete,
    required this.onCancel,
  });

  @override
  State<_PremiumDeleteDialog> createState() => _PremiumDeleteDialogState();
}

class _PremiumDeleteDialogState extends State<_PremiumDeleteDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _btnController;
  bool _deleteHold = false;

  @override
  void initState() {
    super.initState();
    _btnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _btnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgColor = isDark ? const Color(0xFF111827) : Colors.white;
    final address = widget.address;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: isDark ? 0.95 : 1.0),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Red gradient header
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(22)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.delete_forever_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delete Address?',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'This action cannot be undone',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Column(
                    children: [
                      // Address preview card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1F2937)
                              : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(address.label.icon,
                                style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    address.label.displayName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF111827),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    address.shortDisplay,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[600],
                                      height: 1.4,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'Are you sure you want to remove this delivery address? You\'ll need to re-add it if needed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 22),

                      // Buttons Row
                      Row(
                        children: [
                          // Cancel button
                          Expanded(
                            child: SpringTouchScale(
                              onTap: widget.onCancel,
                              scaleFactor: 0.93,
                              pressDepth: 3,
                              enableRipple: true,
                              borderRadius: BorderRadius.circular(14),
                              splashColor: Colors.grey.withValues(alpha: 0.15),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1F2937)
                                      : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF374151)
                                        : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  'Keep It',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF374151),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Delete button with bounce
                          Expanded(
                            child: GestureDetector(
                              onTapDown: (_) {
                                setState(() => _deleteHold = true);
                                _btnController.forward();
                                HapticFeedback.heavyImpact();
                              },
                              onTapUp: (_) {
                                _btnController.reverse();
                                setState(() => _deleteHold = false);
                                widget.onDelete();
                              },
                              onTapCancel: () {
                                _btnController.reverse();
                                setState(() => _deleteHold = false);
                              },
                              child: AnimatedBuilder(
                                animation: _btnController,
                                builder: (_, child) => Transform.scale(
                                  scale:
                                      1.0 - (_btnController.value * 0.06),
                                  child: child,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFEF4444),
                                        Color(0xFFF97316),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFEF4444)
                                            .withValues(
                                                alpha:
                                                    _deleteHold ? 0.5 : 0.3),
                                        blurRadius: _deleteHold ? 18 : 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  alignment: Alignment.center,
                                  child: const Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.delete_forever_rounded,
                                          color: Colors.white, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        'Delete',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Premium Floating Action Button
// ─────────────────────────────────────────────────────────────────────────────
class _PremiumFAB extends StatelessWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onPressed;

  const _PremiumFAB({
    required this.primaryColor,
    required this.secondaryColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SpringTouchScale(
      onTap: onPressed,
      scaleFactor: 0.90,
      pressDepth: 5,
      enableRipple: true,
      borderRadius: BorderRadius.circular(20),
      splashColor: Colors.white.withValues(alpha: 0.2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Add New Address',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 400.ms)
        .slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOutCubic);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer Box helper
// ─────────────────────────────────────────────────────────────────────────────
class _ShimmerBox extends StatelessWidget {
  final bool isDark;

  const _ShimmerBox({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final base = isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    width: 90, height: 12, color: base,
                    margin: const EdgeInsets.only(bottom: 6)),
                Container(width: 140, height: 10, color: base),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
            width: double.infinity, height: 10, color: base,
            margin: const EdgeInsets.only(bottom: 6)),
        Container(width: 220, height: 10, color: base),
        const Spacer(),
        Container(
            height: 36,
            decoration: BoxDecoration(
              color: base,
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20)),
            )),
      ],
    );
  }
}
