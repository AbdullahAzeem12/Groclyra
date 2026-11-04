import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/features/catalog/domain/entities/product_entity.dart';
import 'package:groclyra/features/customer/reviews/domain/entities/review_entity.dart';

class ReviewRepository {
  // In-memory cache for live real-time updates and customer submissions
  final Map<String, List<ReviewEntity>> _reviewsCache = {};

  List<ReviewEntity> getReviewsForProduct(ProductEntity product) {
    if (_reviewsCache.containsKey(product.id)) {
      return List.unmodifiable(_reviewsCache[product.id]!);
    }

    final initialReviews = _generateInitialReviews(product);
    _reviewsCache[product.id] = initialReviews;
    return List.unmodifiable(initialReviews);
  }

  void addReview(String productId, ReviewEntity review) {
    final list = _reviewsCache[productId] ?? [];
    _reviewsCache[productId] = [review, ...list];
  }

  void toggleHelpful(String productId, String reviewId) {
    final list = _reviewsCache[productId];
    if (list == null) return;

    final index = list.indexWhere((r) => r.id == reviewId);
    if (index != -1) {
      final current = list[index];
      final isNowHelpful = !current.isHelpfulByUser;
      final newCount = isNowHelpful ? (current.helpfulCount + 1) : (current.helpfulCount - 1).clamp(0, 9999);
      list[index] = current.copyWith(
        isHelpfulByUser: isNowHelpful,
        helpfulCount: newCount,
      );
      _reviewsCache[productId] = list;
    }
  }

  double calculateAverageRating(List<ReviewEntity> reviews, double fallback) {
    if (reviews.isEmpty) return fallback;
    final total = reviews.fold<double>(0.0, (sum, r) => sum + r.rating);
    return double.parse((total / reviews.length).toStringAsFixed(1));
  }

  Map<int, double> calculateStarDistribution(List<ReviewEntity> reviews) {
    final map = {5: 0.0, 4: 0.0, 3: 0.0, 2: 0.0, 1: 0.0};
    if (reviews.isEmpty) {
      map[5] = 0.85;
      map[4] = 0.12;
      map[3] = 0.03;
      return map;
    }

    final counts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in reviews) {
      final star = r.rating.round().clamp(1, 5);
      counts[star] = (counts[star] ?? 0) + 1;
    }

    final total = reviews.length;
    for (int star = 1; star <= 5; star++) {
      map[star] = (counts[star] ?? 0) / total;
    }
    return map;
  }

  List<ReviewEntity> _generateInitialReviews(ProductEntity product) {
    final now = DateTime.now();

    if (product.isCrockery) {
      return [
        ReviewEntity(
          id: 'rev_${product.id}_1',
          productId: product.id,
          userName: 'Ayesha Farooq',
          userCity: 'DHA Phase 5, Lahore',
          rating: 5.0,
          createdAt: now.subtract(const Duration(days: 2)),
          comment: 'SubhanAllah, the bone china quality is exceptionally fine and lightweight with a high translucent gloss. The bubble wrap packaging was triple-layered, zero breakage during transit!',
          variantName: product.variants.isNotEmpty ? product.variants.first.name : 'Complete Set',
          isVerifiedPurchase: true,
          helpfulCount: 24,
        ),
        ReviewEntity(
          id: 'rev_${product.id}_2',
          productId: product.id,
          userName: 'Dr. Tariq Mahmood',
          userCity: 'Clifton, Karachi',
          rating: 5.0,
          createdAt: now.subtract(const Duration(days: 5)),
          comment: 'Extremely elegant tableware! Microwave and dishwasher safe as described. Perfect for formal dawats and family dinners.',
          variantName: product.variants.length > 1 ? product.variants[1].name : null,
          isVerifiedPurchase: true,
          helpfulCount: 18,
        ),
        ReviewEntity(
          id: 'rev_${product.id}_3',
          productId: product.id,
          userName: 'Zainab Bilal',
          userCity: 'F-8/2, Islamabad',
          rating: 4.8,
          createdAt: now.subtract(const Duration(days: 11)),
          comment: 'Very premium finish. Looks even better in real life than in photos. Delivered right to my door in 24 hours.',
          variantName: product.variants.isNotEmpty ? product.variants.first.name : null,
          isVerifiedPurchase: true,
          helpfulCount: 12,
        ),
      ];
    } else if (product.isFastFood) {
      return [
        ReviewEntity(
          id: 'rev_${product.id}_1',
          productId: product.id,
          userName: 'Muhammad Hamza',
          userCity: 'Gulshan-e-Iqbal, Karachi',
          rating: 5.0,
          createdAt: now.subtract(const Duration(hours: 3)),
          comment: 'Delivered piping hot! The chicken broast crust was super crunchy and the signature garlic mayo was fresh and flavorful. 10/10 prep time!',
          variantName: product.variants.isNotEmpty ? product.variants.first.name : 'Regular',
          isVerifiedPurchase: true,
          helpfulCount: 31,
        ),
        ReviewEntity(
          id: 'rev_${product.id}_2',
          productId: product.id,
          userName: 'Sara Naveed',
          userCity: 'Johar Town, Lahore',
          rating: 5.0,
          createdAt: now.subtract(const Duration(days: 1)),
          comment: 'Very hygienic food grade packaging and generous portion size. One of the best fast food experiences on Groclyra.',
          variantName: product.variants.length > 1 ? product.variants[1].name : null,
          isVerifiedPurchase: true,
          helpfulCount: 15,
        ),
        ReviewEntity(
          id: 'rev_${product.id}_3',
          productId: product.id,
          userName: 'Usman Ali',
          userCity: 'Rawalpindi Cantt',
          rating: 4.5,
          createdAt: now.subtract(const Duration(days: 4)),
          comment: 'Great value meal deal. The fries were crispy and well seasoned. Will definitely reorder soon!',
          variantName: product.variants.isNotEmpty ? product.variants.first.name : null,
          isVerifiedPurchase: true,
          helpfulCount: 9,
        ),
      ];
    } else if (product.isDairyBakery) {
      return [
        ReviewEntity(
          id: 'rev_${product.id}_1',
          productId: product.id,
          userName: 'Fatima Zahra',
          userCity: 'Model Town, Lahore',
          rating: 5.0,
          createdAt: now.subtract(const Duration(hours: 5)),
          comment: 'Chilled delivery in temperature-controlled bag! Fresh shelf life and genuine taste. The texture is rich and pure.',
          variantName: product.packageSize ?? 'Standard Pack',
          isVerifiedPurchase: true,
          helpfulCount: 22,
        ),
        ReviewEntity(
          id: 'rev_${product.id}_2',
          productId: product.id,
          userName: 'Khurram Shehzad',
          userCity: 'Gulberg Greens, Islamabad',
          rating: 5.0,
          createdAt: now.subtract(const Duration(days: 2)),
          comment: 'Freshly baked and soft. Perfect for morning breakfast. 100% genuine sealed pack with verified expiry dates.',
          variantName: product.variants.isNotEmpty ? product.variants.first.name : null,
          isVerifiedPurchase: true,
          helpfulCount: 14,
        ),
        ReviewEntity(
          id: 'rev_${product.id}_3',
          productId: product.id,
          userName: 'Nida Arshad',
          userCity: 'North Nazimabad, Karachi',
          rating: 4.7,
          createdAt: now.subtract(const Duration(days: 6)),
          comment: 'Good natural flavor and no artificial smell. Trusted household staple delivered conveniently.',
          variantName: null,
          isVerifiedPurchase: true,
          helpfulCount: 8,
        ),
      ];
    } else {
      // Grocery & Staples
      return [
        ReviewEntity(
          id: 'rev_${product.id}_1',
          productId: product.id,
          userName: 'Rashid Minhas',
          userCity: 'Peoples Colony, Faisalabad',
          rating: 5.0,
          createdAt: now.subtract(const Duration(days: 1)),
          comment: '100% original brand packaging with verified QR and seal. Fresh crop grains and excellent aroma during cooking. Best price compared to local marts.',
          variantName: product.weightVolume ?? 'Standard Pack',
          isVerifiedPurchase: true,
          helpfulCount: 27,
        ),
        ReviewEntity(
          id: 'rev_${product.id}_2',
          productId: product.id,
          userName: 'Bushra Imran',
          userCity: 'Bahria Town, Rawalpindi',
          rating: 5.0,
          createdAt: now.subtract(const Duration(days: 3)),
          comment: 'Super fast same-day dispatch. Clean items with zero dust or broken pieces. Highly recommended verified vendor!',
          variantName: product.variants.isNotEmpty ? product.variants.first.name : null,
          isVerifiedPurchase: true,
          helpfulCount: 19,
        ),
        ReviewEntity(
          id: 'rev_${product.id}_3',
          productId: product.id,
          userName: 'Hassan Raza',
          userCity: 'Multan Cantt',
          rating: 4.8,
          createdAt: now.subtract(const Duration(days: 7)),
          comment: 'Authentic grocery product as listed. Well handled by the courier rider.',
          variantName: null,
          isVerifiedPurchase: true,
          helpfulCount: 11,
        ),
      ];
    }
  }
}

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository();
});

