import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/shared/widgets/empty_state_view.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import 'package:groclyra/features/admin/presentation/controllers/admin_controller.dart';

import 'package:go_router/go_router.dart';
import 'package:groclyra/routing/route_names.dart';

class SellerKycApprovalScreen extends ConsumerWidget {
  const SellerKycApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adminState = ref.watch(adminControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Merchant KYC Approvals',
        subtitle: 'CNIC, NTN & Warehouse Verification',
        showThemePicker: false,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.two_wheeler_rounded, color: Colors.white, size: 18),
            label: const Text('Rider KYC', style: TextStyle(color: Colors.white, fontSize: 12)),
            onPressed: () => context.go(RouteNames.adminRiderKyc),
          ),
        ],
      ),
      body: adminState.kycQueue.isEmpty
          ? const EmptyStateView(
              title: 'No Pending KYC',
              description: 'All seller partner onboarding documents have been verified.',
              icon: Icons.check_circle_outline_rounded,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: adminState.kycQueue.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final app = adminState.kycQueue[index];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF121722) : Colors.white,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    border: Border.all(
                      color: app.isApproved ? Colors.green : (isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
                      width: app.isApproved ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(app.storeName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: app.isApproved ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              app.isApproved ? 'KYC Approved ✓' : 'Under Review',
                              style: TextStyle(
                                color: app.isApproved ? Colors.green : Colors.orange,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Owner: ${app.ownerName} • CNIC: ${app.cnic}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('Phone: ${app.phone} • Focus: ${app.categoryFocus}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('Warehouse: ${app.address}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const Divider(height: 20),
                      if (!app.isApproved)
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                              onPressed: () {
                                ref.read(adminControllerProvider.notifier).moderateKyc(app.id, false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Rejected KYC for ${app.storeName}')),
                                );
                              },
                              child: const Text('Reject'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              onPressed: () {
                                ref.read(adminControllerProvider.notifier).moderateKyc(app.id, true);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Approved KYC for ${app.storeName}. Store is now LIVE.')),
                                );
                              },
                              child: const Text('Approve & Verify'),
                            ),
                          ],
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
