import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/core/utils/date_time_formatter.dart';
import 'package:groclyra/features/customer/orders/presentation/controllers/orders_controller.dart';
import 'package:groclyra/shared/widgets/app_toggle_message.dart';

class LiveOrderTrackingScreen extends ConsumerWidget {
  final String orderId;

  const LiveOrderTrackingScreen({
    super.key,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final ordersState = ref.watch(ordersControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final order = ordersState.orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => ordersState.orders.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Track Order #${order.orderNumber}'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Simulated Live GPS Map View
            Container(
              height: 240,
              width: double.infinity,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage('https://images.unsplash.com/photo-1524661135-423995f22d0b?w=800&auto=format&fit=crop&q=80'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Stack(
                children: [
                  Container(color: Colors.black.withValues(alpha: 0.35)),
                  // Courier Live Location Pin
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: themeState.palette.linearGradient,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: themeState.palette.primaryColor.withValues(alpha: 0.6),
                                blurRadius: 12,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                          ),
                          child: const Text(
                            'Express Rider (12 mins away)',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // OTP Delivery Pin Card
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: themeState.palette.subtleGradient,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                      border: Border.all(color: themeState.palette.primaryColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.shield_rounded, color: themeState.palette.primaryColor, size: 32),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Handover Delivery Pin (OTP)',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                order.deliveryOtpPin,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                  color: themeState.palette.primaryColor,
                                ),
                              ),
                              const Text(
                                'Share this 4-digit code with the rider only when receiving your packages.',
                                style: TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Courier Details
                  if (order.assignedRiderName != null) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF121722) : Colors.white,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                        border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 22,
                            backgroundImage: NetworkImage('https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200'),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  order.assignedRiderName!,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                Text(
                                  order.assignedRiderVehicle ?? 'Honda 125 • KHI-LEJ-4821',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.phone_rounded, color: Colors.green),
                            onPressed: () {
                              AppToggleMessage.info(
                                context,
                                'Initiating secure call to Rider: ${order.assignedRiderPhone}',
                                title: 'Contacting Rider',
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Real-time Delivery Stepper Pipeline
                  Text('Shipment Status Tracking', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  _buildTimelineStep(
                    context: context,
                    themeState: themeState,
                    isDark: isDark,
                    title: 'Order Placed & Payment Confirmed',
                    time: DateTimeFormatter.formatDateTime(order.createdAt),
                    isCompleted: true,
                    isCurrent: false,
                    isLast: false,
                  ),
                  _buildTimelineStep(
                    context: context,
                    themeState: themeState,
                    isDark: isDark,
                    title: 'Packed by Sellers (Royal Crockery & Food Emporium)',
                    time: '15 mins after order',
                    isCompleted: true,
                    isCurrent: false,
                    isLast: false,
                  ),
                  _buildTimelineStep(
                    context: context,
                    themeState: themeState,
                    isDark: isDark,
                    title: 'Handed to Express Delivery Courier',
                    time: 'Out for Delivery • Expected by 5:30 PM',
                    isCompleted: true,
                    isCurrent: true,
                    isLast: false,
                  ),
                  _buildTimelineStep(
                    context: context,
                    themeState: themeState,
                    isDark: isDark,
                    title: 'Delivered at Doorstep',
                    time: 'Pending OTP Verification',
                    isCompleted: false,
                    isCurrent: false,
                    isLast: true,
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required BuildContext context,
    required ThemeState themeState,
    required bool isDark,
    required String title,
    required String time,
    required bool isCompleted,
    required bool isCurrent,
    required bool isLast,
  }) {
    final activeColor = themeState.palette.primaryColor;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isCompleted ? activeColor : (isDark ? const Color(0xFF262E3D) : const Color(0xFFCBD5E1)),
                shape: BoxShape.circle,
                border: isCurrent
                    ? Border.all(color: activeColor.withValues(alpha: 0.4), width: 4)
                    : null,
              ),
              child: isCompleted
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isCompleted ? activeColor : (isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                    fontSize: 13,
                    color: isCurrent ? activeColor : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
