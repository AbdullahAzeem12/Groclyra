-- ==============================================================================
-- GROCLYRA ENTERPRISE SQL PRODUCTION SEED DATA
-- Database: groclyra.db
-- ==============================================================================

-- 1. VERIFIED PAKISTANI PARTNER MARTS
INSERT OR REPLACE INTO vendor_integrations (id, name, storeName, logoUrl, bannerUrl, rating, verified, isOpen, city, address, totalProducts, liveSync, catalogType, createdAt)
VALUES 
('vendor_alfatah', 'Al-Fatah Gourmet Mart', 'Al-Fatah Gourmet Mart', 'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=300', 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800', 4.9, 1, 1, 'Lahore', 'Main Gulberg, Lahore, Punjab', 540, 1, 'grocery', datetime('now')),
('vendor_imtiaz', 'Imtiaz Super Market', 'Imtiaz Super Market', 'https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=300', 'https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=800', 4.8, 1, 1, 'Karachi', 'Clifton Block 2, Karachi, Sindh', 820, 1, 'grocery', datetime('now')),
('vendor_chenone_official', 'ChenOne Luxury Home & Crockery', 'ChenOne Official Outlet', 'https://images.unsplash.com/photo-1610701596007-11502861dcfa?w=300', 'https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=800', 4.9, 1, 1, 'Lahore', 'Mall of Lahore, Cantt, Lahore', 320, 1, 'crockery', datetime('now')),
('vendor_optp_pakistan', 'OPTP Express Foods', 'OPTP Express & K&N Deli', 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=300', 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=800', 4.7, 1, 1, 'Karachi', 'DHA Phase 6, Karachi, Sindh', 110, 1, 'fastFood', datetime('now'));

-- 2. CORE PLATFORM ACCOUNTS
INSERT OR REPLACE INTO users (id, name, email, phone, role, accountStatus, activePortalRole, authorizedRolesJson, avatarUrl, deliveryAddress, deliveryZone, createdAt, updatedAt)
VALUES
('usr_customer_demo', 'Abdullah Azeem', 'kheroali66@gmail.com', '03001234567', 'customer', 'active', 'customer', '["customer"]', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200', 'Clifton, Karachi, Sindh', 'Karachi', datetime('now'), datetime('now')),
('usr_seller_demo', 'Imtiaz Store Manager', 'seller@groclyra.pk', '03007654321', 'seller', 'active', 'seller', '["seller"]', 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200', 'Clifton Block 2, Karachi', 'Karachi', datetime('now'), datetime('now')),
('usr_rider_demo', 'Hamza Express Rider', 'rider@groclyra.pk', '03112233445', 'rider', 'active', 'rider', '["rider"]', 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200', 'Gulberg 3, Lahore', 'Lahore', datetime('now'), datetime('now')),
('usr_admin_demo', 'Platform Administrator', 'admin@groclyra.pk', '03223344556', 'admin', 'active', 'admin', '["admin"]', 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200', 'F-7 Markaz, Islamabad', 'Islamabad', datetime('now'), datetime('now'));

-- 3. SELLER PROFILES
INSERT OR REPLACE INTO seller_profiles (sellerId, storeName, ownerName, businessEmail, phone, storeCategory, verificationStatus, city, fullAddress, cnicOrNtn, rating, totalOrders, createdAt, updatedAt)
VALUES
('usr_seller_demo', 'Imtiaz Super Market', 'Imtiaz Store Manager', 'seller@groclyra.pk', '03007654321', 'grocery', 'verified', 'Karachi', 'Clifton Block 2, Karachi, Sindh', 'NTN-4892019-2', 4.9, 1420, datetime('now'), datetime('now'));

-- 4. RIDER PROFILES
INSERT OR REPLACE INTO rider_profiles (riderId, fullName, phone, city, vehicleType, vehicleNumber, cnicNumber, drivingLicenseNumber, accountStatus, rating, totalDeliveries, isOnline, walletBalance, createdAt, updatedAt)
VALUES
('usr_rider_demo', 'Hamza Express Rider', '03112233445', 'Lahore', 'motorcycle', 'KHI-LEJ-9042', '42101-1234567-1', 'DL-KHI-89212', 'active', 4.95, 384, 1, 4520.0, datetime('now'), datetime('now'));

-- 5. COUPONS & PROMOTIONAL OFFERS
INSERT OR REPLACE INTO coupons (id, code, title, discountPercentage, maxDiscount, minOrderAmount, validUntil, isActive, usageCount, createdAt)
VALUES
('cpn_freeship', 'FREESHIP', 'Free Doorstep Delivery Across Pakistan', 100, 250.0, 1999.0, '2027-12-31T23:59:59Z', 1, 420, datetime('now')),
('cpn_cravings25', 'CRAVINGS25', 'Flat 25% Off Food & Fresh Delights', 25, 600.0, 1200.0, '2027-12-31T23:59:59Z', 1, 850, datetime('now')),
('cpn_royal15', 'ROYAL15', '15% Off Royal Bone China Dinner Sets', 15, 5000.0, 10000.0, '2027-12-31T23:59:59Z', 1, 140, datetime('now')),
('cpn_ramadan20', 'RAMADAN20', 'Flat 20% Off Mega Bazaar Groceries', 20, 1000.0, 2500.0, '2027-12-31T23:59:59Z', 1, 1290, datetime('now'));

-- 6. INITIAL SYSTEM TELEMETRY
INSERT OR REPLACE INTO system_telemetry (key, value, updatedAt)
VALUES
('schema_version', '1.0.0', datetime('now')),
('platform_status', 'operational', datetime('now')),
('last_catalog_sync', datetime('now'), datetime('now')),
('realtime_bus_status', 'active', datetime('now'));

-- 7. INITIAL MIGRATION RECORD
INSERT OR REPLACE INTO schema_migrations (version, name, appliedAt)
VALUES (1, 'initial_enterprise_schema_v1', datetime('now'));
