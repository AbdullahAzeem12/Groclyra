import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:groclyra/core/database/app_database.dart';
import 'package:groclyra/core/utils/currency_formatter.dart';
import 'package:groclyra/features/rider/data/repositories/rider_repository.dart';
import 'package:groclyra/features/rider/domain/entities/delivery_task_entity.dart';
import 'package:groclyra/features/rider/presentation/controllers/rider_controller.dart';
import 'package:groclyra/routing/route_names.dart';

/// Interactive, full-screen Barcode & QR Code parcel scanner for Express Riders.
///
/// Scans Code128 parcel barcodes and QR codes printed on Groclyra customer invoices
/// to verify merchant pick-ups and confirm doorstep handovers in real-time.
class ParcelBarcodeScannerScreen extends ConsumerStatefulWidget {
  const ParcelBarcodeScannerScreen({super.key});

  @override
  ConsumerState<ParcelBarcodeScannerScreen> createState() => _ParcelBarcodeScannerScreenState();
}

class _ParcelBarcodeScannerScreenState extends ConsumerState<ParcelBarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  late final MobileScannerController _scannerController;
  late final AnimationController _laserAnimController;
  final TextEditingController _manualInputController = TextEditingController();

  bool _isProcessingCode = false;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );

    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _laserAnimController.dispose();
    _scannerController.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessingCode) return;
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? rawValue = barcodes.first.rawValue;
    if (rawValue != null && rawValue.trim().isNotEmpty) {
      _processScannedValue(rawValue.trim());
    }
  }

  Future<void> _processScannedValue(String scannedCode) async {
    setState(() => _isProcessingCode = true);
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.click);

    // Normalize: Remove 'INV_', 'GL-', or trailing hashes if present
    final normalized = scannedCode.trim();

    try {
      // 1. Query delivery_tasks by orderNumber or id
      final taskRows = await AppDatabase.instance.query(
        'delivery_tasks',
        where: 'orderNumber LIKE ? OR id = ? OR subOrderId = ?',
        whereArgs: ['%$normalized%', normalized, normalized],
        limit: 1,
      );

      // 2. Query master orders
      final orderRows = await AppDatabase.instance.query(
        'orders',
        where: 'orderNumber LIKE ? OR id = ?',
        whereArgs: ['%$normalized%', normalized],
        limit: 1,
      );

      if (!mounted) return;

      if (taskRows.isNotEmpty || orderRows.isNotEmpty) {
        final taskData = taskRows.isNotEmpty ? taskRows.first : null;
        final orderData = orderRows.isNotEmpty ? orderRows.first : null;

        _showParcelFoundSheet(
          scannedCode: normalized,
          taskRow: taskData,
          orderRow: orderData,
        );
      } else {
        _showNotFoundDialog(normalized);
      }
    } catch (e) {
      debugPrint('[BarcodeScanner] Query error: $e');
      if (mounted) _showNotFoundDialog(normalized);
    }
  }

  void _showParcelFoundSheet({
    required String scannedCode,
    Map<String, dynamic>? taskRow,
    Map<String, dynamic>? orderRow,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final orderNum = taskRow?['orderNumber'] ?? orderRow?['orderNumber'] ?? scannedCode;
    final customer = taskRow?['customerName'] ?? orderRow?['deliveryAddress'] ?? 'Verified Customer';
    final storeName = taskRow?['sellerStoreName'] ?? 'Partner Mart';
    final address = taskRow?['customerAddress'] ?? orderRow?['deliveryAddress'] ?? 'Karachi, Sindh';
    final codAmount = (taskRow?['codAmount'] as num?)?.toDouble() ?? (orderRow?['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final currentStatus = taskRow?['status']?.toString() ?? orderRow?['status']?.toString() ?? 'available';
    final taskId = taskRow?['id']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: isDark ? const Color(0xFF131923) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Parcel Verified: #$orderNum',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'Store: $storeName • Status: ${currentStatus.toUpperCase()}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 10),

              // Customer & Dropoff info
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_rounded, size: 20, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Customer: $customer', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(address, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('COD Collection Due:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                  Text(
                    CurrencyFormatter.format(codAmount),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF10B981)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() => _isProcessingCode = false);
                      },
                      child: const Text('Scan Another'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.verified_rounded, size: 20),
                      label: Text(
                        currentStatus == 'pickedUp' || currentStatus == 'inTransit'
                            ? 'Complete Handover'
                            : 'Confirm Pickup',
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        if (!mounted) return;
                        Navigator.pop(context); // Close scanner screen

                        if (taskId.isNotEmpty) {
                          if (currentStatus == 'pickedUp' || currentStatus == 'inTransit') {
                            if (mounted) {
                              context.push(RouteNames.riderPod, extra: taskId);
                            }
                          } else {
                            // Update to pickedUp
                            await ref.read(riderRepositoryProvider).updateTaskStatus(
                              taskId,
                              DeliveryTaskStatus.pickedUp,
                            );
                            await ref.read(riderControllerProvider.notifier).loadTasks();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Order #$orderNum verified and marked Picked Up!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNotFoundDialog(String scanned) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 26),
            SizedBox(width: 10),
            Text('Barcode Not Found'),
          ],
        ),
        content: Text('No active parcel matched barcode "$scanned" in local dispatch queue.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() => _isProcessingCode = false);
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanBoxSize = size.width * 0.72;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Scan Parcel Barcode / QR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, color: Colors.white),
            tooltip: 'Toggle Torch',
            onPressed: () async {
              await _scannerController.toggleTorch();
              setState(() => _isTorchOn = !_isTorchOn);
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
            tooltip: 'Switch Camera',
            onPressed: () => _scannerController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Camera Viewfinder
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // 2. Viewfinder Overlay Darkening
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.65),
              BlendMode.srcOut,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: scanBoxSize,
                    height: scanBoxSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Viewfinder Laser & Corner Brackets
          Center(
            child: Container(
              width: scanBoxSize,
              height: scanBoxSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.8), width: 2.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  children: [
                    AnimatedBuilder(
                      animation: _laserAnimController,
                      builder: (context, _) {
                        return Positioned(
                          top: _laserAnimController.value * (scanBoxSize - 4),
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.transparent, Color(0xFF10B981), Colors.transparent],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.8),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Instructions and Manual Input
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF10B981), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Align invoice barcode or QR within frame',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.15),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                  label: const Text('Enter Barcode Manually', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text('Manual Barcode Input', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        content: TextField(
                          controller: _manualInputController,
                          decoration: InputDecoration(
                            hintText: 'e.g. GL-98214 or order ID',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () {
                              final text = _manualInputController.text.trim();
                              Navigator.pop(ctx);
                              if (text.isNotEmpty) {
                                _processScannedValue(text);
                              }
                            },
                            child: const Text('Verify'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
