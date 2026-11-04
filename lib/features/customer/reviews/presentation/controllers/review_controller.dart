import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:groclyra/features/catalog/domain/entities/product_entity.dart';
import 'package:groclyra/features/customer/reviews/data/repositories/review_repository.dart';
import 'package:groclyra/features/customer/reviews/domain/entities/review_entity.dart';

class ReviewState {
  final List<ReviewEntity> allReviews;
  final double averageRating;
  final Map<int, double> starDistribution;
  final String activeFilter; // 'all', '5_star', '4_star', 'verified'

  const ReviewState({
    required this.allReviews,
    required this.averageRating,
    required this.starDistribution,
    this.activeFilter = 'all',
  });

  int get totalCount => allReviews.length;

  List<ReviewEntity> get filteredReviews {
    switch (activeFilter) {
      case '5_star':
        return allReviews.where((r) => r.rating >= 4.8).toList();
      case '4_star':
        return allReviews.where((r) => r.rating >= 3.8 && r.rating < 4.8).toList();
      case 'verified':
        return allReviews.where((r) => r.isVerifiedPurchase).toList();
      case 'all':
      default:
        return allReviews;
    }
  }

  ReviewState copyWith({
    List<ReviewEntity>? allReviews,
    double? averageRating,
    Map<int, double>? starDistribution,
    String? activeFilter,
  }) {
    return ReviewState(
      allReviews: allReviews ?? this.allReviews,
      averageRating: averageRating ?? this.averageRating,
      starDistribution: starDistribution ?? this.starDistribution,
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }
}

class ReviewController extends StateNotifier<ReviewState> {
  final ReviewRepository _repo;
  final ProductEntity _product;

  ReviewController({
    required ReviewRepository repo,
    required ProductEntity product,
  })  : _repo = repo,
        _product = product,
        super(_initialState(repo, product));

  static ReviewState _initialState(ReviewRepository repo, ProductEntity product) {
    final list = repo.getReviewsForProduct(product);
    final avg = repo.calculateAverageRating(list, product.rating);
    final dist = repo.calculateStarDistribution(list);
    return ReviewState(
      allReviews: list,
      averageRating: avg,
      starDistribution: dist,
      activeFilter: 'all',
    );
  }

  void setFilter(String filter) {
    state = state.copyWith(activeFilter: filter);
  }

  void toggleHelpful(String reviewId) {
    _repo.toggleHelpful(_product.id, reviewId);
    final updatedList = _repo.getReviewsForProduct(_product);
    state = state.copyWith(allReviews: updatedList);
  }

  void submitReview({
    required String userName,
    required String userCity,
    required double rating,
    required String comment,
    String? variantName,
  }) {
    final newReview = ReviewEntity(
      id: 'rev_live_${DateTime.now().millisecondsSinceEpoch}',
      productId: _product.id,
      userName: userName.trim().isEmpty ? 'Groclyra Customer' : userName.trim(),
      userCity: userCity.trim().isEmpty ? 'Pakistan' : userCity.trim(),
      rating: rating.clamp(1.0, 5.0),
      createdAt: DateTime.now(),
      comment: comment.trim(),
      variantName: variantName,
      isVerifiedPurchase: true,
      helpfulCount: 0,
      isHelpfulByUser: false,
    );

    _repo.addReview(_product.id, newReview);
    final updatedList = _repo.getReviewsForProduct(_product);
    final avg = _repo.calculateAverageRating(updatedList, _product.rating);
    final dist = _repo.calculateStarDistribution(updatedList);

    state = state.copyWith(
      allReviews: updatedList,
      averageRating: avg,
      starDistribution: dist,
    );
  }
}

final reviewControllerProvider = StateNotifierProvider.family<ReviewController, ReviewState, ProductEntity>((ref, product) {
  final repo = ref.watch(reviewRepositoryProvider);
  return ReviewController(repo: repo, product: product);
});

