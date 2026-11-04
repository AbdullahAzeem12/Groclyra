import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/seller_store_entity.dart';
import '../../../catalog/domain/entities/product_entity.dart';
import '../../../catalog/data/repositories/catalog_repository.dart';

/// Firestore-backed SellerRepository.
///
/// Reads the logged-in seller's store profile and products directly from
/// Firestore — no more hardcoded 'seller_01' identity. Write operations
/// also persist to Firestore immediately.
class SellerRepository {
  final FirebaseFirestore _firestore;
  final CatalogRepository _catalogRepository;

  SellerRepository({
    FirebaseFirestore? firestore,
    required CatalogRepository catalogRepository,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _catalogRepository = catalogRepository;

  // ──────────────────────────────────────────────────────────────
  // STORE PROFILE
  // ──────────────────────────────────────────────────────────────

  /// Fetches the seller's store profile by their Firebase UID (= sellerId).
  Future<SellerStoreEntity> getStoreProfile(String sellerId) async {
    try {
      // Check sellerProfiles collection (written at registration)
      final doc =
          await _firestore.collection('sellerProfiles').doc(sellerId).get();

      if (doc.exists && doc.data() != null) {
        return _storeFromDoc(sellerId, doc.data()!);
      }

      // Fallback: check users collection
      final userDoc =
          await _firestore.collection('users').doc(sellerId).get();
      if (userDoc.exists && userDoc.data() != null) {
        return _storeFromDoc(sellerId, userDoc.data()!);
      }

      // Last resort: empty placeholder so UI doesn't crash
      return SellerStoreEntity(
        id: sellerId,
        sellerId: sellerId,
        storeName: 'My Store',
        rating: 4.5,
        totalProducts: 0,
        totalOrders: 0,
        todayRevenue: 0,
        totalRevenue: 0,
        pendingPayout: 0,
        lowStockCount: 0,
        isKycApproved: false,
      );
    } catch (e) {
      debugPrint('SellerRepository.getStoreProfile error: $e');
      return SellerStoreEntity(
        id: sellerId,
        sellerId: sellerId,
        storeName: 'My Store',
        rating: 4.5,
        totalProducts: 0,
        totalOrders: 0,
        todayRevenue: 0,
        totalRevenue: 0,
        pendingPayout: 0,
        lowStockCount: 0,
        isKycApproved: false,
      );
    }
  }

  /// Real-time stream of the seller's store profile.
  Stream<SellerStoreEntity?> streamStoreProfile(String sellerId) {
    return _firestore
        .collection('sellerProfiles')
        .doc(sellerId)
        .snapshots()
        .asyncMap((doc) async {
      final mergedData = <String, dynamic>{};

      // Merge primary user document (registration details)
      try {
        final userDoc = await _firestore.collection('users').doc(sellerId).get();
        if (userDoc.exists && userDoc.data() != null) {
          mergedData.addAll(userDoc.data()!);
        }
      } catch (_) {}

      // Merge seller profile document
      if (doc.exists && doc.data() != null) {
        mergedData.addAll(doc.data()!);
      }

      if (mergedData.isEmpty) return null;
      return _storeFromDoc(sellerId, mergedData);
    }).handleError((e) {
      debugPrint('SellerRepository.streamStoreProfile error: $e');
      return null;
    });
  }

  // ──────────────────────────────────────────────────────────────
  // SELLER ORDERS — aggregate stats
  // ──────────────────────────────────────────────────────────────

  /// Stream of seller order stats (revenue, order count) derived from Firestore.
  ///
  /// FIX: previously this queried `where('subOrders', arrayContains:
  /// {'sellerId': sellerId})` — Firestore array-contains matches *whole array
  /// elements*, so a partial map fragment never matched real orders and the
  /// stats always silently returned zeros. Orders already carry a denormalised
  /// `sellerIds` array (written by OrderRepository.createOrder), which is what
  /// the seller orders stream uses, so the same field drives stats.
  Stream<Map<String, dynamic>> streamSellerStats(String sellerId) {
    return _firestore
        .collection('orders')
        .where('sellerIds', arrayContains: sellerId)
        .snapshots()
        .map((snap) {
          double todayRevenue = 0;
          double totalRevenue = 0;
          int totalOrders = snap.docs.length;
          final today = DateTime.now();

          for (final doc in snap.docs) {
            final data = doc.data();
            final subOrders =
                List<Map<String, dynamic>>.from(data['subOrders'] as List? ?? []);
            for (final sub in subOrders) {
              if (sub['sellerId'] == sellerId) {
                final amount = (sub['subtotal'] as num?)?.toDouble() ?? 0;
                totalRevenue += amount;
                final createdAt = data['createdAt'];
                if (createdAt is Timestamp) {
                  final dt = createdAt.toDate();
                  if (dt.year == today.year &&
                      dt.month == today.month &&
                      dt.day == today.day) {
                    todayRevenue += amount;
                  }
                }
              }
            }
          }
          return {
            'totalOrders': totalOrders,
            'totalRevenue': totalRevenue,
            'todayRevenue': todayRevenue,
          };
        }).handleError((e) {
          debugPrint('SellerRepository.streamSellerStats error: $e');
          return <String, dynamic>{};
        });
  }

  // ──────────────────────────────────────────────────────────────
  // PRODUCTS
  // ──────────────────────────────────────────────────────────────

  /// One-shot fetch of all products belonging to this seller.
  Future<List<ProductEntity>> getSellerProducts(String sellerId) async {
    return _catalogRepository.getProducts(sellerId: sellerId);
  }

  /// Real-time stream of this seller's products.
  Stream<List<ProductEntity>> streamSellerProducts(String sellerId) {
    return _catalogRepository.streamProducts(sellerId: sellerId);
  }

  /// Writes a new product to Firestore.
  Future<void> addNewProduct(ProductEntity product) async {
    await _catalogRepository.addProduct(product);
    // Increment sellerProfiles.totalProducts counter
    await _firestore
        .collection('sellerProfiles')
        .doc(product.sellerId)
        .set({'totalProducts': FieldValue.increment(1)}, SetOptions(merge: true));
  }

  /// Updates inventory stock for a specific variant.
  Future<void> updateInventory(
      String productId, String variantId, int newStock) async {
    await _catalogRepository.updateProductStock(productId, variantId, newStock);
  }

  /// Updates arbitrary product fields (e.g. price, description, approval).
  Future<void> updateProduct(
      String productId, Map<String, dynamic> updates) async {
    await _catalogRepository.updateProduct(productId, updates);
  }

  // ──────────────────────────────────────────────────────────────
  // SELLER PROFILE UPDATE
  // ──────────────────────────────────────────────────────────────

  /// Updates seller store profile fields in Firestore.
  Future<void> updateStoreProfile(
      String sellerId, Map<String, dynamic> updates) async {
    if (sellerId.isEmpty) {
      throw ArgumentError('Seller ID cannot be empty.');
    }
    updates['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore
        .collection('sellerProfiles')
        .doc(sellerId)
        .set(updates, SetOptions(merge: true));

    // Sync to the primary users collection as well
    final userUpdates = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (updates.containsKey('storeName')) {
      userUpdates['storeName'] = updates['storeName'];
    }
    if (updates.containsKey('ownerName') || updates.containsKey('displayName')) {
      final nameVal = updates['ownerName'] ?? updates['displayName'];
      userUpdates['name'] = nameVal;
      userUpdates['displayName'] = nameVal;
    }
    if (updates.containsKey('phone')) {
      userUpdates['phone'] = updates['phone'];
    }
    if (updates.containsKey('email')) {
      userUpdates['email'] = updates['email'];
    }
    if (updates.containsKey('businessCategory')) {
      userUpdates['businessCategory'] = updates['businessCategory'];
    }
    if (updates.containsKey('logoUrl')) {
      userUpdates['logoUrl'] = updates['logoUrl'];
      userUpdates['avatarUrl'] = updates['logoUrl'];
      userUpdates['profileImageBase64'] = updates['logoUrl'];
    }

    try {
      await _firestore
          .collection('users')
          .doc(sellerId)
          .set(userUpdates, SetOptions(merge: true));
    } catch (e) {
      debugPrint('SellerRepository.updateStoreProfile user sync warning: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────
  // PARSING HELPERS
  // ──────────────────────────────────────────────────────────────

  SellerStoreEntity _storeFromDoc(String sellerId, Map<String, dynamic> data) {
    return SellerStoreEntity(
      id: sellerId,
      sellerId: sellerId,
      storeName: data['storeName'] as String? ??
          data['displayName'] as String? ??
          'My Store',
      ownerName: data['displayName'] as String? ??
          data['name'] as String? ??
          data['ownerName'] as String?,
      email: data['email'] as String?,
      phone: data['phone'] as String? ?? data['contactPhone'] as String?,
      businessCategory:
          data['businessCategory'] as String? ?? data['category'] as String?,
      storeDescription:
          data['storeDescription'] as String? ?? data['description'] as String?,
      storeAddress:
          data['storeAddress'] as String? ?? data['address'] as String?,
      logoUrl: data['logoUrl'] as String? ??
          data['avatarUrl'] as String? ??
          data['profileImageBase64'] as String?,
      bannerUrl: data['bannerUrl'] as String?,
      rating: (data['rating'] as num?)?.toDouble() ?? 4.5,
      totalProducts: (data['totalProducts'] as num?)?.toInt() ?? 0,
      totalOrders: (data['totalOrders'] as num?)?.toInt() ?? 0,
      todayRevenue: (data['todayRevenue'] as num?)?.toDouble() ?? 0,
      totalRevenue: (data['totalRevenue'] as num?)?.toDouble() ?? 0,
      pendingPayout: (data['pendingPayout'] as num?)?.toDouble() ?? 0,
      lowStockCount: (data['lowStockCount'] as num?)?.toInt() ?? 0,
      isKycApproved:
          data['isKycApproved'] as bool? ?? (data['accountStatus'] == 'active'),
      accountStatus: data['accountStatus'] as String? ?? 'active',
    );
  }
}

// ──────────────────────────────────────────────────────────────
// PROVIDERS
// ──────────────────────────────────────────────────────────────

final sellerRepositoryProvider = Provider<SellerRepository>((ref) {
  final catalogRepo = ref.watch(catalogRepositoryProvider);
  return SellerRepository(catalogRepository: catalogRepo);
});

/// Stream of a seller's store profile by their UID.
final sellerStoreProfileStreamProvider =
    StreamProvider.autoDispose.family<SellerStoreEntity?, String>(
        (ref, sellerId) {
  return ref.watch(sellerRepositoryProvider).streamStoreProfile(sellerId);
});
