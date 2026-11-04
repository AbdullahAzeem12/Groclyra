enum MainCategoryType {
  crockery('Crockery', 'Plates, Dinner Sets, Glassware, Bowls & Mugs', '🍽️'),
  grocery('Grocery', 'Food Staples, Cooking Essentials, Snacks & Beverages', '🛒'),
  fastFood('Fast Food & Bakery', 'Restaurants, Bakeries, Cafes & Ready Meals', '🍔'),
  dairyBakery('Dairy & Bakery', 'Fresh Dairy, Milk Products, Artisan Breads & Pastries', '🥛');

  final String title;
  final String description;
  final String emoji;

  const MainCategoryType(this.title, this.description, this.emoji);
}

class CategoryEntity {
  final String id;
  final String name;
  final MainCategoryType parentType;
  final String iconEmoji;
  final String imageUrl;
  final int productCount;
  final List<String> subcategories;

  const CategoryEntity({
    required this.id,
    required this.name,
    required this.parentType,
    required this.iconEmoji,
    required this.imageUrl,
    required this.productCount,
    required this.subcategories,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'parentType': parentType.name,
        'iconEmoji': iconEmoji,
        'imageUrl': imageUrl,
        'productCount': productCount,
        'subcategories': subcategories,
      };

  factory CategoryEntity.fromJson(Map<String, dynamic> json) => CategoryEntity(
        id: json['id'],
        name: json['name'],
        parentType: MainCategoryType.values.firstWhere((e) => e.name == json['parentType']),
        iconEmoji: json['iconEmoji'],
        imageUrl: json['imageUrl'],
        productCount: json['productCount'],
        subcategories: List<String>.from(json['subcategories'] ?? []),
      );
}
