import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/shared/widgets/base64_image.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/core/utils/currency_formatter.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/widgets/empty_state_view.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import 'package:groclyra/shared/widgets/gradient_button.dart';
import 'package:groclyra/shared/widgets/app_toggle_message.dart';
import 'package:groclyra/features/customer/cart/presentation/controllers/cart_controller.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  final TextEditingController _voucherController = TextEditingController();

  @override
  void dispose() {
    _voucherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final cartState = ref.watch(cartControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Shopping Cart',
        subtitle: 'Multi-Seller Grouped Checkout',
        showThemePicker: false,
      ),
      body: cartState.items.isEmpty
          ? EmptyStateView(
              title: 'Your Cart is Empty',
              description: 'Explore our exquisite Crockery collections and fresh Grocery pantry to add items.',
              icon: Icons.shopping_basket_outlined,
              actionButtonText: 'Start Shopping',
              onAction: () => context.go(RouteNames.customerHome),
            )
          : CustomScrollView(
              slivers: [
                // Multi-Seller Items List
                SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final sellerName = cartState.itemsBySeller.keys.elementAt(index);
                        final sellerItems = cartState.itemsBySeller[sellerName]!;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF121722) : Colors.white,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                            border: Border.all(
                              color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Seller Header
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF181E2B) : const Color(0xFFF8F9FD),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(AppDimensions.radiusMedium),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.storefront_rounded, size: 18, color: Colors.indigo),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        sellerName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Flat Rs. 150 Shipping',
                                      style: TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),

                              // Seller Items
                              ...sellerItems.map((item) {
                                return Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                                        child: Base64Image(
                                          imageUrl: item.product.primaryImage,
                                          categoryType: item.product.categoryType,
                                          productTitle: item.product.title,
                                          width: 68,
                                          height: 68,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.product.title,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            if (item.selectedVariant != null)
                                              Text(
                                                'Variant: ${item.selectedVariant!.name}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: themeState.palette.primaryColor,
                                                ),
                                              ),
                                            const SizedBox(height: 6),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  CurrencyFormatter.format(item.totalPrice),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: themeState.palette.primaryColor,
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                                                      onPressed: () {
                                                        ref
                                                            .read(cartControllerProvider.notifier)
                                                            .updateQuantity(item.id, item.quantity - 1);
                                                      },
                                                    ),
                                                    Text(
                                                      '${item.quantity}',
                                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                                    ),
                                                    IconButton(
                                                      icon: const Icon(Icons.add_circle_outline, size: 20),
                                                      onPressed: () {
                                                        ref
                                                            .read(cartControllerProvider.notifier)
                                                            .updateQuantity(item.id, item.quantity + 1);
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                      childCount: cartState.itemsBySeller.keys.length,
                    ),
                  ),
                ),

                // Voucher Section
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121722) : Colors.white,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                        border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Discount Voucher / Promo Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _voucherController,
                                  textCapitalization: TextCapitalization.characters,
                                  decoration: const InputDecoration(
                                    hintText: 'Try "GROCLYRA10" or "WELCOME500"',
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    prefixIcon: Icon(Icons.local_offer_outlined, size: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  final applied = ref
                                      .read(cartControllerProvider.notifier)
                                      .applyVoucher(_voucherController.text);
                                  if (applied) {
                                    AppToggleMessage.success(
                                      context,
                                      'Voucher ${_voucherController.text.toUpperCase()} applied!',
                                      title: 'Promo Applied',
                                    );
                                  } else {
                                    AppToggleMessage.warning(
                                      context,
                                      'Invalid promo code. Try GROCLYRA10',
                                      title: 'Invalid Voucher',
                                    );
                                  }
                                },
                                child: const Text('Apply'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Order Price Breakdown Summary
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121722) : Colors.white,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                        border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow('Subtotal (${cartState.totalItemCount} items)', CurrencyFormatter.format(cartState.subtotal)),
                          _buildSummaryRow('Total Shipping Fee (${cartState.itemsBySeller.length} sellers)', CurrencyFormatter.format(cartState.totalShippingFee)),
                          if (cartState.discountAmount > 0)
                            _buildSummaryRow('Promo Voucher (${cartState.appliedVoucher})', '-${CurrencyFormatter.format(cartState.discountAmount)}', isDiscount: true),
                          const Divider(height: 20),
                          _buildSummaryRow('Grand Total', CurrencyFormatter.format(cartState.grandTotal), isBold: true, color: themeState.palette.primaryColor),
                        ],
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 90)),
              ],
            ),

      // Bottom Checkout Button
      bottomNavigationBar: cartState.items.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121722) : Colors.white,
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0))),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Total Payable', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            CurrencyFormatter.format(cartState.grandTotal),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: themeState.palette.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: GradientButton(
                        text: 'Proceed to Checkout',
                        onPressed: () => context.push(RouteNames.customerCheckout),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isDiscount = false, bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: isBold ? 14 : 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 16 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isDiscount ? Colors.green : color,
            ),
          ),
        ],
      ),
    );
  }
}
