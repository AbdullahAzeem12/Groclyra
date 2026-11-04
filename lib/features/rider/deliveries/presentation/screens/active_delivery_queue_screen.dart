import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/widgets/empty_state_view.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import 'package:groclyra/features/rider/presentation/controllers/rider_controller.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';
import 'dart:ui';
class ActiveDeliveryQueueScreen extends ConsumerWidget {
  const ActiveDeliveryQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riderState = ref.watch(riderControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const GradientAppBar(
        title: 'Delivery Tasks Queue',
        subtitle: 'Available & Dispatched Jobs',
        showThemePicker: false,
      ),
      body: riderState.tasks.isEmpty
          ? const EmptyStateView(
              title: 'No Pending Dispatches',
              description: 'You are all caught up! Keep your duty ON to receive incoming delivery requests.',
              icon: Icons.done_all_rounded,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: riderState.tasks.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final task = riderState.tasks[index];
                return SpringTouchScale(
                  onTap: () => context.push('${RouteNames.riderNavigate}/${task.id}'),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.5)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Task #${task.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: task.status.color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(task.status.label, style: TextStyle(color: task.status.color, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Pickup: ${task.sellerStoreName} (${task.sellerAddress})', style: const TextStyle(fontSize: 12)),
                            Text('Drop-off: ${task.customerName} (${task.customerAddress})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${task.distanceKm} km • Est. Earning: Rs. ${task.estimatedEarnings.toInt()}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ElevatedButton(
                                  onPressed: () => context.push('${RouteNames.riderNavigate}/${task.id}'),
                                  child: const Text('Open Map', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: (50 * index).ms).slideY(begin: 0.1, duration: 300.ms);
              },
            ),
    );
  }
}
