import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/services/payment_service.dart';
import 'package:groclyra/core/services/payfast_gateway.dart';
import 'package:groclyra/core/services/rate_limit_service.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/core/utils/currency_formatter.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';
import 'package:groclyra/shared/widgets/custom_text_field.dart';
import 'package:groclyra/shared/widgets/gradient_button.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';
import 'package:groclyra/features/customer/cart/presentation/controllers/cart_controller.dart';
import 'package:groclyra/features/customer/orders/domain/entities/order_entity.dart';
import 'package:groclyra/features/customer/orders/presentation/controllers/orders_controller.dart';
import 'package:groclyra/features/customer/checkout/presentation/screens/payment_webview_screen.dart';
import 'package:groclyra/features/customer/cart/domain/entities/cart_item_entity.dart';
import 'package:groclyra/features/customer/addresses/presentation/controllers/address_controller.dart';
import 'package:groclyra/core/services/location_service.dart';
import 'package:groclyra/shared/animations/rotating_border_glow_card.dart';
import 'package:groclyra/shared/widgets/app_toggle_message.dart';
import 'package:groclyra/shared/widgets/base64_image.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final CartItemEntity? directItem;

  const CheckoutScreen({
    super.key,
    this.directItem,
  });

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> with SingleTickerProviderStateMixin {
  PaymentMethod _selectedPayment = PaymentMethod.cashOnDelivery;
  bool _isPlacingOrder = false;
  final TextEditingController _walletPhoneController = TextEditingController();
  final TextEditingController _instructionController = TextEditingController();
  String _selectedInstruction = '📦 Fragile Crockery: Handle with extra care';
  final List<String> _quickInstructions = [
    '📦 Fragile Crockery: Handle with extra care',
    '🚪 Leave package at doorstep / with security',
    '🔔 Ring doorbell twice upon arrival',
    '📞 Call customer when you reach the gate',
    '⚡ Express delivery requested',
  ];
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();
  }

  @override
  void dispose() {
    _walletPhoneController.dispose();
    _instructionController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _processOrder() async {
    final cartState = ref.read(cartControllerProvider);
    final authState = ref.read(authControllerProvider);

    final checkoutItems = widget.directItem != null ? [widget.directItem!] : cartState.items;
    if (checkoutItems.isEmpty) return;

    final user = authState.user;
    final addressState = ref.read(addressControllerProvider);
    final selectedAddress = addressState.defaultAddress ??
        (addressState.addresses.isNotEmpty ? addressState.addresses.first : null);

    final deliveryAddress = selectedAddress?.formattedAddress ??
        user?.deliveryAddress ??
        user?.deliveryZone ??
        '';

    if (deliveryAddress.isEmpty) {
      AppToggleMessage.warning(
        context,
        'Please set a delivery address before placing your order.',
        title: 'Address Required',
      );
      return;
    }

    double? lat = selectedAddress?.latitude;
    double? lng = selectedAddress?.longitude;
    if (lat == null || lng == null || (lat == 0.0 && lng == 0.0)) {
      final resolved = await LocationService().resolveAddressCoordinates(
        deliveryAddress,
        city: selectedAddress?.city,
      );
      lat = resolved.lat;
      lng = resolved.lng;
    }

    if (!mounted) return;

    if (_selectedPayment != PaymentMethod.payFast &&
        _selectedPayment != PaymentMethod.creditDebitCard &&
        _selectedPayment != PaymentMethod.cashOnDelivery &&
        _walletPhoneController.text.isEmpty) {
      AppToggleMessage.warning(
        context,
        'Please enter your mobile wallet number.',
        title: 'Phone Required',
      );
      return;
    }

    final customerId = user?.id ?? 'usr_guest';
    final rateLimit = ref.read(rateLimitServiceProvider);
    if (!rateLimit.canPlaceOrder(customerId)) {
      final rem = rateLimit.getRemainingOrderCooldownSeconds(customerId);
      AppToggleMessage.warning(
        context,
        'Please wait $rem seconds before placing another order.',
        title: 'Cooldown Active',
      );
      return;
    }

    setState(() => _isPlacingOrder = true);

    final computedSubtotal = checkoutItems.fold(0.0, (sum, it) => sum + it.totalPrice);
    final computedShipping = checkoutItems.isEmpty ? 0.0 : checkoutItems.map((e) => e.sellerId).toSet().length * 150.0;
    final computedDiscount = widget.directItem != null ? 0.0 : cartState.discountAmount;
    final computedGrandTotal = (computedSubtotal + computedShipping - computedDiscount).clamp(0.0, double.infinity);

    final finalInstruction = _instructionController.text.trim().isNotEmpty
        ? _instructionController.text.trim()
        : _selectedInstruction;

    // 1. Create the order in SQLite with 'pending' payment status
    final order = await ref.read(ordersControllerProvider.notifier).placeOrder(
          customerId: user?.id ?? 'usr_guest',
          customerName: user?.name ?? 'Valued Customer',
          customerPhone: user?.phone ?? '',
          deliveryAddress: deliveryAddress,
          items: checkoutItems,
          discountAmount: computedDiscount,
          paymentMethod: _selectedPayment,
          customerLat: lat,
          customerLng: lng,
          deliveryInstructions: finalInstruction,
        );

    if (order == null) {
      setState(() => _isPlacingOrder = false);
      return;
    }

    // 2. Handle Payment Gateway
    bool paymentSuccess = false;
    if (_selectedPayment == PaymentMethod.cashOnDelivery) {
      // Cash on Delivery is confirmed immediately upon customer request
      paymentSuccess = true;
    } else if (_selectedPayment == PaymentMethod.payFast ||
        _selectedPayment == PaymentMethod.creditDebitCard) {
      paymentSuccess = await _runPayFastFlow(
        orderId: order.id,
        amount: computedGrandTotal,
        customerName: user?.name ?? 'Valued Customer',
        customerMobile: user?.phone ?? '',
        customerEmail: user?.email ?? '',
        isCardPath: _selectedPayment == PaymentMethod.creditDebitCard,
      );
    } else if (_selectedPayment == PaymentMethod.jazzCash) {
      final res = await PaymentService.initiateJazzCash(
        orderId: order.id,
        amount: computedGrandTotal,
        mobileNumber: _walletPhoneController.text.trim(),
        customerName: user?.name ?? 'Valued Customer',
      );
      paymentSuccess = res.success;
      if (!res.success) _showPaymentFailed(res.errorMessage ?? 'JazzCash Transaction Failed');
    } else if (_selectedPayment == PaymentMethod.easypaisa) {
      await PaymentService.markOrderAwaitingVerification(order.id);
      final res = await PaymentService.initiateEasypaisa(
        orderId: order.id,
        amount: computedGrandTotal,
        mobileNumber: _walletPhoneController.text.trim(),
        customerEmail: user?.email ?? 'customer@groclyra.app',
        paymentMethod: _walletPhoneController.text.trim().isNotEmpty ? 'MA' : 'OTC',
      );
      if (res.success && res.checkoutHtml != null) {
        paymentSuccess = await _runHostedEasypaisaFlow(
          checkoutHtml: res.checkoutHtml!,
          orderId: order.id,
          txnRefNo: res.txnRefNo!,
        ) == true;
      } else {
        await PaymentService.markOrderPaymentFailed(order.id);
        _showPaymentFailed(res.errorMessage ?? 'Easypaisa Transaction Failed');
      }
    } else if (_selectedPayment == PaymentMethod.creditDebitCard) {
      await PaymentService.markOrderAwaitingVerification(order.id);
      final res = await PaymentService.startJazzCashCheckout(
        orderId: order.id,
        amount: computedGrandTotal,
        description: 'Order ${order.orderNumber}',
      );
      if (res.success && res.checkoutHtml != null) {
        paymentSuccess = await _runHostedJazzCashFlow(
          checkoutHtml: res.checkoutHtml!,
          orderId: order.id,
          txnRefNo: res.txnRefNo!,
        ) == true;
      } else {
        await PaymentService.markOrderPaymentFailed(order.id);
        _showPaymentFailed(res.errorMessage ?? 'Card Checkout Failed');
      }
    }

    setState(() => _isPlacingOrder = false);

    // 3. Show Success Dialog if payment passed
    if (paymentSuccess && mounted) {
      if (widget.directItem == null) {
        ref.read(cartControllerProvider.notifier).clearCart();
      }
      _showSuccessDialog(order);
    }
  }

  /// PayFast hosted-checkout flow (primary online payment method).
  /// Opens the gateway's secure page; the WebView verifies the redirect
  /// signature and then asks PayFast for the AUTHORITATIVE transaction
  /// state — nothing is marked paid on the redirect alone.
  Future<bool> _runPayFastFlow({
    required String orderId,
    required double amount,
    required String customerName,
    required String customerMobile,
    required String customerEmail,
    required bool isCardPath,
  }) async {
    final checkout = await PayFastGateway.startCheckout(
      orderId: orderId,
      amount: amount,
      customerMobile: customerMobile.isNotEmpty
          ? customerMobile
          : _walletPhoneController.text.trim(),
      customerEmail: customerEmail.isNotEmpty
          ? customerEmail
          : 'customer@groclyra.app',
      customerName: customerName,
      description: isCardPath ? 'Card payment' : 'Grocery order',
    );
    if (!checkout.success || checkout.checkoutHtml == null) {
      await PaymentService.markOrderPaymentFailed(orderId);
      if (mounted) {
        // Only nudge users when PayFast itself is not provisioned yet.
        _showPaymentFailed(checkout.errorMessage ??
            (isCardPath ? 'Card checkout failed' : 'PayFast checkout failed'));
      }
      return false;
    }
    await PaymentService.markOrderAwaitingVerification(orderId);
    if (!mounted) return false;
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => PaymentWebviewScreen(
          checkoutHtml: checkout.checkoutHtml!,
          orderId: orderId,
          txnRefNo: checkout.txnRefNo!,
          gateway: PaymentGateway.payFast,
          payFastAmount: amount,
        ),
      ),
    );
    return result == true;
  }
  /// Opens the hosted Easypaisa gateway page; the WebView polls the official
  /// Transaction-Status inquiry until the gateway settles (async MA/OTC).
  /// Returns: true = confirmed paid · false = declined/cancelled ·
  /// 'pending' = still awaiting gateway decision (order kept recoverable).
  Future<Object> _runHostedEasypaisaFlow({
    required String checkoutHtml,
    required String orderId,
    required String txnRefNo,
  }) async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => PaymentWebviewScreen(
          checkoutHtml: checkoutHtml,
          orderId: orderId,
          txnRefNo: txnRefNo,
          gateway: PaymentGateway.easypaisa,
        ),
      ),
    );
    return result ?? false;
  }

  /// Opens the hosted JazzCash gateway page (cards via MPGS / wallets).
  /// The WebView verifies the pp_SecureHash appended on the return URL
  /// before trusting any success — nothing is marked paid on trust alone.
  Future<Object> _runHostedJazzCashFlow({
    required String checkoutHtml,
    required String orderId,
    required String txnRefNo,
  }) async {
    final result = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => PaymentWebviewScreen(
          checkoutHtml: checkoutHtml,
          orderId: orderId,
          txnRefNo: txnRefNo,
          gateway: PaymentGateway.jazzCash,
        ),
      ),
    );
    return result ?? false;
  }

  void _showPaymentFailed(String error) {
    if (!mounted) return;
    AppToggleMessage.error(
      context,
      'Payment transaction failed: $error',
      title: 'Payment Error',
    );
  }

  void _showSuccessDialog(OrderEntity order) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLarge)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        title: const Column(
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green, size: 54),
            SizedBox(height: 12),
            Text('Order Confirmed!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
          ],
        ),
        content: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your order #${order.orderNumber} has been placed successfully across ${order.subOrders.length} vendor stores.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.pin_rounded, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your Delivery OTP is ${order.customerOtp} (Share with rider upon arrival)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        actions: [
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              text: 'Track Live Order',
              onPressed: () {
                Navigator.pop(ctx);
                context.go(RouteNames.customerOrders);
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final cartState = ref.watch(cartControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final checkoutItems = widget.directItem != null ? [widget.directItem!] : cartState.items;

    if (checkoutItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout & Payment')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.remove_shopping_cart_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('No items to checkout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Add products to your cart before proceeding to checkout.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.go(RouteNames.customerHome),
                child: const Text('Continue Shopping'),
              ),
            ],
          ),
        ),
      );
    }

    final subtotal = checkoutItems.fold(0.0, (sum, it) => sum + it.totalPrice);
    final shippingFee = checkoutItems.isEmpty ? 0.0 : checkoutItems.map((e) => e.sellerId).toSet().length * 150.0;
    final discountAmount = widget.directItem != null ? 0.0 : cartState.discountAmount;
    final grandTotal = (subtotal + shippingFee - discountAmount).clamp(0.0, double.infinity);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout & Payment'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Delivery Address Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121722) : Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.location_on_rounded, color: themeState.palette.primaryColor, size: 20),
                            const SizedBox(width: 8),
                            const Flexible(
                              child: Text(
                                'Delivery Address',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Builder(builder: (ctx) {
                    final user = ref.watch(authControllerProvider).user;
                    final address = user?.deliveryAddress ?? user?.deliveryZone ?? 'No address saved';
                    return Text(address, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500));
                  }),
                  const SizedBox(height: 4),
                  Builder(builder: (ctx) {
                    final user = ref.watch(authControllerProvider).user;
                    final namePhone = '${user?.name ?? 'Customer'} • ${user?.phone ?? ''}';
                    return Text(namePhone, style: const TextStyle(fontSize: 12, color: Colors.grey));
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Order Items Details Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121722) : Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(Icons.inventory_2_rounded, color: themeState.palette.primaryColor, size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Order Items (${checkoutItems.fold<int>(0, (sum, it) => sum + it.quantity)})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.directItem != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.flash_on_rounded, size: 12, color: Colors.amber),
                              SizedBox(width: 2),
                              Text('Direct Buy', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber)),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const Divider(height: 20),
                  ...checkoutItems.map((item) {
                    final itemThumb = item.selectedVariant?.imageUrl ?? item.product.primaryImage;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Thumbnail
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 58,
                              height: 58,
                              child: Base64Image(
                                imageUrl: itemThumb,
                                categoryType: item.product.categoryType,
                                productTitle: item.product.title,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Info
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
                                if (item.selectedVariant != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Option: ${item.selectedVariant!.name}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '${CurrencyFormatter.format(item.unitPrice)} × ${item.quantity}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      CurrencyFormatter.format(item.totalPrice),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: themeState.palette.primaryColor,
                                      ),
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
            ),
            const SizedBox(height: 16),

            // Doorstep Instructions & Fragile Care Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121722) : Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: Colors.amber, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Doorstep Instructions & Fragile Care',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Ensure delicate tableware safety and guide your express rider',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _quickInstructions.map((inst) {
                      final isSel = _selectedInstruction == inst;
                      return ChoiceChip(
                        label: Text(inst, style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                        selected: isSel,
                        selectedColor: themeState.palette.primaryColor.withValues(alpha: 0.2),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedInstruction = inst);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _instructionController,
                    style: const TextStyle(fontSize: 12.5),
                    decoration: InputDecoration(
                      hintText: 'Add custom note for delivery rider (optional)...',
                      hintStyle: const TextStyle(fontSize: 11.5, color: Colors.grey),
                      isDense: true,
                      prefixIcon: const Icon(Icons.edit_note_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Payment Methods Selector
            Text('Select Payment Method', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...PaymentMethod.values.map((method) {
              final isSelected = _selectedPayment == method;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: SpringTouchScale(
                  onTap: () => setState(() => _selectedPayment = method),
                  child: RotatingBorderGlowCard(
                    rotateController: _glowController,
                    color: isSelected ? themeState.palette.primaryColor : (isDark ? Colors.white24 : Colors.grey),
                    secondaryColor: isSelected ? Colors.white : Colors.transparent,
                    phaseOffset: (method.index * 0.25),
                    isDark: isDark,
                    borderRadius: AppDimensions.radiusMedium,
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121722) : Colors.white,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                method == PaymentMethod.cashOnDelivery
                                    ? Icons.local_atm_rounded
                                    : (method == PaymentMethod.payFast
                                        ? Icons.shopping_cart_checkout_rounded
                                        : (method == PaymentMethod.jazzCash
                                            ? Icons
                                                .account_balance_wallet_rounded
                                            : (method ==
                                                    PaymentMethod.creditDebitCard
                                                ? Icons.credit_card_rounded
                                                : Icons
                                                    .account_balance_rounded))),
                                color: isSelected ? themeState.palette.primaryColor : Colors.grey,
                                size: 24,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(method.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isSelected ? themeState.palette.primaryColor : null)),
                                    Text(method.description, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(Icons.check_circle_rounded, color: themeState.palette.primaryColor, size: 20),
                            ],
                          ),
                          // Expand wallet input for mobile-account methods only
                          // (PayFast / hosted-card flows open the gateway's
                          // secure page instead — nothing is collected here).
                          if (isSelected &&
                              method != PaymentMethod.cashOnDelivery &&
                              method != PaymentMethod.payFast &&
                              method != PaymentMethod.creditDebitCard) ...[
                            const SizedBox(height: 14),
                            CustomTextField(
                              label: '${method.title} Mobile Number',
                              hint: 'e.g. 03XXXXXXXXX',
                              controller: _walletPhoneController,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Please ensure your phone is nearby to authorize the prompt.',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                          if (isSelected &&
                              (method == PaymentMethod.payFast ||
                                  method == PaymentMethod.creditDebitCard)) ...[
                            const SizedBox(height: 14),
                            const Text(
                              'You will be redirected to the secure checkout to complete this payment.',
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),

            // Order Breakdown Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121722) : Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Payment Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 12),
                  _buildRow('Items Total', CurrencyFormatter.format(subtotal)),
                  _buildRow('Delivery Charges', CurrencyFormatter.format(shippingFee)),
                  if (discountAmount > 0)
                    _buildRow('Voucher Discount', '-${CurrencyFormatter.format(discountAmount)}', color: Colors.green),
                  const Divider(height: 20),
                  _buildRow('Grand Total', CurrencyFormatter.format(grandTotal), isBold: true, color: themeState.palette.primaryColor),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Place Order CTA
            GradientButton(
              text: 'Confirm & Place Order (${CurrencyFormatter.format(grandTotal)})',
              isLoading: _isPlacingOrder,
              onPressed: _processOrder,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {bool isBold = false, Color? color}) {
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
              style: TextStyle(fontSize: isBold ? 14 : 13, fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: TextStyle(fontSize: isBold ? 16 : 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}
