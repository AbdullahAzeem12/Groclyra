class ReviewEntity {
  final String id;
  final String productId;
  final String userName;
  final String? userAvatarUrl;
  final String userCity;
  final double rating;
  final DateTime createdAt;
  final String comment;
  final String? variantName;
  final bool isVerifiedPurchase;
  final int helpfulCount;
  final bool isHelpfulByUser;

  const ReviewEntity({
    required this.id,
    required this.productId,
    required this.userName,
    this.userAvatarUrl,
    required this.userCity,
    required this.rating,
    required this.createdAt,
    required this.comment,
    this.variantName,
    this.isVerifiedPurchase = true,
    this.helpfulCount = 0,
    this.isHelpfulByUser = false,
  });

  ReviewEntity copyWith({
    String? id,
    String? productId,
    String? userName,
    String? userAvatarUrl,
    String? userCity,
    double? rating,
    DateTime? createdAt,
    String? comment,
    String? variantName,
    bool? isVerifiedPurchase,
    int? helpfulCount,
    bool? isHelpfulByUser,
  }) {
    return ReviewEntity(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      userName: userName ?? this.userName,
      userAvatarUrl: userAvatarUrl ?? this.userAvatarUrl,
      userCity: userCity ?? this.userCity,
      rating: rating ?? this.rating,
      createdAt: createdAt ?? this.createdAt,
      comment: comment ?? this.comment,
      variantName: variantName ?? this.variantName,
      isVerifiedPurchase: isVerifiedPurchase ?? this.isVerifiedPurchase,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      isHelpfulByUser: isHelpfulByUser ?? this.isHelpfulByUser,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'userName': userName,
      'userAvatarUrl': userAvatarUrl,
      'userCity': userCity,
      'rating': rating,
      'createdAt': createdAt.toIso8601String(),
      'comment': comment,
      'variantName': variantName,
      'isVerifiedPurchase': isVerifiedPurchase,
      'helpfulCount': helpfulCount,
      'isHelpfulByUser': isHelpfulByUser,
    };
  }

  factory ReviewEntity.fromMap(Map<String, dynamic> map) {
    return ReviewEntity(
      id: map['id']?.toString() ?? '',
      productId: map['productId']?.toString() ?? '',
      userName: map['userName']?.toString() ?? 'Verified Buyer',
      userAvatarUrl: map['userAvatarUrl']?.toString(),
      userCity: map['userCity']?.toString() ?? 'Pakistan',
      rating: (map['rating'] as num?)?.toDouble() ?? 5.0,
      createdAt: DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now(),
      comment: map['comment']?.toString() ?? '',
      variantName: map['variantName']?.toString(),
      isVerifiedPurchase: map['isVerifiedPurchase'] as bool? ?? true,
      helpfulCount: (map['helpfulCount'] as num?)?.toInt() ?? 0,
      isHelpfulByUser: map['isHelpfulByUser'] as bool? ?? false,
    );
  }
}

