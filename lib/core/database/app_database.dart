import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sql;
import '../../features/catalog/data/pakistan_catalog_dataset.dart';
import 'realtime/sql_realtime_stream.dart';
import 'daos/catalog_dao.dart';
import 'daos/order_dao.dart';
import 'daos/address_dao.dart';
import 'daos/user_dao.dart';
import 'daos/delivery_dao.dart';
import 'daos/review_dao.dart';
import 'daos/wishlist_dao.dart';
import 'daos/telemetry_dao.dart';
import 'daos/coupon_dao.dart';
import 'daos/home_banner_dao.dart';
import 'migrations/migration_manager.dart';

/// Centralized, enterprise-grade SQLite Database engine for Groclyra.
///
/// Features:
/// - True local SQL ACID storage (Zero Cloud Firestore requirement)
/// - Reactive table change notification bus (enables real-time SQL streams)
/// - Dedicated Data Access Objects (DAOs) for all 4 portals
/// - Automatic multi-portal data seeding on fresh installation
/// - Resilient memory-cache fallback for headless unit/widget tests
class AppDatabase {
  static AppDatabase? _instance;
  static AppDatabase get instance => _instance ??= AppDatabase._();

  AppDatabase._();

  sql.Database? _db;
  bool _isInitializing = false;
  bool _isTestMode = false;

  /// Holds the current active authenticated user ID across all app portals and services.
  String? activeSessionUserId;

  // Dedicated SQL Data Access Objects (DAOs)
  late final CatalogDao catalogDao = CatalogDao(() async {
    await init();
    return _db;
  }, SqlRealtimeStreamManager.instance);

  late final OrderDao orderDao = OrderDao(() async {
    await init();
    return _db;
  }, SqlRealtimeStreamManager.instance);

  late final AddressDao addressDao = AddressDao(() async {
    await init();
    return _db;
  }, SqlRealtimeStreamManager.instance);

  late final UserDao userDao = UserDao(() async {
    await init();
    return _db;
  }, SqlRealtimeStreamManager.instance);

  late final DeliveryDao deliveryDao = DeliveryDao(() async {
    await init();
    return _db;
  }, SqlRealtimeStreamManager.instance);

  late final ReviewDao reviewDao = ReviewDao(() async {
    await init();
    return _db;
  }, SqlRealtimeStreamManager.instance);

  late final WishlistDao wishlistDao = WishlistDao(() async {
    await init();
    return _db;
  }, SqlRealtimeStreamManager.instance);

  late final TelemetryDao telemetryDao = TelemetryDao(() async {
    await init();
    return _db;
  }, SqlRealtimeStreamManager.instance);

  late final CouponDao couponDao = CouponDao(() async {
    await init();
    return _db;
  }, SqlRealtimeStreamManager.instance);

  late final HomeBannerDao homeBannerDao = HomeBannerDao(() async {
    await init();
    return _db;
  }, SqlRealtimeStreamManager.instance);

  sql.Database? get database => _db;

  // In-memory fallback tables for tests or platforms without native SQLite bindings
  final Map<String, List<Map<String, dynamic>>> _memoryTables = {};

  // Broadcast controllers for real-time table streams
  final Map<String, StreamController<String>> _tableChangeControllers = {};

  StreamController<String> _getController(String table) {
    return _tableChangeControllers.putIfAbsent(
      table,
      () => StreamController<String>.broadcast(),
    );
  }

  /// Notifies all active subscribers that a table's data has mutated
  void notifyTable(String table) {
    if (_tableChangeControllers.containsKey(table)) {
      _tableChangeControllers[table]!.add(table);
    }
    SqlRealtimeStreamManager.instance.notifyTable(table);
  }

  /// Returns a real-time stream that emits every time [table] is written to
  Stream<String> watchTable(String table) {
    return _getController(table).stream;
  }

  /// Initializes the SQLite database or sets up memory fallback if running tests
  Future<void> init() async {
    if (_db != null || _isTestMode) return;
    if (_isInitializing) {
      while (_isInitializing) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return;
    }

    _isInitializing = true;
    try {
      if (kIsWeb || (Platform.environment.containsKey('FLUTTER_TEST'))) {
        _isTestMode = true;
        _seedMemoryTables();
        _isInitializing = false;
        return;
      }

      final dbPath = await sql.getDatabasesPath();
      final fullPath = p.join(dbPath, 'groclyra.db');

      _db = await sql.openDatabase(
        fullPath,
        version: 1,
        onCreate: (db, version) async {
          await _createTables(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await MigrationManager.instance.onUpgrade(db, oldVersion, newVersion);
        },
      );

      // Ensure oauthProvider column exists
      try {
        await _db?.execute("ALTER TABLE users ADD COLUMN oauthProvider TEXT");
      } catch (_) {}

      // Ensure enterprise security tables exist
      try {
        await _db?.execute('''
          CREATE TABLE IF NOT EXISTS user_2fa (
            userId TEXT PRIMARY KEY,
            secretKey TEXT NOT NULL,
            isEnabled INTEGER DEFAULT 0,
            backupCodesJson TEXT,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');
        await _db?.execute('''
          CREATE TABLE IF NOT EXISTS user_sessions (
            id TEXT PRIMARY KEY,
            userId TEXT NOT NULL,
            deviceId TEXT NOT NULL,
            deviceName TEXT NOT NULL,
            platform TEXT NOT NULL,
            ipAddress TEXT,
            lastActiveAt TEXT NOT NULL,
            isCurrent INTEGER DEFAULT 0,
            createdAt TEXT NOT NULL
          )
        ''');
        await _db?.execute('CREATE INDEX IF NOT EXISTS idx_user_sessions_user ON user_sessions(userId);');
        await _db?.execute('CREATE INDEX IF NOT EXISTS idx_user_sessions_device ON user_sessions(deviceId);');
        await _db?.execute('''
          CREATE TABLE IF NOT EXISTS database_backups (
            id TEXT PRIMARY KEY,
            fileName TEXT NOT NULL,
            filePath TEXT NOT NULL,
            fileSizeBytes INTEGER NOT NULL,
            checksum TEXT NOT NULL,
            isEncrypted INTEGER DEFAULT 1,
            createdAt TEXT NOT NULL
          )
        ''');
      } catch (_) {}

      // Purge any legacy fake/static demo accounts
      try {
        await _db?.delete('users', where: "id LIKE 'usr_%_demo'");
        await _db?.delete('seller_profiles', where: "sellerId LIKE 'usr_%_demo'");
        await _db?.delete('rider_profiles', where: "riderId LIKE 'usr_%_demo'");
      } catch (_) {}

      // Seed if fresh
      await _seedSqliteDatabaseIfEmpty();
    } catch (e) {
      debugPrint(
        'AppDatabase initialization note: $e. Operating in resilient memory mode.',
      );
      _isTestMode = true;
      _seedMemoryTables();
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _createTables(sql.Database db) async {
    // 1. Users
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        phone TEXT,
        role TEXT NOT NULL,
        accountStatus TEXT NOT NULL,
        photoUrl TEXT,
        vehicleNumber TEXT,
        licenseNumber TEXT,
        fcmToken TEXT,
        passwordHash TEXT,
        oauthProvider TEXT,
        isOnline INTEGER DEFAULT 0,
        deliveryAddress TEXT,
        deliveryZone TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT
      )
    ''');

    // 2. Categories
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        parentType TEXT NOT NULL,
        iconEmoji TEXT NOT NULL,
        imageUrl TEXT NOT NULL,
        productCount INTEGER DEFAULT 0,
        subcategoriesJson TEXT,
        sortOrder INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    // 3. Products
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT NOT NULL,
        basePrice REAL NOT NULL,
        salePrice REAL NOT NULL,
        discountPercentage REAL DEFAULT 0,
        categoryId TEXT NOT NULL,
        subcategory TEXT NOT NULL,
        parentCategory TEXT NOT NULL,
        imageUrl TEXT NOT NULL,
        secondaryImagesJson TEXT,
        rating REAL DEFAULT 4.5,
        reviewCount INTEGER DEFAULT 0,
        isAvailable INTEGER DEFAULT 1,
        isFlashDeal INTEGER DEFAULT 0,
        stockQuantity INTEGER DEFAULT 100,
        brand TEXT NOT NULL,
        vendorId TEXT,
        vendorStoreName TEXT,
        fullDataJson TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT
      )
    ''');

    // 4. Reviews
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reviews (
        id TEXT PRIMARY KEY,
        productId TEXT NOT NULL,
        userId TEXT NOT NULL,
        userName TEXT NOT NULL,
        userAvatar TEXT,
        rating REAL NOT NULL,
        comment TEXT NOT NULL,
        verified INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL
      )
    ''');

    // 5. Addresses
    await db.execute('''
      CREATE TABLE IF NOT EXISTS addresses (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        label TEXT NOT NULL,
        recipientName TEXT NOT NULL,
        phone TEXT NOT NULL,
        street TEXT NOT NULL,
        area TEXT NOT NULL,
        city TEXT NOT NULL,
        province TEXT NOT NULL,
        postalCode TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        isDefault INTEGER DEFAULT 0,
        serviceabilityStatus TEXT NOT NULL,
        fullDataJson TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // 6. Orders
    await db.execute('''
      CREATE TABLE IF NOT EXISTS orders (
        id TEXT PRIMARY KEY,
        orderNumber TEXT NOT NULL UNIQUE,
        customerId TEXT NOT NULL,
        customerName TEXT NOT NULL,
        customerPhone TEXT NOT NULL,
        deliveryAddressJson TEXT NOT NULL,
        status TEXT NOT NULL,
        subtotal REAL NOT NULL,
        shippingFee REAL NOT NULL,
        discount REAL NOT NULL,
        totalAmount REAL NOT NULL,
        paymentMethod TEXT NOT NULL,
        paymentStatus TEXT NOT NULL,
        sellerIdsJson TEXT NOT NULL,
        riderId TEXT,
        riderName TEXT,
        notes TEXT,
        trackingNumber TEXT,
        fullDataJson TEXT,
        placedAt TEXT NOT NULL,
        deliveredAt TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT
      )
    ''');

    // 7. Order Items
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_items (
        id TEXT PRIMARY KEY,
        orderId TEXT NOT NULL,
        productId TEXT NOT NULL,
        title TEXT NOT NULL,
        price REAL NOT NULL,
        quantity INTEGER NOT NULL,
        imageUrl TEXT NOT NULL,
        variant TEXT,
        vendorId TEXT,
        vendorStoreName TEXT
      )
    ''');

    // 8. Wishlist
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wishlist (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        productId TEXT NOT NULL,
        title TEXT NOT NULL,
        categoryType TEXT NOT NULL,
        categoryName TEXT NOT NULL,
        brand TEXT NOT NULL,
        imageUrl TEXT NOT NULL,
        savedPrice REAL NOT NULL,
        currentPrice REAL NOT NULL,
        compareAtPrice REAL,
        inStock INTEGER DEFAULT 1,
        stockCount INTEGER DEFAULT 10,
        selectedVariantName TEXT,
        collectionName TEXT,
        fullDataJson TEXT,
        savedAt TEXT NOT NULL
      )
    ''');

    // 9. Seller Profiles
    await db.execute('''
      CREATE TABLE IF NOT EXISTS seller_profiles (
        sellerId TEXT PRIMARY KEY,
        storeName TEXT NOT NULL,
        logoUrl TEXT,
        bannerUrl TEXT,
        rating REAL DEFAULT 4.5,
        totalProducts INTEGER DEFAULT 0,
        totalOrders INTEGER DEFAULT 0,
        todayRevenue REAL DEFAULT 0,
        totalRevenue REAL DEFAULT 0,
        pendingPayout REAL DEFAULT 0,
        lowStockCount INTEGER DEFAULT 0,
        isKycApproved INTEGER DEFAULT 0,
        phone TEXT,
        address TEXT,
        categoryFocus TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // 10. Delivery Tasks
    await db.execute('''
      CREATE TABLE IF NOT EXISTS delivery_tasks (
        id TEXT PRIMARY KEY,
        subOrderId TEXT NOT NULL,
        orderId TEXT NOT NULL,
        orderNumber TEXT NOT NULL,
        sellerStoreName TEXT NOT NULL,
        sellerAddress TEXT NOT NULL,
        sellerPhone TEXT NOT NULL,
        pickupLat REAL,
        pickupLng REAL,
        customerName TEXT NOT NULL,
        customerAddress TEXT NOT NULL,
        customerPhone TEXT NOT NULL,
        dropLat REAL,
        dropLng REAL,
        riderLat REAL,
        riderLng REAL,
        distanceKm REAL DEFAULT 3.0,
        codAmount REAL DEFAULT 0,
        estimatedEarnings REAL DEFAULT 150,
        status TEXT NOT NULL,
        customerOtp TEXT NOT NULL,
        riderId TEXT,
        assignedAt TEXT,
        completedAt TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT
      )
    ''');

    // 11. Rider Profiles
    await db.execute('''
      CREATE TABLE IF NOT EXISTS rider_profiles (
        riderId TEXT PRIMARY KEY,
        fullName TEXT NOT NULL,
        cnic TEXT,
        phone TEXT,
        vehicleType TEXT,
        vehicleNumber TEXT,
        licenseNumber TEXT,
        kycStatus TEXT DEFAULT 'active',
        isAvailable INTEGER DEFAULT 1,
        totalDeliveries INTEGER DEFAULT 0,
        rating REAL DEFAULT 5.0,
        totalCodCollected REAL DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    // 12. Vendor Integrations
    await db.execute('''
      CREATE TABLE IF NOT EXISTS vendor_integrations (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        storeName TEXT NOT NULL,
        logoUrl TEXT NOT NULL,
        bannerUrl TEXT,
        rating REAL DEFAULT 4.8,
        verified INTEGER DEFAULT 1,
        isOpen INTEGER DEFAULT 1,
        city TEXT NOT NULL,
        address TEXT NOT NULL,
        totalProducts INTEGER DEFAULT 100,
        liveSync INTEGER DEFAULT 1,
        catalogType TEXT DEFAULT 'grocery',
        contactNumber TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // 13. Notifications
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notifications (
        id TEXT PRIMARY KEY,
        recipientId TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        type TEXT NOT NULL,
        isRead INTEGER DEFAULT 0,
        dataJson TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    // 14. Support Messages
    await db.execute('''
      CREATE TABLE IF NOT EXISTS support_messages (
        id TEXT PRIMARY KEY,
        threadId TEXT NOT NULL,
        senderType TEXT NOT NULL,
        text TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');

    // 15. Notification Preferences
    await db.execute('''
      CREATE TABLE IF NOT EXISTS notification_preferences (
        userId TEXT PRIMARY KEY,
        orderUpdates INTEGER DEFAULT 1,
        promotionalOffers INTEGER DEFAULT 1,
        deliveryAlerts INTEGER DEFAULT 1,
        emailNotifications INTEGER DEFAULT 0,
        smsNotifications INTEGER DEFAULT 1
      )
    ''');

    // 16. Telemetry & Settings
    await db.execute('''
      CREATE TABLE IF NOT EXISTS system_telemetry (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // 17. Coupons & Promo Codes
    await db.execute('''
      CREATE TABLE IF NOT EXISTS coupons (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        discountPercentage INTEGER NOT NULL,
        maxDiscount REAL,
        minOrderAmount REAL DEFAULT 0.0,
        validUntil TEXT NOT NULL,
        isActive INTEGER DEFAULT 1,
        usageCount INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    // 18. Schema Migrations Audit Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        appliedAt TEXT NOT NULL
      )
    ''');

    // 19. App Preferences (Replaces SharedPreferences with Reactive SQL)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_preferences (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'string',
        updatedAt TEXT NOT NULL
      )
    ''');

    // 20. App Secure Vault (Replaces FlutterSecureStorage with SQL Storage)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_secure_vault (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // 21. Shopping Cart SQL Cache (Replaces JSON Cart Storage)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cart_cache (
        userId TEXT NOT NULL,
        productId TEXT NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        variantName TEXT,
        unitPrice REAL NOT NULL,
        fullDataJson TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        PRIMARY KEY (userId, productId)
      )
    ''');

    // 22. App Rate Limits (Replaces XML SharedPreferences Rate Limits)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_rate_limits (
        key TEXT PRIMARY KEY,
        hitCount INTEGER DEFAULT 0,
        lastAttemptEpoch INTEGER DEFAULT 0,
        lockoutUntilEpoch INTEGER DEFAULT 0,
        updatedAt TEXT NOT NULL
      )
    ''');

    // 23. Offline Mutations Queue
    await db.execute('''
      CREATE TABLE IF NOT EXISTS offline_mutations (
        id TEXT PRIMARY KEY,
        mutationType TEXT NOT NULL,
        payloadJson TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        createdAt TEXT NOT NULL
      )
    ''');

    // 24. Home Promotional Banners (Marketing CMS)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS home_banners (
        id TEXT PRIMARY KEY,
        tag TEXT NOT NULL,
        title TEXT NOT NULL,
        subtitle TEXT NOT NULL,
        badgeText TEXT NOT NULL,
        floatingEmojis TEXT NOT NULL,
        gradientColorsJson TEXT NOT NULL,
        targetPillar TEXT,
        ctaText TEXT NOT NULL,
        isActive INTEGER DEFAULT 1,
        displayOrder INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    // 25. Two-Factor Authentication (RFC 6238 TOTP)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_2fa (
        userId TEXT PRIMARY KEY,
        secretKey TEXT NOT NULL,
        isEnabled INTEGER DEFAULT 0,
        backupCodesJson TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    // 26. Active User Sessions & Device Management
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_sessions (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        deviceId TEXT NOT NULL,
        deviceName TEXT NOT NULL,
        platform TEXT NOT NULL,
        ipAddress TEXT,
        lastActiveAt TEXT NOT NULL,
        isCurrent INTEGER DEFAULT 0,
        createdAt TEXT NOT NULL
      )
    ''');

    // 27. Database Backups & Recovery Registry
    await db.execute('''
      CREATE TABLE IF NOT EXISTS database_backups (
        id TEXT PRIMARY KEY,
        fileName TEXT NOT NULL,
        filePath TEXT NOT NULL,
        fileSizeBytes INTEGER NOT NULL,
        checksum TEXT NOT NULL,
        isEncrypted INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL
      )
    ''');

    // Indexes
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_user_sessions_user ON user_sessions(userId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_user_sessions_device ON user_sessions(deviceId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_home_banners_active ON home_banners(isActive, displayOrder);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_cart_cache_user ON cart_cache(userId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_cat ON products(categoryId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_products_parent ON products(parentCategory);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_addresses_user ON addresses(userId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_orders_customer ON orders(customerId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(orderId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_wishlist_user ON wishlist(userId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_delivery_tasks_rider ON delivery_tasks(riderId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_coupons_code ON coupons(code);',
    );
  }

  // â”€â”€â”€ CRUD Operations â”€â”€â”€

  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    await init();
    if (_db != null) {
      return await _db!.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    }

    // Memory query fallback
    var list = List<Map<String, dynamic>>.from(_memoryTables[table] ?? []);
    if (where != null && whereArgs != null) {
      list = _filterMemoryList(list, where, whereArgs);
    }
    if (limit != null && list.length > limit) {
      list = list.sublist(
        offset ?? 0,
        (offset ?? 0) + limit > list.length
            ? list.length
            : (offset ?? 0) + limit,
      );
    }
    return list;
  }

  Future<int> insert(
    String table,
    Map<String, dynamic> values, {
    String? nullColumnHack,
    sql.ConflictAlgorithm conflictAlgorithm = sql.ConflictAlgorithm.replace,
  }) async {
    await init();
    int result = 1;
    if (_db != null) {
      result = await _db!.insert(
        table,
        values,
        nullColumnHack: nullColumnHack,
        conflictAlgorithm: conflictAlgorithm,
      );
    } else {
      final list = _memoryTables.putIfAbsent(table, () => []);
      final pkKey = _getPrimaryKeyName(table);
      final id =
          values[pkKey]?.toString() ??
          DateTime.now().millisecondsSinceEpoch.toString();
      list.removeWhere((item) => item[pkKey]?.toString() == id);
      list.add(Map<String, dynamic>.from(values));
    }
    notifyTable(table);
    return result;
  }

  Future<int> insertOrReplace(String table, Map<String, dynamic> values) {
    return insert(
      table,
      values,
      conflictAlgorithm: sql.ConflictAlgorithm.replace,
    );
  }

  Future<int> update(
    String table,
    Map<String, dynamic> values, {
    String? where,
    List<Object?>? whereArgs,
    sql.ConflictAlgorithm? conflictAlgorithm,
  }) async {
    await init();
    int result = 0;
    if (_db != null) {
      result = await _db!.update(
        table,
        values,
        where: where,
        whereArgs: whereArgs,
        conflictAlgorithm: conflictAlgorithm,
      );
    } else {
      final list = _memoryTables[table] ?? [];
      for (var i = 0; i < list.length; i++) {
        if (_matchesCondition(list[i], where, whereArgs)) {
          list[i] = {...list[i], ...values};
          result++;
        }
      }
    }
    notifyTable(table);
    return result;
  }

  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    await init();
    int result = 0;
    if (_db != null) {
      result = await _db!.delete(table, where: where, whereArgs: whereArgs);
    } else {
      final list = _memoryTables[table] ?? [];
      final beforeLen = list.length;
      if (where != null && whereArgs != null && whereArgs.isNotEmpty) {
        list.removeWhere((item) => _matchesCondition(item, where, whereArgs));
      } else {
        list.clear();
      }
      result = beforeLen - list.length;
    }
    notifyTable(table);
    return result;
  }

  Future<List<Map<String, dynamic>>> rawQuery(
    String sqlStr, [
    List<Object?>? arguments,
  ]) async {
    await init();
    if (_db != null) {
      return await _db!.rawQuery(sqlStr, arguments);
    }
    if (sqlStr.toUpperCase().contains('COUNT(*)')) {
      for (final table in _memoryTables.keys) {
        if (sqlStr.toLowerCase().contains(table.toLowerCase())) {
          return [
            {'count': _memoryTables[table]?.length ?? 0}
          ];
        }
      }
    }
    return [];
  }

  String _getPrimaryKeyName(String table) {
    switch (table) {
      case 'seller_profiles':
        return 'sellerId';
      case 'rider_profiles':
        return 'riderId';
      case 'notification_preferences':
        return 'userId';
      case 'system_telemetry':
      case 'app_preferences':
      case 'app_secure_vault':
      case 'app_rate_limits':
        return 'key';
      case 'cart_cache':
        return 'productId';
      case 'offline_mutations':
        return 'id';
      case 'schema_migrations':
        return 'version';
      case 'user_2fa':
        return 'userId';
      default:
        return 'id';
    }
  }

  bool _matchesCondition(
    Map<String, dynamic> item,
    String? where,
    List<Object?>? whereArgs,
  ) {
    if (where == null || whereArgs == null || whereArgs.isEmpty) return true;
    final conditions = where.split(RegExp(r'\s+AND\s+', caseSensitive: false));
    int argIndex = 0;
    for (final condition in conditions) {
      if (condition.contains('!=')) {
        final parts = condition.trim().split(RegExp(r'\s*!=\s*'));
        if (parts.length == 2 && parts[1].trim() == '?') {
          final col = parts[0].trim();
          if (argIndex < whereArgs.length) {
            final targetVal = whereArgs[argIndex]?.toString();
            argIndex++;
            final itemVal = item[col]?.toString();
            if (itemVal == targetVal) return false;
          }
        }
      } else {
        final parts = condition.trim().split(RegExp(r'\s*=\s*'));
        if (parts.length == 2 && parts[1].trim() == '?') {
          final col = parts[0].trim();
          if (argIndex < whereArgs.length) {
            final targetVal = whereArgs[argIndex]?.toString();
            argIndex++;
            final itemVal = item[col]?.toString();
            if (itemVal != targetVal) return false;
          }
        }
      }
    }
    return true;
  }

  List<Map<String, dynamic>> _filterMemoryList(
    List<Map<String, dynamic>> list,
    String where,
    List<Object?> whereArgs,
  ) {
    if (whereArgs.isEmpty) return list;
    return list
        .where((item) => _matchesCondition(item, where, whereArgs))
        .toList();
  }

  @visibleForTesting
  void resetForTest() {
    _memoryTables.clear();
  }

  Future<void> seedInitialData() async {
    await _seedSqliteDatabaseIfEmpty();
  }

  Future<void> _seedSqliteDatabaseIfEmpty() async {
    if (_db == null) return;
    final count = sql.Sqflite.firstIntValue(
      await _db!.rawQuery('SELECT COUNT(*) FROM categories'),
    );
    if ((count ?? 0) > 0) return;

    final batch = _db!.batch();

    // 1. Seed Categories
    final categories = PakistanCatalogDataset.getCategories();
    for (int i = 0; i < categories.length; i++) {
      final c = categories[i];
      batch.insert('categories', {
        'id': c.id,
        'name': c.name,
        'parentType': c.parentType.name,
        'iconEmoji': c.iconEmoji,
        'imageUrl': c.imageUrl,
        'productCount': c.productCount,
        'subcategoriesJson': jsonEncode(c.subcategories),
        'sortOrder': i,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }

    // 2. Seed Products
    final products = PakistanCatalogDataset.getProducts();
    for (final p in products) {
      batch.insert('products', {
        'id': p.id,
        'title': p.title,
        'description': p.description,
        'basePrice': p.basePrice,
        'salePrice': p.salePrice,
        'discountPercentage': p.discountPercentage.toDouble(),
        'categoryId': p.categoryType.name,
        'subcategory': p.categoryName,
        'parentCategory': p.categoryType.name,
        'imageUrl': p.images.isNotEmpty ? p.images.first : '',
        'secondaryImagesJson': jsonEncode(p.images),
        'rating': p.rating,
        'reviewCount': p.reviewCount,
        'isAvailable': p.inStock ? 1 : 0,
        'isFlashDeal': p.isFlashDeal ? 1 : 0,
        'stockQuantity': p.totalStock,
        'brand': p.brand,
        'vendorId': p.sellerId,
        'vendorStoreName': p.sellerName,
        'fullDataJson': jsonEncode(p.toJson()),
        'createdAt': DateTime.now().toIso8601String(),
      });
    }

    // 3. Seed Partner Marts (Verified Pakistani Merchants)
    _seedVendorsBatch(batch);

    // 4. Seed Support AI Welcome Assistant
    batch.insert('support_messages', {
      'id': 'msg_welcome_ai',
      'threadId': 'thread_main',
      'senderType': 'aiAgent',
      'text':
          'Assalam-o-Alaikum! 👋 I am your Groclyra 24/7 Intelligent Support Assistant, connected to your local SQL database and nationwide Pakistan delivery network.\n\nHow may I assist you with your orders, groceries, or crockery today?',
      'createdAt': DateTime.now().toIso8601String(),
    });

    // 6. Seed Coupons
    _seedCouponsBatch(batch);

    // 7. Seed Home Promotional Banners (Marketing CMS)
    _seedHomeBannersBatch(batch);

    // 8. Seed Schema Migration
    batch.insert('schema_migrations', {
      'version': 1,
      'name': 'initial_enterprise_schema_v1',
      'appliedAt': DateTime.now().toIso8601String(),
    });

    await batch.commit(noResult: true);
  }

  void _seedHomeBannersBatch(sql.Batch batch) {
    final now = DateTime.now().toIso8601String();
    final banners = [
      {
        'id': 'banner_crockery',
        'tag': '✨ ROYAL CROCKERY FESTIVAL • 35% OFF',
        'title': 'Imperial Bone China & Crystal Dining',
        'subtitle': 'Luxury 72-Pc Dinner Sets, Opal Glassware & Noritake Porcelain',
        'badgeText': 'VERIFIED LUXURY',
        'floatingEmojis': '🍽️☕🥣',
        'gradientColorsJson': jsonEncode(['#1E1B4B', '#3730A3', '#6366F1']),
        'targetPillar': 'crockery',
        'ctaText': 'Explore Sets →',
        'isActive': 1,
        'displayOrder': 0,
        'createdAt': now,
      },
      {
        'id': 'banner_grocery',
        'tag': '🛒 MEGA PANTRY SAVINGS • FLAT 20% OFF',
        'title': 'Monthly Grocery Super Saver Pantry',
        'subtitle': 'Super Basmati Rice, Pure Canola Oil & Shan Gourmet Spices',
        'badgeText': 'SAME DAY DISPATCH',
        'floatingEmojis': '🌾🍚🧂',
        'gradientColorsJson': jsonEncode(['#064E3B', '#047857', '#10B981']),
        'targetPillar': 'grocery',
        'ctaText': 'Stock Pantry →',
        'isActive': 1,
        'displayOrder': 1,
        'createdAt': now,
      },
      {
        'id': 'banner_dairy',
        'tag': '🥛 100% PURE FARM FRESH • DAILY SPECIAL',
        'title': 'Sunrise Dairy Milk & Artisan Bakes',
        'subtitle': 'Pure Farm Milk, Free-Range Eggs & Dawn Fresh Artisan Breads',
        'badgeText': 'FRESH MORNING STOCK',
        'floatingEmojis': '🥛🧀🥖',
        'gradientColorsJson': jsonEncode(['#78350F', '#B45309', '#F59E0B']),
        'targetPillar': 'dairyBakery',
        'ctaText': 'View Bakery →',
        'isActive': 1,
        'displayOrder': 2,
        'createdAt': now,
      },
      {
        'id': 'banner_fastfood',
        'tag': '🔥 CRAVINGS EXPRESS • FLAT 25% OFF',
        'title': 'Crispy Broast, Burgers & Loaded Fries',
        'subtitle': "Hot & Fresh from K&N's Deli, OPTP Grill & Partner Kitchens",
        'badgeText': 'HOT IN 25 MINS',
        'floatingEmojis': '🍔🍟🍗',
        'gradientColorsJson': jsonEncode(['#881337', '#BE123C', '#FF5722']),
        'targetPillar': 'fastFood',
        'ctaText': 'Order Food →',
        'isActive': 1,
        'displayOrder': 3,
        'createdAt': now,
      },
    ];
    for (final b in banners) {
      batch.insert('home_banners', b, conflictAlgorithm: sql.ConflictAlgorithm.ignore);
    }
  }

  void _seedCouponsBatch(sql.Batch batch) {
    final now = DateTime.now().toIso8601String();
    final coupons = [
      {
        'id': 'cpn_freeship',
        'code': 'FREESHIP',
        'title': 'Free Doorstep Delivery Across Pakistan',
        'discountPercentage': 100,
        'maxDiscount': 250.0,
        'minOrderAmount': 1999.0,
        'validUntil': '2027-12-31T23:59:59Z',
        'isActive': 1,
        'usageCount': 420,
        'createdAt': now,
      },
      {
        'id': 'cpn_cravings25',
        'code': 'CRAVINGS25',
        'title': 'Flat 25% Off Food & Fresh Delights',
        'discountPercentage': 25,
        'maxDiscount': 600.0,
        'minOrderAmount': 1200.0,
        'validUntil': '2027-12-31T23:59:59Z',
        'isActive': 1,
        'usageCount': 850,
        'createdAt': now,
      },
      {
        'id': 'cpn_royal15',
        'code': 'ROYAL15',
        'title': '15% Off Royal Bone China Dinner Sets',
        'discountPercentage': 15,
        'maxDiscount': 5000.0,
        'minOrderAmount': 10000.0,
        'validUntil': '2027-12-31T23:59:59Z',
        'isActive': 1,
        'usageCount': 140,
        'createdAt': now,
      },
    ];
    for (final c in coupons) {
      batch.insert('coupons', c);
    }
  }

  void _seedMemoryTables() {
    // Memory categories
    final categories = PakistanCatalogDataset.getCategories();
    _memoryTables['categories'] = categories.asMap().entries.map<Map<String, dynamic>>((e) {
      final c = e.value;
      return <String, dynamic>{
        'id': c.id,
        'name': c.name,
        'parentType': c.parentType.name,
        'iconEmoji': c.iconEmoji,
        'imageUrl': c.imageUrl,
        'productCount': c.productCount,
        'subcategoriesJson': jsonEncode(c.subcategories),
        'sortOrder': e.key,
        'createdAt': DateTime.now().toIso8601String(),
      };
    }).toList();

    // Memory products
    final products = PakistanCatalogDataset.getProducts();
    _memoryTables['products'] = products.map<Map<String, dynamic>>((p) {
      return <String, dynamic>{
        'id': p.id,
        'title': p.title,
        'description': p.description,
        'basePrice': p.basePrice,
        'salePrice': p.salePrice,
        'discountPercentage': p.discountPercentage.toDouble(),
        'categoryId': p.categoryType.name,
        'subcategory': p.categoryName,
        'parentCategory': p.categoryType.name,
        'imageUrl': p.images.isNotEmpty ? p.images.first : '',
        'secondaryImagesJson': jsonEncode(p.images),
        'rating': p.rating,
        'reviewCount': p.reviewCount,
        'isAvailable': p.inStock ? 1 : 0,
        'isFlashDeal': p.isFlashDeal ? 1 : 0,
        'stockQuantity': p.totalStock,
        'brand': p.brand,
        'vendorId': p.sellerId,
        'vendorStoreName': p.sellerName,
        'fullDataJson': jsonEncode(p.toJson()),
        'createdAt': DateTime.now().toIso8601String(),
      };
    }).toList();

    _memoryTables['users'] = [];

    _memoryTables['vendor_integrations'] = <Map<String, dynamic>>[
      {
        'id': 'vendor_alfatah',
        'name': 'Al-Fatah Gourmet Mart',
        'storeName': 'Al-Fatah Gourmet Mart',
        'logoUrl':
            'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=300',
        'bannerUrl':
            'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800',
        'rating': 4.9,
        'verified': 1,
        'isOpen': 1,
        'city': 'Lahore',
        'address': 'Main Gulberg, Lahore, Punjab',
        'totalProducts': 540,
        'liveSync': 1,
        'catalogType': 'grocery',
        'contactNumber': '+92 42 111 253 282',
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'id': 'vendor_imtiaz',
        'name': 'Imtiaz Super Market',
        'storeName': 'Imtiaz Super Market',
        'logoUrl':
            'https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=300',
        'bannerUrl':
            'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=800',
        'rating': 4.8,
        'verified': 1,
        'isOpen': 1,
        'city': 'Karachi',
        'address': 'Clifton Block 2, Karachi, Sindh',
        'totalProducts': 820,
        'liveSync': 1,
        'catalogType': 'grocery',
        'contactNumber': '+92 21 111 468 429',
        'createdAt': DateTime.now().toIso8601String(),
      },
      {
        'id': 'vendor_metro',
        'name': 'Metro Cash & Carry',
        'storeName': 'Metro Cash & Carry',
        'logoUrl':
            'https://images.unsplash.com/photo-1583258292688-d0213dc5a3a8?w=300',
        'bannerUrl':
            'https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=800',
        'rating': 4.7,
        'verified': 1,
        'isOpen': 1,
        'city': 'Islamabad',
        'address': 'Sector I-11/4, Islamabad',
        'totalProducts': 950,
        'liveSync': 1,
        'catalogType': 'crockery',
        'contactNumber': '+92 51 111 638 760',
        'createdAt': DateTime.now().toIso8601String(),
      },
    ];

    _memoryTables['delivery_tasks'] = [];

    _memoryTables['support_messages'] = <Map<String, dynamic>>[
      {
        'id': 'msg_welcome_ai',
        'threadId': 'thread_main',
        'senderType': 'aiAgent',
        'text':
            'Assalam-o-Alaikum! 👋 I am your Groclyra 24/7 Intelligent Support Assistant, connected to your local SQL database and nationwide Pakistan delivery network.\n\nHow may I assist you with your orders, groceries, or crockery today?',
        'createdAt': DateTime.now().toIso8601String(),
      },
    ];

    _memoryTables['app_preferences'] ??= [];
    _memoryTables['app_secure_vault'] ??= [];
    _memoryTables['cart_cache'] ??= [];
    _memoryTables['app_rate_limits'] ??= [];
    _memoryTables['offline_mutations'] ??= [];
    _memoryTables['user_2fa'] ??= [];
    _memoryTables['user_sessions'] ??= [];
    _memoryTables['database_backups'] ??= [];
  }

  void _seedVendorsBatch(sql.Batch batch) {
    final now = DateTime.now().toIso8601String();
    final vendors = [
      {
        'id': 'vendor_alfatah',
        'name': 'Al-Fatah Gourmet Mart',
        'storeName': 'Al-Fatah Gourmet Mart',
        'logoUrl':
            'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=300',
        'bannerUrl':
            'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800',
        'rating': 4.9,
        'verified': 1,
        'isOpen': 1,
        'city': 'Lahore',
        'address': 'Main Gulberg, Lahore, Punjab',
        'totalProducts': 540,
        'liveSync': 1,
        'catalogType': 'grocery',
        'contactNumber': '+92 42 111 253 282',
        'createdAt': now,
      },
      {
        'id': 'vendor_imtiaz',
        'name': 'Imtiaz Super Market',
        'storeName': 'Imtiaz Super Market',
        'logoUrl':
            'https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=300',
        'bannerUrl':
            'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=800',
        'rating': 4.8,
        'verified': 1,
        'isOpen': 1,
        'city': 'Karachi',
        'address': 'Clifton Block 2, Karachi, Sindh',
        'totalProducts': 820,
        'liveSync': 1,
        'catalogType': 'grocery',
        'contactNumber': '+92 21 111 468 429',
        'createdAt': now,
      },
      {
        'id': 'vendor_metro',
        'name': 'Metro Cash & Carry',
        'storeName': 'Metro Cash & Carry',
        'logoUrl':
            'https://images.unsplash.com/photo-1583258292688-d0213dc5a3a8?w=300',
        'bannerUrl':
            'https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=800',
        'rating': 4.7,
        'verified': 1,
        'isOpen': 1,
        'city': 'Islamabad',
        'address': 'Sector I-11/4, Islamabad',
        'totalProducts': 950,
        'liveSync': 1,
        'catalogType': 'crockery',
        'contactNumber': '+92 51 111 638 760',
        'createdAt': now,
      },
    ];
    for (final v in vendors) {
      batch.insert('vendor_integrations', v);
    }
  }
}
