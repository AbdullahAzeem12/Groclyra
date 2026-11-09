import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/features/auth/domain/entities/account_status.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';
import 'package:groclyra/routing/route_names.dart';
import 'package:groclyra/shared/widgets/empty_state_view.dart';
import 'package:groclyra/shared/widgets/gradient_app_bar.dart';
import '../../../presentation/controllers/admin_controller.dart';
import '../../domain/entities/rider_kyc_application.dart';

class RiderKycApprovalScreen extends ConsumerStatefulWidget {
  const RiderKycApprovalScreen({super.key});

  @override
  ConsumerState<RiderKycApprovalScreen> createState() => _RiderKycApprovalScreenState();
}

class _RiderKycApprovalScreenState extends ConsumerState<RiderKycApprovalScreen> {
  String _searchQuery = '';
  String _filter = 'pending'; // 'all', 'pending', 'approved', 'rejected'
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RiderKycApplication> _filterList(List<RiderKycApplication> list) {
    return list.where((app) {
      final matchesSearch = _searchQuery.isEmpty ||
          app.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          app.phone.contains(_searchQuery) ||
          app.vehicleNumber.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          app.deliveryZone.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          app.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          app.id.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      switch (_filter) {
        case 'pending':
          return app.isPending;
        case 'approved':
          return app.isApproved;
        case 'rejected':
          return app.isRejected || app.isSuspended;
        default:
          return true;
      }
    }).toList();
  }

  void _showActionDialog({
    required BuildContext context,
    required RiderKycApplication application,
    required AccountStatus targetStatus,
    required String title,
    required String actionLabel,
    required Color actionColor,
    bool requireNotes = false,
  }) {
    final notesController = TextEditingController();
    final currentAdminId = ref.read(authControllerProvider).user?.id ?? 'admin_console';

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Applicant: ${application.name}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'Vehicle: ${application.vehicleNumber} • Zone: ${application.deliveryZone}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: requireNotes ? 'Reason / Required Documents *' : 'Optional Administrative Notes',
                    hintText: targetStatus == AccountStatus.active
                        ? 'e.g., Verified license & registration card'
                        : 'e.g., Incomplete driving license scan, please re-upload',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          foregroundColor: Colors.pink,
                        ),
                        onPressed: () => Navigator.of(dialogCtx).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 3,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: actionColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          final notes = notesController.text.trim();
                          if (requireNotes && notes.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please provide a reason or document details')),
                            );
                            return;
                          }

                          Navigator.of(dialogCtx).pop();

                          try {
                            await ref.read(adminControllerProvider.notifier).reviewRiderKyc(
                                  riderId: application.id,
                                  newStatus: targetStatus,
                                  adminId: currentAdminId,
                                  notes: notes.isNotEmpty ? notes : null,
                                );

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Successfully updated ${application.name} to ${targetStatus.label}'),
                                  backgroundColor: actionColor,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error updating application: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            actionLabel,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allRiders = adminState.riderKycQueue;
    final filteredRiders = _filterList(allRiders);

    final pendingCount = allRiders.where((r) => r.isPending).length;
    final approvedCount = allRiders.where((r) => r.isApproved).length;

    return Scaffold(
      appBar: GradientAppBar(
        title: 'Rider KYC Applications',
        subtitle: 'Identity, License & Fleet Verification • Live Sync ($pendingCount Pending)',
        showThemePicker: false,
        actions: [
          IconButton(
            tooltip: 'Live Sync from Database',
            icon: const Icon(Icons.sync_rounded, color: Colors.white, size: 20),
            onPressed: () => ref.read(adminControllerProvider.notifier).loadDashboard(),
          ),
          TextButton.icon(
            icon: const Icon(Icons.storefront_outlined, color: Colors.white, size: 18),
            label: const Text('Seller KYC', style: TextStyle(color: Colors.white, fontSize: 12)),
            onPressed: () => context.go(RouteNames.adminKyc),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121722) : Colors.white,
              border: Border(
                bottom: BorderSide(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search rider name, phone, vehicle plate, or zone...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('pending', 'Pending ($pendingCount)', Colors.orange),
                      const SizedBox(width: 8),
                      _buildFilterChip('approved', 'Active Fleet ($approvedCount)', Colors.green),
                      const SizedBox(width: 8),
                      _buildFilterChip('rejected', 'Rejected / Suspended', Colors.red),
                      const SizedBox(width: 8),
                      _buildFilterChip('all', 'All Applications (${allRiders.length})', Colors.blue),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Applications List with Realtime Firestore Sync & Pull-to-Refresh
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.read(adminControllerProvider.notifier).loadDashboard(),
              child: adminState.isLoading && allRiders.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(),
                    )
                  : filteredRiders.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) => SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minHeight: constraints.maxHeight),
                              child: Center(
                                child: EmptyStateView(
                                  title: _filter == 'pending' ? 'No Pending Rider KYC' : 'No Applications Found',
                                  description: _filter == 'pending'
                                      ? 'All rider applicant credentials have been reviewed. Realtime sync is active directly with Cloud Firestore.'
                                      : 'No applicant records match your current search or filter criteria.',
                                  icon: _filter == 'pending' ? Icons.verified_user_rounded : Icons.search_off_rounded,
                                ),
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredRiders.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final app = filteredRiders[index];
                            return _buildRiderApplicationCard(context, app, isDark);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, Color activeColor) {
    final isSelected = _filter == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : null,
        ),
      ),
      selected: isSelected,
      selectedColor: activeColor,
      onSelected: (_) => setState(() => _filter = key),
    );
  }

  Widget _buildRiderApplicationCard(BuildContext context, RiderKycApplication app, bool isDark) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final formattedDate = dateFormat.format(app.submittedAt);

    Color statusColor;
    String statusLabel;
    if (app.isApproved) {
      statusColor = Colors.green;
      statusLabel = 'Active Fleet ✓';
    } else if (app.isPending) {
      statusColor = Colors.orange;
      statusLabel = 'Under Review';
    } else if (app.isSuspended) {
      statusColor = Colors.deepOrange;
      statusLabel = 'Suspended';
    } else {
      statusColor = Colors.red;
      statusLabel = 'Rejected';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121722) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: app.isApproved ? Colors.green.withValues(alpha: 0.5) : (isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
          width: app.isApproved ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name, Avatar, Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withValues(alpha: 0.15),
                ),
                child: const Center(
                  child: Icon(Icons.two_wheeler_rounded, color: Colors.orange, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'App ID: ${app.id.substring(0, app.id.length >= 8 ? 8 : app.id.length)}... • Reg: $formattedDate',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Detail Grid: Phone, Email, Vehicle, Zone
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D111A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.phone_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        app.phone.isNotEmpty ? app.phone : 'Not provided',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.email_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        app.email,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.directions_bike_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '${app.vehicleType}: ${app.vehicleNumber}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        app.deliveryZone,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Document Checklist
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildDocTag('CNIC: ${app.cnic}', Icons.badge_outlined, Colors.blue),
              _buildDocTag('License: ${app.licenseNumber}', Icons.card_membership_rounded, Colors.purple),
            ],
          ),

          if (app.adminNotes != null && app.adminNotes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Text(
                'Admin Note: ${app.adminNotes}',
                style: const TextStyle(fontSize: 11, color: Colors.amber, fontStyle: FontStyle.italic),
              ),
            ),
          ],

          const Divider(height: 24),

          // Admin Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              if (app.isPending) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  onPressed: () => _showActionDialog(
                    context: context,
                    application: app,
                    targetStatus: AccountStatus.disabled,
                    title: 'Reject Rider Application',
                    actionLabel: 'Confirm Rejection',
                    actionColor: Colors.red,
                    requireNotes: true,
                  ),
                  label: const Text('Reject'),
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_note_rounded, size: 16),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.amber),
                  onPressed: () => _showActionDialog(
                    context: context,
                    application: app,
                    targetStatus: AccountStatus.pending,
                    title: 'Request Documents / Update',
                    actionLabel: 'Send Request',
                    actionColor: Colors.amber,
                    requireNotes: true,
                  ),
                  label: const Text('Request Docs'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () => _showActionDialog(
                    context: context,
                    application: app,
                    targetStatus: AccountStatus.active,
                    title: 'Approve & Activate Rider',
                    actionLabel: 'Approve & Grant Fleet Access',
                    actionColor: Colors.green,
                  ),
                  label: const Text('Approve & Verify'),
                ),
              ] else if (app.isApproved) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.block_flipped, size: 16),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                  onPressed: () => _showActionDialog(
                    context: context,
                    application: app,
                    targetStatus: AccountStatus.suspended,
                    title: 'Suspend Rider Fleet Access',
                    actionLabel: 'Confirm Suspension',
                    actionColor: Colors.orange,
                    requireNotes: true,
                  ),
                  label: const Text('Suspend Access'),
                ),
              ] else ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.restart_alt_rounded, size: 16),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  onPressed: () => _showActionDialog(
                    context: context,
                    application: app,
                    targetStatus: AccountStatus.active,
                    title: 'Re-activate Rider Account',
                    actionLabel: 'Re-activate Account',
                    actionColor: Colors.green,
                  ),
                  label: const Text('Re-activate'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDocTag(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
