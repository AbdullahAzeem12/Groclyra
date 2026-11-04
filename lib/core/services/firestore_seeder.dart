import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:groclyra/features/catalog/data/mock_catalog_data.dart';

/// FirestoreSeeder — call once from a debug/admin screen or during onboarding
/// to populate Firestore with the initial catalog data.
///
/// Safe to call multiple times: uses `merge: true` so existing data is
/// preserved and only missing fields are added.
class FirestoreSeeder {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Seeds categories and products if they are not yet in Firestore.
  /// Strictly restricted to debug environments.
  static Future<void> seedIfEmpty() async {
    if (!kDebugMode) {
      debugPrint('FirestoreSeeder: demonstration seeding is disabled in non-debug mode.');
      return;
    }
    try {
      // Check if products already exist
      final snap = await _db.collection('products').limit(1).get();
      if (snap.docs.isNotEmpty) {
        debugPrint('FirestoreSeeder: catalog already seeded — skipping.');
        return;
      }

      debugPrint('FirestoreSeeder: starting catalog seed...');
      await seedCategories();
      await seedProducts();
      debugPrint('FirestoreSeeder: catalog seed complete!');
    } catch (e) {
      debugPrint('FirestoreSeeder.seedIfEmpty error: $e');
    }
  }

  /// Seeds categories collection from MockCatalogData.
  static Future<void> seedCategories() async {
    final categories = MockCatalogData.getCategories();
    final batch = _db.batch();
    int order = 0;
    for (final cat in categories) {
      final docRef = _db.collection('categories').doc(cat.id);
      batch.set(
        docRef,
        {
          'id': cat.id,
          'name': cat.name,
          'parentType': cat.parentType.name,
          'iconEmoji': cat.iconEmoji,
          'imageUrl': cat.imageUrl,
          'productCount': cat.productCount,
          'subcategories': cat.subcategories,
          'order': order++,
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    debugPrint('FirestoreSeeder: seeded ${categories.length} categories.');
  }

  /// Seeds products collection from MockCatalogData.
  static Future<void> seedProducts() async {
    final products = MockCatalogData.getProducts();
    // Firestore batch supports max 500 writes — chunk if needed
    const chunkSize = 100;
    for (var i = 0; i < products.length; i += chunkSize) {
      final chunk = products.sublist(
          i, i + chunkSize > products.length ? products.length : i + chunkSize);
      final batch = _db.batch();
      for (final product in chunk) {
        final docRef = _db.collection('products').doc(product.id);
        final data = product.toJson();
        data['createdAt'] = FieldValue.serverTimestamp();
        data['updatedAt'] = FieldValue.serverTimestamp();
        batch.set(docRef, data, SetOptions(merge: true));
      }
      await batch.commit();
    }
    debugPrint('FirestoreSeeder: seeded ${products.length} products.');
  }

  /// Seeds a seller profile document (call after seller registration).
  static Future<void> seedSellerProfile({
    required String sellerId,
    required String storeName,
    String? logoUrl,
    String? bannerUrl,
  }) async {
    await _db.collection('sellerProfiles').doc(sellerId).set({
      'storeName': storeName,
      'logoUrl': logoUrl,
      'bannerUrl': bannerUrl,
      'rating': 0.0,
      'totalProducts': 0,
      'totalOrders': 0,
      'todayRevenue': 0,
      'totalRevenue': 0,
      'pendingPayout': 0,
      'lowStockCount': 0,
      'isKycApproved': false,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    debugPrint('FirestoreSeeder: seller profile seeded for $sellerId');
  }

  /// Seeds a demo delivery task document (for testing rider portal).
  static Future<void> seedDemoDeliveryTask() async {
    const taskId = 'task_demo_001';
    final existing = await _db.collection('deliveryTasks').doc(taskId).get();
    if (existing.exists) return;

    await _db.collection('deliveryTasks').doc(taskId).set({
      'id': taskId,
      'subOrderId': 'sub_demo_001',
      'orderId': 'ord_demo_001',
      'orderNumber': 'GL-00001',
      'sellerStoreName': 'Demo Grocery Store',
      'sellerAddress': 'Shop 1, Main Market, Karachi',
      'sellerPhone': '+92 300 0000000',
      'customerName': 'Test Customer',
      'customerAddress': 'House 1, Street 1, Block A, Karachi',
      'customerPhone': '+92 300 1234567',
      'distanceKm': 3.5,
      'codAmount': 1500.0,
      'estimatedEarnings': 200.0,
      'status': 'available',
      'customerOtp': '1234',
      'assignedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    debugPrint('FirestoreSeeder: demo delivery task seeded.');
  }
}
