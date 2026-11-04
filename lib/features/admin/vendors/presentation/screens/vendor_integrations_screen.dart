import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/core/utils/currency_formatter.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';
import 'package:groclyra/shared/widgets/app_toggle_message.dart';
import 'package:groclyra/shared/widgets/empty_state_view.dart';
import 'package:groclyra/shared/widgets/shimmer_loading.dart';
import 'package:groclyra/features/catalog/domain/entities/category_entity.dart';
import '../../domain/entities/vendor_integration_entity.dart';
import '../../domain/entities/catalog_sync_run_entity.dart';
import '../../data/repositories/vendor_catalog_repository.dart';

class VendorIntegrationsScreen extends ConsumerStatefulWidget {
  const VendorIntegrationsScreen({super.key});

  @override
  ConsumerState<VendorIntegrationsScreen> createState() => _VendorIntegrationsScreenState();
}

class _VendorIntegrationsScreenState extends ConsumerState<VendorIntegrationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Set<String> _syncingVendorIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleSyncNow(VendorIntegrationEntity integration) async {
    setState(() => _syncingVendorIds.add(integration.id));
    AppToggleMessage.info(
      context,
      'Connecting to ${integration.vendorName} live API...',
      title: 'Realtime Sync Initiated',
    );

    try {
      final repo = ref.read(vendorCatalogRepositoryProvider);
      final run = await repo.triggerLiveSync(integration);

      if (mounted) {
        setState(() => _syncingVendorIds.remove(integration.id));
        if (run.status == SyncRunStatus.succeeded) {
          AppToggleMessage.success(
            context,
            'Successfully fetched & verified ${run.productsCreated} items from ${integration.vendorName}.',
            title: 'Live Catalog Synced! 🚀',
          );
        } else {
          AppToggleMessage.error(
            context,
            run.errorMessage ?? 'Sync completed with warnings. Check logs.',
            title: 'Sync Warning',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _syncingVendorIds.remove(integration.id));
        AppToggleMessage.error(context, 'Sync error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = ref.watch(themeControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final integrationsAsync = ref.watch(vendorIntegrationsStreamProvider);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Vendor Integrations & Live Marts'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: themeState.palette.primaryColor,
          unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
          indicatorColor: themeState.palette.primaryColor,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.storefront_rounded), text: 'Active Marts'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Sync Runs'),
            Tab(icon: Icon(Icons.account_balance_wallet_rounded), text: 'Earning Cuts'),
          ],
        ),
      ),
      body: integrationsAsync.when(
        data: (integrations) => TabBarView(
          controller: _tabController,
          children: [
            _buildActiveMartsTab(context, integrations, isDark, themeState),
            _buildSyncRunsTab(context, isDark, themeState),
            _buildEarningCutsTab(context, integrations, isDark, themeState),
          ],
        ),
        loading: () => _buildLoadingState(isDark),
        error: (err, stack) => EmptyStateView(
          icon: Icons.cloud_off_rounded,
          title: 'Unable to load integrations',
          description: err.toString(),
          actionButtonText: 'Retry',
          onAction: () => ref.refresh(vendorIntegrationsStreamProvider),
        ),
      ),
    );
  }

  Widget _buildActiveMartsTab(
    BuildContext context,
    List<VendorIntegrationEntity> integrations,
    bool isDark,
    dynamic themeState,
  ) {
    final totalSynced = integrations.fold<int>(0, (sum, i) => sum + i.totalProductsSynced);
    final totalSales = integrations.fold<double>(0.0, (sum, i) => sum + i.totalGrossSales);

    return ListView(
      padding: const EdgeInsets.all(AppDimensions.p16),
      children: [
        // Real-Time Stats Overview Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: themeState.palette.linearGradient,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            boxShadow: [
              BoxShadow(
                color: themeState.palette.primaryColor.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Multi-Vendor Live Network',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_tethering_rounded, color: Colors.white, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Realtime Sync ON',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _buildStatItem('Active Marts', '${integrations.length}', Icons.hub_rounded),
                  _buildStatItem('Synced Items', '$totalSynced', Icons.inventory_2_rounded),
                  _buildStatItem('Network GMV', CurrencyFormatter.format(totalSales), Icons.trending_up_rounded),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Section Title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Connected Shops, Marts & Malls',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              '${integrations.length} Active Feeds',
              style: TextStyle(
                fontSize: 12,
                color: themeState.palette.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Mart Cards
        ...integrations.map((integration) {
          final isSyncing = _syncingVendorIds.contains(integration.id);
          return _buildMartCard(context, integration, isSyncing, isDark, themeState);
        }),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMartCard(
    BuildContext context,
    VendorIntegrationEntity item,
    bool isSyncing,
    bool isDark,
    dynamic themeState,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _getCategoryColor(item.categoryType).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _getCategoryIcon(item.categoryType),
                  color: _getCategoryColor(item.categoryType),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.vendorName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.city} • ${item.businessAddress}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Connected',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Details row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Platform Cut: ${(item.platformCommissionRate * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: themeState.palette.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Vendor Payout: ${((1.0 - item.platformCommissionRate) * 100).toStringAsFixed(1)}%',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${item.totalProductsSynced} Products Synced',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.lastSyncStatus ?? 'Sync schedule: every ${item.syncIntervalMinutes}m',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons: Sync Now & Inspect Staged
          Row(
            children: [
              Expanded(
                child: SpringTouchScale(
                  onTap: isSyncing ? null : () => _handleSyncNow(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSyncing
                          ? Colors.grey.withValues(alpha: 0.3)
                          : themeState.palette.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSyncing ? Colors.transparent : themeState.palette.primaryColor,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isSyncing)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(Icons.sync_rounded, color: themeState.palette.primaryColor, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          isSyncing ? 'Fetching...' : 'Sync Live Products',
                          style: TextStyle(
                            color: isSyncing ? Colors.grey : themeState.palette.primaryColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SpringTouchScale(
                onTap: () => _showStagedProductsSheet(context, item, isDark, themeState),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Inspect Staging',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSyncRunsTab(BuildContext context, bool isDark, dynamic themeState) {
    final runsAsync = ref.watch(catalogSyncRunsStreamProvider);

    return runsAsync.when(
      data: (runs) {
        if (runs.isEmpty) {
          return const EmptyStateView(
            icon: Icons.history_rounded,
            title: 'No Sync Runs Yet',
            description: 'Trigger a manual sync from the Active Marts tab to start live product ingestion.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(AppDimensions.p16),
          itemCount: runs.length,
          itemBuilder: (context, index) {
            final run = runs[index];
            final isSuccess = run.status == SyncRunStatus.succeeded;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: isSuccess ? const Color(0xFF10B981) : Colors.red,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          run.vendorName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${run.productsCreated} items verified & updated',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${run.startedAt.hour.toString().padLeft(2, '0')}:${run.startedAt.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => _buildLoadingState(isDark),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildEarningCutsTab(
    BuildContext context,
    List<VendorIntegrationEntity> integrations,
    bool isDark,
    dynamic themeState,
  ) {
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.p16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Two-Sided Commission & Profit Model',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Vendors earn instant reach, automated online store cataloging, and professional rider deliveries. Groclyra retains agreed platform commission.',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),
              _buildCutRow('Supermarkets & Marts', '6.5%', '93.5%', const Color(0xFF0077B6)),
              _buildCutRow('Fast Food & Restaurants', '12.0%', '88.0%', const Color(0xFFFF6B35)),
              _buildCutRow('Dairy & Fresh Bakeries', '8.0%', '92.0%', const Color(0xFF10B981)),
              _buildCutRow('Crockery & Luxury Dining', '14.0%', '86.0%', const Color(0xFF8B5CF6)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Live Mart Revenue & Payout Ledger',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        ...integrations.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.vendorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    const SizedBox(height: 3),
                    Text(
                      'Commission: ${(item.platformCommissionRate * 100).toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 11, color: themeState.palette.primaryColor),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Payable: ${CurrencyFormatter.format(item.totalVendorPayable)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Groclyra Cut: ${CurrencyFormatter.format(item.totalCommissionEarned)}',
                      style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildCutRow(String category, String platformCut, String vendorCut, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(category, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
          ),
          Text(
            'Cut: $platformCut (Vendor: $vendorCut)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.p16),
      itemCount: 4,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 12.0),
        child: ShimmerBox(width: double.infinity, height: 120, borderRadius: 12),
      ),
    );
  }

  Color _getCategoryColor(MainCategoryType type) {
    switch (type) {
      case MainCategoryType.grocery:
        return const Color(0xFF0077B6);
      case MainCategoryType.dairyBakery:
        return const Color(0xFF10B981);
      case MainCategoryType.fastFood:
        return const Color(0xFFFF6B35);
      case MainCategoryType.crockery:
        return const Color(0xFF8B5CF6);
    }
  }

  IconData _getCategoryIcon(MainCategoryType type) {
    switch (type) {
      case MainCategoryType.grocery:
        return Icons.shopping_basket_rounded;
      case MainCategoryType.dairyBakery:
        return Icons.bakery_dining_rounded;
      case MainCategoryType.fastFood:
        return Icons.fastfood_rounded;
      case MainCategoryType.crockery:
        return Icons.dinner_dining_rounded;
    }
  }

  void _showStagedProductsSheet(
    BuildContext context,
    VendorIntegrationEntity item,
    bool isDark,
    dynamic themeState,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Consumer(
              builder: (context, ref, _) {
                final stagedAsync = ref.watch(stagedProductsStreamProvider(item.id));

                return Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${item.vendorName} — Staged Catalog',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Isolated staging area • Safe from customer view',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.pop(modalContext),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.shield_outlined, color: Colors.amber, size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Staged items require verified order readiness and inventory authority before customer publication.',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: stagedAsync.when(
                        data: (products) {
                          if (products.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No Staged Products Yet',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Tap "Sync Live Products" on the mart card to ingest items.',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final p = products[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: p.images.isNotEmpty
                                            ? Image.network(
                                                p.images.first,
                                                width: 52,
                                                height: 52,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  width: 52,
                                                  height: 52,
                                                  color: Colors.grey[300],
                                                  child: const Icon(Icons.broken_image_rounded, size: 24),
                                                ),
                                              )
                                            : Container(
                                                width: 52,
                                                height: 52,
                                                color: Colors.grey[300],
                                                child: const Icon(Icons.shopping_bag_outlined, size: 24),
                                              ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              p.title,
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              'SKU: ${p.externalPosId ?? p.id} • ${p.categoryName}',
                                              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  CurrencyFormatter.format(p.salePrice),
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: themeState.palette.primaryColor,
                                                  ),
                                                ),
                                                if (p.discountPercentage > 0) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.withValues(alpha: 0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      '-${p.discountPercentage}%',
                                                      style: const TextStyle(
                                                        color: Colors.red,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Staged',
                                          style: TextStyle(
                                            color: Color(0xFF10B981),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (err, _) => Center(child: Text('Error loading staged items: $err')),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
