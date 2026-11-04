import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/utils/currency_formatter.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import 'package:groclyra/shared/widgets/gradient_button.dart';
import 'package:groclyra/features/rider/presentation/controllers/rider_controller.dart';

class CodCashReconciliationScreen extends ConsumerWidget {
  const CodCashReconciliationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riderState = ref.watch(riderControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Cash on Delivery Ledger',
        subtitle: 'Cash Collections & Hub Remittance',
        showThemePicker: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Total Cash Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF065F46), Color(0xFF047857)],
                ),
                borderRadius: BorderRadius.circular(AppDimensions.radiusLarge),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Cash In Hand to Remit', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(
                    CurrencyFormatter.format(riderState.codCashInHand),
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text('Deposit at Hub or via JazzCash Agent before 11:00 PM', style: TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Remit Action Button
            GradientButton(
              text: 'Deposit Cash to Regional Logistics Hub',
              icon: Icons.account_balance_rounded,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Deposit slip generated. Show QR at Hub Counter.')),
                );
              },
            ),
            const SizedBox(height: 24),

            // Today's Cash Collection Records
            Text('Today\'s COD Collections', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF121722) : Colors.white,
                borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Order #GL-98214', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Customer: Fatima Zahra (Clifton)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  Text(
                    CurrencyFormatter.format(15149.0),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
