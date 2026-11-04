class AppConfig {
  static const String appName = 'Groclyra';
  static const String appTagline = 'Fresh Groceries. Beautiful Living.';
  static const String appVersion = '1.0.0';
  static const String baseUrl = 'https://api.groclyra.com/v1';
  static const String cdnBaseUrl = 'https://cdn.groclyra.com';
  
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
  
  // Scoped Categories
  static const String categoryCrockery = 'Crockery';
  static const String categoryGrocery = 'Grocery';
}
