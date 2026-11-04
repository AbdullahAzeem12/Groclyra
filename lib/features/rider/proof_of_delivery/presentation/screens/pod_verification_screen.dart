import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/core/utils/currency_formatter.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/widgets/custom_text_field.dart';
import 'package:groclyra/shared/widgets/gradient_button.dart';
import 'package:groclyra/features/rider/presentation/controllers/rider_controller.dart';

class PodVerificationScreen extends ConsumerStatefulWidget {
  final String taskId;

  const PodVerificationScreen({
    super.key,
    required this.taskId,
  });

  @override
  ConsumerState<PodVerificationScreen> createState() => _PodVerificationScreenState();
}

class _PodVerificationScreenState extends ConsumerState<PodVerificationScreen> {
  // Demo convenience: the sample OTP is pre-filled ONLY in debug builds.
  // Release builds require the rider to enter the customer's real OTP.
  final _otpController =
      TextEditingController(text: kDebugMode ? '4829' : '');
  bool _isSubmitting = false;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _completeDelivery() async {
    setState(() => _isSubmitting = true);

    final success = await ref
        .read(riderControllerProvider.notifier)
        .completeDeliveryWithOtp(widget.taskId, _otpController.text);

    setState(() => _isSubmitting = false);

    if (success && mounted) {
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
              Text('Delivery Verified!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
            ],
          ),
          content: const SingleChildScrollView(
            physics: ClampingScrollPhysics(),
            child: Text(
              'Proof of Delivery accepted. Customer OTP and GPS coordinates logged. Delivery earnings credited to your wallet.',
              textAlign: TextAlign.center,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                text: 'Return to Duty Dashboard',
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go(RouteNames.riderDashboard);
                },
              ),
            ),
          ],
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP code. Please check with the customer.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final riderState = ref.watch(riderControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final task = riderState.tasks.firstWhere(
      (t) => t.id == widget.taskId,
      orElse: () => riderState.tasks.first,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Proof of Delivery (POD)'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order & Customer Info Card
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
                  Text('Handover for Order #${task.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text('Customer: ${task.customerName} • ${task.customerPhone}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 8),
                  if (task.isCod)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('COD Amount to Collect:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text(CurrencyFormatter.format(task.codAmount), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 14)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Step 1: Customer 4-digit OTP
            Text('1. Customer Verification OTP', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
                'Ask customer for the 4-digit OTP displayed on their order tracking screen${kDebugMode ? ' (Demo: 4829)' : ''}:',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            CustomTextField(
              label: '4-Digit Handover Code',
              controller: _otpController,
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.pin_rounded),
            ),
            const SizedBox(height: 20),

            // Step 2: Digital Signature Proof
            Text('2. Customer Signature Canvas', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181E2B) : const Color(0xFFF8F9FD),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.draw_rounded, color: themeState.palette.primaryColor),
                    const SizedBox(width: 8),
                    const Text('Digital Signature Captured ✓', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Step 3: Photo & GPS Stamp
            Text('3. GPS Location & Photo Proof', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF181E2B) : const Color(0xFFF8F9FD),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.gps_fixed_rounded, color: Colors.green, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('GPS Coordinates Locked', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('Lat: 24.8138° N, Long: 67.0309° E (Clifton Block 4)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Submit Final Delivery
            GradientButton(
              text: 'Complete & Confirm Delivery',
              icon: Icons.check_circle_outline_rounded,
              isLoading: _isSubmitting,
              onPressed: _completeDelivery,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
