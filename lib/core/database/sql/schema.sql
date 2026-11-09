-- ==============================================================================
-- GROCLYRA ENTERPRISE SQL REALTIME DATABASE SCHEMA
-- Engine: SQLite (sqflite)
-- Database: groclyra.db
-- Portals: Customer, Seller, Rider, Administrator
-- ==============================================================================

PRAGMA foreign_keys = ON;

-- 1. USERS & AUTHENTICATION TABLE
CREATE TABLE IF NOT EXISTS users (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    role TEXT NOT NULL DEFAULT 'customer',
    accountStatus TEXT NOT NULL DEFAULT 'active',
    activePortalRole TEXT DEFAULT 'customer',
    authorizedRolesJson TEXT,
    avatarUrl TEXT,
    deliveryAddress TEXT,
    deliveryZone TEXT,
    deviceToken TEXT,
    createdAt TEXT NOT NULL,
    updatedAt TEXT,
    fullDataJson TEXT
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(accountStatus);

-- 2. CATEGORIES TAXONOMY TABLE
CREATE TABLE IF NOT EXISTS categories (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    parentType TEXT NOT NULL,
    iconEmoji TEXT NOT NULL,
    imageUrl TEXT NOT NULL,
    productCount INTEGER DEFAULT 0,
    subcategoriesJson TEXT NOT NULL,
    sortOrder INTEGER DEFAULT 0,
    createdAt TEXT NOT NULL,
    fullDataJson TEXT
);

CREATE INDEX IF NOT EXISTS idx_categories_parent ON categories(parentType);
CREATE INDEX IF NOT EXISTS idx_categories_order ON categories(sortOrder);

-- 3. PRODUCTS & INVENTORY MASTER TABLE
CREATE TABLE IF NOT EXISTS products (
    id TEXT PRIMARY KEY NOT NULL,
    title TEXT NOT NULL,
    brand TEXT NOT NULL,
    basePrice REAL NOT NULL,
    salePrice REAL NOT NULL,
    discountPercentage INTEGER DEFAULT 0,
    unit TEXT NOT NULL,
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
    vendorId TEXT,
    vendorStoreName TEXT,
    fullDataJson TEXT NOT NULL,
    createdAt TEXT NOT NULL,
    updatedAt TEXT,
    FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_products_category ON products(categoryId);
CREATE INDEX IF NOT EXISTS idx_products_parent ON products(parentCategory);
CREATE INDEX IF NOT EXISTS idx_products_flash ON products(isFlashDeal);
CREATE INDEX IF NOT EXISTS idx_products_brand ON products(brand);
CREATE INDEX IF NOT EXISTS idx_products_vendor ON products(vendorId);
CREATE INDEX IF NOT EXISTS idx_products_price ON products(salePrice);

-- 4. CUSTOMER REVIEWS & RATINGS TABLE
CREATE TABLE IF NOT EXISTS reviews (
    id TEXT PRIMARY KEY NOT NULL,
    productId TEXT NOT NULL,
    userId TEXT NOT NULL,
    userName TEXT NOT NULL,
    userAvatar TEXT,
    rating REAL NOT NULL,
    comment TEXT NOT NULL,
    verified INTEGER DEFAULT 1,
    helpfulVotes INTEGER DEFAULT 0,
    createdAt TEXT NOT NULL,
    fullDataJson TEXT,
    FOREIGN KEY (productId) REFERENCES products(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_reviews_product ON reviews(productId);
CREATE INDEX IF NOT EXISTS idx_reviews_rating ON reviews(rating);

-- 5. DELIVERY ADDRESSES & GEOCODING TABLE
CREATE TABLE IF NOT EXISTS addresses (
    id TEXT PRIMARY KEY NOT NULL,
    userId TEXT NOT NULL,
    label TEXT NOT NULL,
    recipientName TEXT NOT NULL,
    phone TEXT NOT NULL,
    provinceOrTerritory TEXT NOT NULL,
    city TEXT NOT NULL,
    locality TEXT,
    societyOrScheme TEXT,
    sectorOrBlock TEXT,
    street TEXT,
    houseOrFlat TEXT,
    formattedAddress TEXT NOT NULL,
    latitude REAL NOT NULL,
    longitude REAL NOT NULL,
    isDefault INTEGER DEFAULT 0,
    serviceabilityStatus TEXT NOT NULL,
    fullDataJson TEXT NOT NULL,
    createdAt TEXT NOT NULL,
    updatedAt TEXT
);

CREATE INDEX IF NOT EXISTS idx_addresses_user ON addresses(userId);
CREATE INDEX IF NOT EXISTS idx_addresses_default ON addresses(userId, isDefault);

-- 6. ORDERS MASTER TABLE
CREATE TABLE IF NOT EXISTS orders (
    id TEXT PRIMARY KEY NOT NULL,
    userId TEXT NOT NULL,
    totalAmount REAL NOT NULL,
    discountAmount REAL DEFAULT 0.0,
    deliveryFee REAL DEFAULT 0.0,
    finalAmount REAL NOT NULL,
    status TEXT NOT NULL,
    paymentMethod TEXT NOT NULL,
    paymentStatus TEXT NOT NULL,
    transactionRef TEXT,
    deliveryAddressJson TEXT NOT NULL,
    trackingNumber TEXT,
    riderId TEXT,
    estimatedDeliveryTime TEXT,
    deliveredAt TEXT,
    fullDataJson TEXT NOT NULL,
    createdAt TEXT NOT NULL,
    updatedAt TEXT
);

CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(userId);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_rider ON orders(riderId);
CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(createdAt);

-- 7. ORDER LINE ITEMS TABLE
CREATE TABLE IF NOT EXISTS order_items (
    id TEXT PRIMARY KEY NOT NULL,
    orderId TEXT NOT NULL,
    productId TEXT NOT NULL,
    title TEXT NOT NULL,
    variantName TEXT,
    unitPrice REAL NOT NULL,
    quantity INTEGER NOT NULL,
    lineTotal REAL NOT NULL,
    imageUrl TEXT,
    fullDataJson TEXT,
    FOREIGN KEY (orderId) REFERENCES orders(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(orderId);
CREATE INDEX IF NOT EXISTS idx_order_items_product ON order_items(productId);

-- 8. CUSTOMER WISHLIST & PRICE TRACKING TABLE
CREATE TABLE IF NOT EXISTS wishlist (
    id TEXT PRIMARY KEY NOT NULL,
    userId TEXT NOT NULL,
    productId TEXT NOT NULL,
    originalPrice REAL NOT NULL,
    currentPrice REAL NOT NULL,
    addedAt TEXT NOT NULL,
    fullDataJson TEXT NOT NULL,
    UNIQUE(userId, productId)
);

CREATE INDEX IF NOT EXISTS idx_wishlist_user ON wishlist(userId);
CREATE INDEX IF NOT EXISTS idx_wishlist_product ON wishlist(productId);

-- 9. SELLER PARTNER PROFILES TABLE
CREATE TABLE IF NOT EXISTS seller_profiles (
    sellerId TEXT PRIMARY KEY NOT NULL,
    storeName TEXT NOT NULL,
    ownerName TEXT NOT NULL,
    businessEmail TEXT NOT NULL,
    phone TEXT NOT NULL,
    storeCategory TEXT NOT NULL,
    verificationStatus TEXT NOT NULL DEFAULT 'verified',
    city TEXT NOT NULL,
    fullAddress TEXT NOT NULL,
    cnicOrNtn TEXT NOT NULL,
    bankName TEXT,
    accountNumber TEXT,
    accountTitle TEXT,
    rating REAL DEFAULT 4.8,
    totalOrders INTEGER DEFAULT 0,
    fullDataJson TEXT,
    createdAt TEXT NOT NULL,
    updatedAt TEXT
);

CREATE INDEX IF NOT EXISTS idx_seller_city ON seller_profiles(city);
CREATE INDEX IF NOT EXISTS idx_seller_status ON seller_profiles(verificationStatus);

-- 10. EXPRESS DELIVERY TASKS & FULFILLMENT TABLE
CREATE TABLE IF NOT EXISTS delivery_tasks (
    id TEXT PRIMARY KEY NOT NULL,
    orderId TEXT NOT NULL,
    riderId TEXT,
    status TEXT NOT NULL,
    pickupLocationName TEXT NOT NULL,
    pickupAddress TEXT NOT NULL,
    pickupLat REAL NOT NULL,
    pickupLng REAL NOT NULL,
    dropRecipientName TEXT NOT NULL,
    dropAddress TEXT NOT NULL,
    dropPhone TEXT NOT NULL,
    dropLat REAL NOT NULL,
    dropLng REAL NOT NULL,
    deliveryFeeEarnings REAL NOT NULL,
    deliveryOtp TEXT NOT NULL,
    fullDataJson TEXT NOT NULL,
    createdAt TEXT NOT NULL,
    updatedAt TEXT
);

CREATE INDEX IF NOT EXISTS idx_delivery_order ON delivery_tasks(orderId);
CREATE INDEX IF NOT EXISTS idx_delivery_rider ON delivery_tasks(riderId);
CREATE INDEX IF NOT EXISTS idx_delivery_status ON delivery_tasks(status);

-- 11. RIDER PROFILES & FLEET TELEMETRY TABLE
CREATE TABLE IF NOT EXISTS rider_profiles (
    riderId TEXT PRIMARY KEY NOT NULL,
    fullName TEXT NOT NULL,
    phone TEXT NOT NULL,
    city TEXT NOT NULL,
    vehicleType TEXT NOT NULL,
    vehicleNumber TEXT NOT NULL,
    cnicNumber TEXT NOT NULL,
    drivingLicenseNumber TEXT NOT NULL,
    accountStatus TEXT NOT NULL DEFAULT 'active',
    rating REAL DEFAULT 4.9,
    totalDeliveries INTEGER DEFAULT 0,
    currentLat REAL,
    currentLng REAL,
    isOnline INTEGER DEFAULT 1,
    walletBalance REAL DEFAULT 0.0,
    fullDataJson TEXT,
    createdAt TEXT NOT NULL,
    updatedAt TEXT
);

CREATE INDEX IF NOT EXISTS idx_rider_status ON rider_profiles(accountStatus);
CREATE INDEX IF NOT EXISTS idx_rider_city ON rider_profiles(city);

-- 12. VENDOR INTEGRATIONS (PAKISTANI MARTS) TABLE
CREATE TABLE IF NOT EXISTS vendor_integrations (
    id TEXT PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    storeName TEXT NOT NULL,
    logoUrl TEXT,
    bannerUrl TEXT,
    rating REAL DEFAULT 4.8,
    verified INTEGER DEFAULT 1,
    isOpen INTEGER DEFAULT 1,
    city TEXT NOT NULL,
    address TEXT NOT NULL,
    totalProducts INTEGER DEFAULT 0,
    liveSync INTEGER DEFAULT 1,
    catalogType TEXT NOT NULL,
    createdAt TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_vendor_city ON vendor_integrations(city);

-- 13. PUSH NOTIFICATIONS TABLE
CREATE TABLE IF NOT EXISTS notifications (
    id TEXT PRIMARY KEY NOT NULL,
    userId TEXT NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    type TEXT NOT NULL,
    isRead INTEGER DEFAULT 0,
    createdAt TEXT NOT NULL,
    fullDataJson TEXT
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(userId);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(userId, isRead);

-- 14. CUSTOMER SUPPORT MESSAGES TABLE
CREATE TABLE IF NOT EXISTS support_messages (
    id TEXT PRIMARY KEY NOT NULL,
    ticketId TEXT NOT NULL,
    userId TEXT NOT NULL,
    senderType TEXT NOT NULL,
    message TEXT NOT NULL,
    attachmentUrl TEXT,
    createdAt TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_support_ticket ON support_messages(ticketId);

-- 15. NOTIFICATION PREFERENCES TABLE
CREATE TABLE IF NOT EXISTS notification_preferences (
    userId TEXT PRIMARY KEY NOT NULL,
    ordersPush INTEGER DEFAULT 1,
    promotionsPush INTEGER DEFAULT 1,
    deliverySms INTEGER DEFAULT 1,
    newsletterEmail INTEGER DEFAULT 0,
    updatedAt TEXT NOT NULL
);

-- 16. PLATFORM AUDIT & SECURITY TELEMETRY TABLE
CREATE TABLE IF NOT EXISTS system_telemetry (
    key TEXT PRIMARY KEY NOT NULL,
    value TEXT NOT NULL,
    updatedAt TEXT NOT NULL
);

-- 17. COUPONS & PROMO CODES TABLE
CREATE TABLE IF NOT EXISTS coupons (
    id TEXT PRIMARY KEY NOT NULL,
    code TEXT NOT NULL UNIQUE,
    title TEXT NOT NULL,
    discountPercentage INTEGER NOT NULL,
    maxDiscount REAL,
    minOrderAmount REAL DEFAULT 0.0,
    validUntil TEXT NOT NULL,
    isActive INTEGER DEFAULT 1,
    usageCount INTEGER DEFAULT 0,
    createdAt TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_coupons_code ON coupons(code);

-- 18. SCHEMA MIGRATIONS AUDIT TABLE
CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    appliedAt TEXT NOT NULL
);

-- 19. APP PREFERENCES TABLE (Replaces SharedPreferences with Reactive SQL)
CREATE TABLE IF NOT EXISTS app_preferences (
    key TEXT PRIMARY KEY NOT NULL,
    value TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'string',
    updatedAt TEXT NOT NULL
);

-- 20. APP SECURE VAULT TABLE (Replaces FlutterSecureStorage with SQL Storage)
CREATE TABLE IF NOT EXISTS app_secure_vault (
    key TEXT PRIMARY KEY NOT NULL,
    value TEXT NOT NULL,
    updatedAt TEXT NOT NULL
);

-- 21. SHOPPING CART SQL CACHE TABLE (Replaces JSON Local Cache)
CREATE TABLE IF NOT EXISTS cart_cache (
    userId TEXT NOT NULL,
    productId TEXT NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    variantName TEXT,
    unitPrice REAL NOT NULL,
    fullDataJson TEXT NOT NULL,
    updatedAt TEXT NOT NULL,
    PRIMARY KEY (userId, productId)
);

CREATE INDEX IF NOT EXISTS idx_cart_cache_user ON cart_cache(userId);

-- 22. RATE LIMITS & SECURITY COOLDOWNS TABLE
CREATE TABLE IF NOT EXISTS app_rate_limits (
    key TEXT PRIMARY KEY NOT NULL,
    hitCount INTEGER DEFAULT 0,
    lastAttemptEpoch INTEGER DEFAULT 0,
    lockoutUntilEpoch INTEGER DEFAULT 0,
    updatedAt TEXT NOT NULL
);

-- 23. OFFLINE MUTATIONS SYNC QUEUE TABLE
CREATE TABLE IF NOT EXISTS offline_mutations (
    id TEXT PRIMARY KEY NOT NULL,
    mutationType TEXT NOT NULL,
    payloadJson TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    createdAt TEXT NOT NULL
);

-- ==============================================================================
-- AUTOMATIC TIMESTAMP & INTEGRITY TRIGGERS
-- ==============================================================================

CREATE TRIGGER IF NOT EXISTS trg_users_updated_at
AFTER UPDATE ON users
FOR EACH ROW
WHEN NEW.updatedAt <= OLD.updatedAt OR NEW.updatedAt IS NULL
BEGIN
    UPDATE users SET updatedAt = datetime('now') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_products_updated_at
AFTER UPDATE ON products
FOR EACH ROW
WHEN NEW.updatedAt <= OLD.updatedAt OR NEW.updatedAt IS NULL
BEGIN
    UPDATE products SET updatedAt = datetime('now') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_orders_updated_at
AFTER UPDATE ON orders
FOR EACH ROW
WHEN NEW.updatedAt <= OLD.updatedAt OR NEW.updatedAt IS NULL
BEGIN
    UPDATE orders SET updatedAt = datetime('now') WHERE id = NEW.id;
END;

CREATE TRIGGER IF NOT EXISTS trg_delivery_tasks_updated_at
AFTER UPDATE ON delivery_tasks
FOR EACH ROW
WHEN NEW.updatedAt <= OLD.updatedAt OR NEW.updatedAt IS NULL
BEGIN
    UPDATE delivery_tasks SET updatedAt = datetime('now') WHERE id = NEW.id;
END;
