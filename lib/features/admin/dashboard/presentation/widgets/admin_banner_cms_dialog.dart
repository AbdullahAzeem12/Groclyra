import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/database/daos/home_banner_dao.dart';
import 'package:groclyra/shared/widgets/custom_text_field.dart';
import 'package:groclyra/shared/widgets/gradient_button.dart';

class AdminBannerCmsDialog extends ConsumerStatefulWidget {
  const AdminBannerCmsDialog({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AdminBannerCmsDialog(),
    );
  }

  @override
  ConsumerState<AdminBannerCmsDialog> createState() => _AdminBannerCmsDialogState();
}

class _AdminBannerCmsDialogState extends ConsumerState<AdminBannerCmsDialog> {
  bool _isCreating = false;
  final _tagController = TextEditingController(text: '⚡ FLASH SALE • FLAT 30% OFF');
  final _titleController = TextEditingController(text: 'Exclusive Eid Crockery & Dinner Sets');
  final _subtitleController = TextEditingController(text: 'Royal porcelain, crystal bowls & non-stick cookware');
  final _badgeController = TextEditingController(text: 'LIMITED TIME DEAL');
  final _emojisController = TextEditingController(text: '🍽️✨🍲');
  String _selectedPillar = 'crockery';

  @override
  void dispose() {
    _tagController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    _badgeController.dispose();
    _emojisController.dispose();
    super.dispose();
  }

  Future<void> _addNewBanner() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final id = 'banner_${DateTime.now().millisecondsSinceEpoch}';
    final colors = _selectedPillar == 'crockery'
        ? ['#1E1B4B', '#3730A3', '#6366F1']
        : (_selectedPillar == 'grocery'
            ? ['#064E3B', '#047857', '#10B981']
            : ['#881337', '#BE123C', '#FF5722']);

    await ref.read(homeBannerDaoProvider).saveBanner({
      'id': id,
      'tag': _tagController.text.trim(),
      'title': title,
      'subtitle': _subtitleController.text.trim(),
      'badgeText': _badgeController.text.trim(),
      'floatingEmojis': _emojisController.text.trim(),
      'gradientColorsJson': jsonEncode(colors),
      'targetPillar': _selectedPillar,
      'ctaText': 'Shop Now →',
      'isActive': 1,
      'displayOrder': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });

    if (mounted) {
      setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bannersAsync = ref.watch(allHomeBannersStreamProvider);
    final banners = bannersAsync.value ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F141C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
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
          const SizedBox(height: 14),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Promotions & Marketing CMS',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    'Manage dynamic homepage banners & live customer deals',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
              IconButton(
                icon: Icon(
                  _isCreating ? Icons.close_rounded : Icons.add_circle_rounded,
                  color: const Color(0xFF4F46E5),
                  size: 26,
                ),
                tooltip: _isCreating ? 'Cancel' : 'Add New Banner',
                onPressed: () => setState(() => _isCreating = !_isCreating),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(),

          // Body
          Expanded(
            child: _isCreating
                ? _buildCreateForm(context, isDark)
                : _buildBannerList(context, banners, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerList(BuildContext context, List<Map<String, dynamic>> banners, bool isDark) {
    if (banners.isEmpty) {
      return const Center(
        child: Text('No promotional banners configured yet.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      itemCount: banners.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final b = banners[index];
        final id = b['id']?.toString() ?? '';
        final title = b['title']?.toString() ?? 'Untitled Banner';
        final tag = b['tag']?.toString() ?? '';
        final isActive = (b['isActive'] as int? ?? 1) == 1;
        final targetPillar = b['targetPillar']?.toString() ?? 'all';

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161C26) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF4F46E5).withValues(alpha: 0.4)
                  : Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isActive ? Icons.campaign_rounded : Icons.pause_circle_rounded,
                  color: isActive ? Colors.green : Colors.grey,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$tag • Target: ${targetPillar.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isActive,
                activeThumbColor: const Color(0xFF4F46E5),
                onChanged: (val) {
                  ref.read(homeBannerDaoProvider).toggleBannerStatus(id, val);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                onPressed: () {
                  ref.read(homeBannerDaoProvider).deleteBanner(id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreateForm(BuildContext context, bool isDark) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Create Live Promotional Banner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          CustomTextField(
            label: 'Banner Tagline / Discount',
            controller: _tagController,
            prefixIcon: const Icon(Icons.local_offer_rounded),
          ),
          const SizedBox(height: 10),
          CustomTextField(
            label: 'Main Headline Title',
            controller: _titleController,
            prefixIcon: const Icon(Icons.title_rounded),
          ),
          const SizedBox(height: 10),
          CustomTextField(
            label: 'Subtitle & Category Highlights',
            controller: _subtitleController,
            prefixIcon: const Icon(Icons.subtitles_rounded),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  label: 'Badge Text',
                  controller: _badgeController,
                  prefixIcon: const Icon(Icons.badge_rounded),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CustomTextField(
                  label: 'Floating Emojis',
                  controller: _emojisController,
                  prefixIcon: const Icon(Icons.emoji_emotions_rounded),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Target Marketplace Pillar:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: ['crockery', 'grocery', 'dairyBakery', 'fastFood'].map((pillar) {
              final isSel = _selectedPillar == pillar;
              return ChoiceChip(
                label: Text(pillar.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                selected: isSel,
                selectedColor: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                onSelected: (val) {
                  if (val) setState(() => _selectedPillar = pillar);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          GradientButton(
            text: 'Publish Banner to Customer Home',
            icon: Icons.publish_rounded,
            onPressed: _addNewBanner,
          ),
        ],
      ),
    );
  }
}
