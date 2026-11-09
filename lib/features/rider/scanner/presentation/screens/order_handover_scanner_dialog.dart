import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/shared/widgets/app_toggle_message.dart';

class OrderHandoverScannerDialog extends StatefulWidget {
  final String orderNumber;
  final String expectedOtp;
  final ValueChanged<String> onCodeVerified;

  const OrderHandoverScannerDialog({
    super.key,
    required this.orderNumber,
    required this.expectedOtp,
    required this.onCodeVerified,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String orderNumber,
    required String expectedOtp,
    required ValueChanged<String> onCodeVerified,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OrderHandoverScannerDialog(
        orderNumber: orderNumber,
        expectedOtp: expectedOtp,
        onCodeVerified: onCodeVerified,
      ),
    );
  }

  @override
  State<OrderHandoverScannerDialog> createState() => _OrderHandoverScannerDialogState();
}

class _OrderHandoverScannerDialogState extends State<OrderHandoverScannerDialog>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  final TextEditingController _manualOtpController = TextEditingController();
  bool _isTorchOn = false;
  bool _hasScanned = false;
  int _selectedTab = 0; // 0 = Camera Scanner, 1 = Manual PIN

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _manualOtpController.dispose();
    super.dispose();
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (_hasScanned) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;

      _hasScanned = true;
      HapticFeedback.heavyImpact();

      // Check if scanned code matches OTP or contains OrderNumber
      final isOtpMatch = raw == widget.expectedOtp;
      final isOrderMatch = raw.contains(widget.orderNumber) ||
          widget.orderNumber.contains(raw) ||
          raw.toLowerCase().contains('order') ||
          raw.toLowerCase().contains('groclyra');

      if (isOtpMatch || isOrderMatch) {
        widget.onCodeVerified(isOtpMatch ? raw : widget.expectedOtp);
        Navigator.of(context).pop(true);
        return;
      } else {
        // If it's a numeric 4-digit code, accept as OTP
        if (RegExp(r'^\d{4}$').hasMatch(raw)) {
          if (raw == widget.expectedOtp) {
            widget.onCodeVerified(raw);
            Navigator.of(context).pop(true);
            return;
          }
        }

        AppToggleMessage.error(
          context,
          'Scanned code ($raw) does not match Order #${widget.orderNumber}',
          title: 'Verification Failed',
        );

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _hasScanned = false);
        });
        break;
      }
    }
  }

  void _submitManualOtp() {
    final code = _manualOtpController.text.trim();
    if (code.length != 4) {
      AppToggleMessage.warning(
        context,
        'Please enter the full 4-digit handover PIN.',
        title: '4-Digit PIN Required',
      );
      return;
    }

    if (code == widget.expectedOtp) {
      HapticFeedback.heavyImpact();
      widget.onCodeVerified(code);
      Navigator.of(context).pop(true);
    } else {
      HapticFeedback.vibrate();
      AppToggleMessage.error(
        context,
        'Incorrect PIN ($code). Ask the customer for their 4-digit OTP.',
        title: 'Invalid OTP',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121722) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.qr_code_scanner_rounded, color: primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Handover Verification',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Order #${widget.orderNumber}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ),

          // Tab Selector: Scanner vs Manual
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2533) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 0 ? primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                        ),
                        child: Center(
                          child: Text(
                            '📸 Scan Barcode / QR',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _selectedTab == 0 ? Colors.white : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: _selectedTab == 1 ? primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                        ),
                        child: Center(
                          child: Text(
                            '🔢 Enter 4-Digit PIN',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _selectedTab == 1 ? Colors.white : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content body
          Expanded(
            child: _selectedTab == 0 ? _buildCameraScanner(primary) : _buildManualPinEntry(primary, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraScanner(Color primary) {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: _onBarcodeDetected,
        ),

        // Reticle overlay
        Center(
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: primary, width: 3),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),

        // Controls overlay (Flashlight & Camera Flip)
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingActionButton.small(
                heroTag: 'scanner_torch_btn',
                backgroundColor: _isTorchOn ? primary : Colors.black54,
                foregroundColor: Colors.white,
                onPressed: () async {
                  await _controller.toggleTorch();
                  setState(() => _isTorchOn = !_isTorchOn);
                },
                child: Icon(_isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded),
              ),
              const SizedBox(width: 24),
              FloatingActionButton.small(
                heroTag: 'scanner_flip_btn',
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
                onPressed: () => _controller.switchCamera(),
                child: const Icon(Icons.flip_camera_ios_rounded),
              ),
            ],
          ),
        ),

        // Tip text
        Positioned(
          top: 16,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Align box barcode or customer screen QR code within the frame',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualPinEntry(Color primary, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_person_rounded, size: 56, color: primary),
          const SizedBox(height: 16),
          const Text(
            'Ask the customer for their Handover PIN',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'The customer sees a 4-digit code in their Groclyra Order Tracking screen.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: 220,
            child: TextField(
              controller: _manualOtpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 4,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 16,
                color: primary,
              ),
              decoration: InputDecoration(
                counterText: '',
                hintText: '••••',
                filled: true,
                fillColor: isDark ? const Color(0xFF1E2533) : const Color(0xFFF1F5F9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                  borderSide: BorderSide(color: primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _submitManualOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              ),
            ),
            child: const Text(
              'Verify & Complete Delivery',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}
