import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../routing/route_names.dart';
import '../../data/repositories/firestore_user_repository.dart';
import '../../domain/entities/account_status.dart';
import '../../domain/entities/user_entity.dart';
import '../controllers/auth_controller.dart';
import '../widgets/floating_background.dart';

class AccountPendingScreen extends ConsumerWidget {
  const AccountPendingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final palette = themeState.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final user = authState.user;

    // Real-time listener for bidirectional synchronization with Firestore
    if (user != null) {
      ref.listen<AsyncValue<UserEntity?>>(userStreamProvider(user.id), (previous, next) {
        final liveUser = next.value;
        if (liveUser != null && liveUser.accountStatus == AccountStatus.active) {
          ref.read(authControllerProvider.notifier).updateUserSession(liveUser);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('🎉 Your ${liveUser.role.displayName} application has been approved! Redirecting...'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 2),
            ),
          );

          if (liveUser.role == UserRole.rider) {
            context.go(RouteNames.riderDashboard);
          } else if (liveUser.role == UserRole.seller) {
            context.go(RouteNames.sellerDashboard);
          }
        }
      });
    }

    final liveUserAsync = user != null ? ref.watch(userStreamProvider(user.id)) : null;
    final displayUser = liveUserAsync?.value ?? user;
    final roleName = displayUser?.role.displayName ?? 'Partner';
    final isRejected = displayUser?.accountStatus == AccountStatus.disabled;
    final isSuspended = displayUser?.accountStatus == AccountStatus.suspended;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0D14) : const Color(0xFFF8F9FD),
      body: Stack(
        children: [
          FloatingBackground(palette: palette, isDark: isDark),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppDimensions.p24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Badge icon
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (isRejected ? Colors.red : (isSuspended ? Colors.orange : const Color(0xFFF59E0B)))
                              .withValues(alpha: 0.15),
                          border: Border.all(
                            color: (isRejected ? Colors.red : (isSuspended ? Colors.orange : const Color(0xFFF59E0B)))
                                .withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            isRejected
                                ? Icons.cancel_outlined
                                : (isSuspended ? Icons.block_flipped : Icons.pending_actions_rounded),
                            size: 46,
                            color: isRejected
                                ? Colors.red
                                : (isSuspended ? Colors.orange : const Color(0xFFF59E0B)),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.p24),

                      Text(
                        isRejected
                            ? '$roleName Application Rejected'
                            : (isSuspended ? '$roleName Account Suspended' : '$roleName Application Under Review'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                      ),
                      const SizedBox(height: AppDimensions.p12),

                      Text(
                        isRejected
                            ? 'Thank you for your interest, ${displayUser?.name ?? 'Applicant'}. Unfortunately, your application could not be approved at this time.'
                            : (isSuspended
                                ? 'Your ${displayUser?.role.displayName} portal access has been temporarily suspended by platform administration.'
                                : 'Thank you for registering with Groclyra, ${displayUser?.name ?? 'Applicant'}! Our marketplace administration team is verifying your credentials and documentation.'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.p24),

                      // Application review step card or rejected alert
                      if (isRejected)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppDimensions.p20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1F1215) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Review Decision',
                                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                displayUser?.adminDepartment != null
                                    ? 'Notes: ${displayUser?.adminDepartment}'
                                    : 'Your submitted documentation does not meet current verification standards. Please contact support to appeal or reapply.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.p20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF131A29) : Colors.white,
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                            border: Border.all(
                              color: isDark ? const Color(0xFF263248) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (displayUser?.role == UserRole.rider) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ID / CNIC: ${displayUser?.cnicNumber ?? 'Not provided'}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Registration Date: ${displayUser?.createdAt.toLocal().toString().split(' ')[0]}',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.visible,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                              _buildTimelineStep(
                                icon: Icons.check_circle_rounded,
                                title: 'Application Submitted',
                                subtitle: 'Account details recorded securely',
                                isDone: true,
                                isDark: isDark,
                                palette: palette,
                              ),
                              const Divider(height: 24),
                              _buildTimelineStep(
                                icon: Icons.hourglass_top_rounded,
                                title: 'Identity & Catalog Review',
                                subtitle: 'Estimated turnaround: 1-2 business days',
                                isDone: false,
                                isCurrent: true,
                                isDark: isDark,
                                palette: palette,
                              ),
                              const Divider(height: 24),
                              _buildTimelineStep(
                                icon: Icons.storefront_rounded,
                                title: 'Portal Activation',
                                subtitle: 'Instant access once verified by admin',
                                isDone: false,
                                isDark: isDark,
                                palette: palette,
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: AppDimensions.p32),

                      // Sign Out button
                      OutlinedButton.icon(
                        onPressed: () async {
                          await ref.read(authControllerProvider.notifier).logout();
                          if (context.mounted) {
                            context.go(RouteNames.login);
                          }
                        },
                        icon: const Icon(Icons.logout_rounded, size: 18),
                        label: const Text('Sign Out to Portal Login'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          foregroundColor: isDark ? Colors.white : const Color(0xFF0F172A),
                          side: BorderSide(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required IconData icon,
    required String title,
    required String subtitle,
    bool isDone = false,
    bool isCurrent = false,
    required bool isDark,
    required dynamic palette,
  }) {
    final color = isDone
        ? const Color(0xFF10B981)
        : (isCurrent ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8));

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: AppDimensions.p12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
