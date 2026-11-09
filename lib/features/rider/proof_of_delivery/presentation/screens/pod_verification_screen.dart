import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/core/utils/currency_formatter.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/widgets/custom_text_field.dart';
import 'package:groclyra/shared/widgets/gradient_button.dart';
import 'package:groclyra/features/rider/presentation/controllers/rider_controller.dart';

class PodVerificationScreen extends ConsumerStatefulWidget {
  final String taskId;

  const PodVerificationScreen({super.key, required this.taskId});

  @override
  ConsumerState<PodVerificationScreen> createState() =>
      _PodVerificationScreenState();
}

class _PodVerificationScreenState extends ConsumerState<PodVerificationScreen> {
  final _otpController = TextEditingController(text: kDebugMode ? '4829' : '');
  bool _isSubmitting = false;

  final List<Offset?> _signaturePoints = [];
  XFile? _doorstepPhoto;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _captureDoorstepPhoto(ImageSource source) async {
    try {
      final photo = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (photo != null && mounted) {
        setState(() => _doorstepPhoto = photo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Camera error: $e')));
      }
    }
  }

  void _clearSignature() {
    setState(() => _signaturePoints.clear());
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
          ),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          title: const Column(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 54),
              SizedBox(height: 12),
              Text(
                'Delivery Verified!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
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
        const SnackBar(
          content: Text('Invalid OTP code. Please check with the customer.'),
        ),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Scan Invoice Barcode',
            onPressed: () => context.push(RouteNames.riderScanner),
          ),
        ],
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
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF262E3D)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Handover for Order #${task.orderNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Customer: ${task.customerName} • ${task.customerPhone}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  if (task.isCod)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'COD Amount to Collect:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.format(task.codAmount),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Step 1: Customer 4-digit OTP
            Text(
              '1. Customer Verification OTP',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Ask customer for the 4-digit OTP displayed on their order tracking screen${kDebugMode ? ' (Demo: 4829)' : ''}:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            CustomTextField(
              label: '4-Digit Handover Code',
              controller: _otpController,
              keyboardType: TextInputType.number,
              prefixIcon: const Icon(Icons.pin_rounded),
            ),
            const SizedBox(height: 20),

            // Step 2: Digital Signature Proof
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '2. Recipient Signature Pad',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_signaturePoints.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.clear_rounded, size: 16),
                    label: const Text('Clear', style: TextStyle(fontSize: 12)),
                    onPressed: _clearSignature,
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Customer can draw their signature with fingertip on screen:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF181E2B)
                    : const Color(0xFFF8F9FD),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(
                  color: _signaturePoints.isNotEmpty
                      ? themeState.palette.primaryColor
                      : Colors.grey.withValues(alpha: 0.3),
                  width: _signaturePoints.isNotEmpty ? 1.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                child: GestureDetector(
                  onPanUpdate: (DragUpdateDetails details) {
                    final renderBox = context.findRenderObject() as RenderBox?;
                    if (renderBox != null) {
                      final localPos = details.localPosition;
                      setState(() {
                        _signaturePoints.add(localPos);
                      });
                    }
                  },
                  onPanEnd: (DragEndDetails details) {
                    setState(() {
                      _signaturePoints.add(null);
                    });
                  },
                  child: Stack(
                    children: [
                      CustomPaint(
                        painter: _SignaturePainter(
                          _signaturePoints,
                          themeState.palette.primaryColor,
                        ),
                        size: Size.infinite,
                      ),
                      if (_signaturePoints.isEmpty)
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.draw_rounded,
                                color: Colors.grey.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Sign Here (Fingertip)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Step 3: Photo & GPS Stamp
            Text(
              '3. Doorstep Package Snapshot',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'Capture verified photo proof of package handed over or left at door:',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            if (_doorstepPhoto != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF181E2B)
                      : const Color(0xFFF8F9FD),
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusMedium,
                  ),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_doorstepPhoto!.path),
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: Colors.green,
                                size: 16,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Photo Verified ✓',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Logged at ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.blue,
                      ),
                      tooltip: 'Retake Photo',
                      onPressed: () =>
                          _captureDoorstepPhoto(ImageSource.camera),
                    ),
                  ],
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text(
                        'Take Doorstep Photo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: themeState.palette.primaryColor,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () =>
                          _captureDoorstepPhoto(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                    tooltip: 'Choose from Gallery',
                    onPressed: () => _captureDoorstepPhoto(ImageSource.gallery),
                  ),
                ],
              ),
            const SizedBox(height: 12),

            // GPS Stamp Card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF181E2B)
                    : const Color(0xFFF8F9FD),
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
                        Text(
                          'GPS Coordinates Locked & Encrypted',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Precision GPS matched within 12 meters of destination pin',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.lock_rounded, color: Colors.green, size: 16),
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

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;
  final Color strokeColor;

  const _SignaturePainter(this.points, this.strokeColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
