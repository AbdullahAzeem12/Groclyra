import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/core/constants/app_dimensions.dart';
import 'package:groclyra/core/theme/theme_controller.dart';
import 'package:groclyra/features/auth/presentation/controllers/auth_controller.dart';
import 'package:groclyra/features/catalog/domain/entities/product_entity.dart';
import 'package:groclyra/features/customer/reviews/domain/entities/review_entity.dart';
import 'package:groclyra/features/customer/reviews/presentation/controllers/review_controller.dart';
import 'package:groclyra/shared/animations/spring_touch_scale.dart';
import 'package:groclyra/shared/widgets/app_toggle_message.dart';
import 'package:groclyra/shared/widgets/gradient_button.dart';

class ProductReviewsSection extends ConsumerWidget {
  final ProductEntity product;
  final String? selectedVariantName;

  const ProductReviewsSection({
    super.key,
    required this.product,
    this.selectedVariantName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeState = ref.watch(themeControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reviewState = ref.watch(reviewControllerProvider(product));
    final controller = ref.read(reviewControllerProvider(product).notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Ratings & Reviews',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => _openWriteReviewSheet(context, ref),
              icon: const Icon(Icons.rate_review_rounded, size: 16),
              label: const Text('Write a Review', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Overall Score & Star Breakdown Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF121722) : Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(
              color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Big Score
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    reviewState.averageRating.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: themeState.palette.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      final starVal = index + 1;
                      return Icon(
                        reviewState.averageRating >= starVal
                            ? Icons.star_rounded
                            : (reviewState.averageRating >= starVal - 0.5
                                ? Icons.star_half_rounded
                                : Icons.star_outline_rounded),
                        color: Colors.amber,
                        size: 16,
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${reviewState.totalCount} Verified Reviews',
                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              const SizedBox(
                height: 70,
                child: VerticalDivider(width: 1),
              ),
              const SizedBox(width: 12),

              // Right: 5 to 1 Star Progress Distribution
              Expanded(
                child: Column(
                  children: [5, 4, 3, 2, 1].map((star) {
                    final fraction = reviewState.starDistribution[star] ?? 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 10,
                            child: Text(
                              '$star',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: fraction,
                                minHeight: 5,
                                backgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  star >= 4 ? themeState.palette.primaryColor : Colors.amber.shade700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 24,
                            child: Text(
                              '${(fraction * 100).toInt()}%',
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip(
                context,
                label: 'All (${reviewState.totalCount})',
                isSelected: reviewState.activeFilter == 'all',
                onSelected: () => controller.setFilter('all'),
                primaryColor: themeState.palette.primaryColor,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context,
                label: '5 Stars ★',
                isSelected: reviewState.activeFilter == '5_star',
                onSelected: () => controller.setFilter('5_star'),
                primaryColor: themeState.palette.primaryColor,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context,
                label: '4 Stars ★',
                isSelected: reviewState.activeFilter == '4_star',
                onSelected: () => controller.setFilter('4_star'),
                primaryColor: themeState.palette.primaryColor,
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                context,
                label: '✓ Verified Purchases',
                isSelected: reviewState.activeFilter == 'verified',
                onSelected: () => controller.setFilter('verified'),
                primaryColor: themeState.palette.primaryColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Filtered Reviews List
        if (reviewState.filteredReviews.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121722) : Colors.white,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
              border: Border.all(color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Icon(Icons.reviews_outlined, size: 36, color: Colors.grey),
                const SizedBox(height: 8),
                const Text('No reviews found for this filter.', style: TextStyle(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () => controller.setFilter('all'),
                  child: const Text('Show All Reviews'),
                ),
              ],
            ),
          )
        else
          ...reviewState.filteredReviews.map((review) {
            return _ReviewCard(
              review: review,
              onToggleHelpful: () => controller.toggleHelpful(review.id),
              primaryColor: themeState.palette.primaryColor,
              isDark: isDark,
            );
          }),
      ],
    );
  }

  Widget _buildFilterChip(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
    required Color primaryColor,
  }) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : null,
        ),
      ),
      selected: isSelected,
      selectedColor: primaryColor,
      onSelected: (_) => onSelected(),
    );
  }

  void _openWriteReviewSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WriteReviewSheet(
        product: product,
        defaultVariant: selectedVariantName,
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ReviewEntity review;
  final VoidCallback onToggleHelpful;
  final Color primaryColor;
  final bool isDark;

  const _ReviewCard({
    required this.review,
    required this.onToggleHelpful,
    required this.primaryColor,
    required this.isDark,
  });

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()} mo ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = review.userName.trim().split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join().toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121722) : Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        border: Border.all(
          color: isDark ? const Color(0xFF262E3D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header Row
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: primaryColor.withValues(alpha: 0.15),
                child: Text(
                  initials.isNotEmpty ? initials : 'GB',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            review.userName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (review.isVerifiedPurchase) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, size: 10, color: Colors.green),
                                SizedBox(width: 2),
                                Text(
                                  'Verified Buyer',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${review.userCity} • ${_formatTimeAgo(review.createdAt)}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              // Stars
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (idx) {
                  return Icon(
                    idx < review.rating.round() ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: Colors.amber,
                    size: 14,
                  );
                }),
              ),
            ],
          ),

          if (review.variantName != null && review.variantName!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Option: ${review.variantName}',
                style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600),
              ),
            ),
          ],

          const SizedBox(height: 10),
          // Review Text
          Text(
            review.comment,
            style: const TextStyle(fontSize: 13, height: 1.45),
          ),
          const SizedBox(height: 10),

          // Helpful Upvote Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SpringTouchScale(
                onTap: onToggleHelpful,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: review.isHelpfulByUser
                        ? primaryColor.withValues(alpha: 0.15)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSmall),
                    border: Border.all(
                      color: review.isHelpfulByUser ? primaryColor : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        review.isHelpfulByUser ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                        size: 13,
                        color: review.isHelpfulByUser ? primaryColor : Colors.grey,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        review.helpfulCount > 0 ? 'Helpful (${review.helpfulCount})' : 'Helpful',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: review.isHelpfulByUser ? FontWeight.bold : FontWeight.w500,
                          color: review.isHelpfulByUser ? primaryColor : Colors.grey,
                        ),
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
}

class _WriteReviewSheet extends ConsumerStatefulWidget {
  final ProductEntity product;
  final String? defaultVariant;

  const _WriteReviewSheet({
    required this.product,
    this.defaultVariant,
  });

  @override
  ConsumerState<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<_WriteReviewSheet> {
  int _selectedRating = 5;
  late final TextEditingController _nameController;
  late final TextEditingController _cityController;
  late final TextEditingController _commentController;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _cityController = TextEditingController(
      text: user?.deliveryZone != null && user!.deliveryZone!.isNotEmpty
          ? user.deliveryZone!
          : (user?.deliveryAddress != null && user!.deliveryAddress!.isNotEmpty ? user.deliveryAddress! : 'Lahore, Punjab'),
    );
    _commentController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      AppToggleMessage.warning(
        context,
        'Please enter your honest feedback before submitting.',
        title: 'Review Required',
      );
      return;
    }

    ref.read(reviewControllerProvider(widget.product).notifier).submitReview(
          userName: _nameController.text,
          userCity: _cityController.text,
          rating: _selectedRating.toDouble(),
          comment: comment,
          variantName: widget.defaultVariant,
        );

    Navigator.of(context).pop();

    AppToggleMessage.success(
      context,
      'Your verified review for ${widget.product.title} has been published!',
      title: 'Review Published',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeState = ref.watch(themeControllerProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F141C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusLarge)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 24 + bottomInset,
      ),
      child: SingleChildScrollView(
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
            Text(
              'Rate & Review Product',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              widget.product.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 18),

            // Interactive Star Rating
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      final starNum = index + 1;
                      final isFilled = starNum <= _selectedRating;
                      return IconButton(
                        iconSize: 36,
                        icon: Icon(
                          isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: Colors.amber,
                        ),
                        onPressed: () => setState(() => _selectedRating = starNum),
                      );
                    }),
                  ),
                  Text(
                    _selectedRating == 5
                        ? '⭐⭐⭐⭐⭐ Outstanding (5/5)'
                        : (_selectedRating == 4
                            ? '⭐⭐⭐⭐ Very Good (4/5)'
                            : (_selectedRating == 3
                                ? '⭐⭐⭐ Average (3/5)'
                                : '⭐ Needs Improvement ($_selectedRating/5)')),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: themeState.palette.primaryColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Your Name',
                hintText: 'e.g. Ayesha Khan',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // City / Location
            TextField(
              controller: _cityController,
              decoration: InputDecoration(
                labelText: 'City / Area',
                hintText: 'e.g. Clifton, Karachi or DHA, Lahore',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),

            // Comment
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Share your genuine experience...',
                hintText: 'How was the quality, packaging, freshness, and delivery?',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 20),

            // Submit CTA
            GradientButton(
              text: 'Publish Authentic Review',
              icon: Icons.check_circle_rounded,
              onPressed: _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }
}