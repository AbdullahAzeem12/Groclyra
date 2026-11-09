-- ==============================================================================
-- GROCLYRA ENTERPRISE SQL PRODUCTION SEED DATA
-- Database: groclyra.db
-- Clean Production Master: Zero fake accounts; real user accounts are created
-- dynamically through real SQL authentication (Sign Up / Sign In / OAuth).
-- ==============================================================================

-- 1. VERIFIED PAKISTANI PARTNER MARTS
INSERT OR REPLACE INTO vendor_integrations (id, name, storeName, logoUrl, bannerUrl, rating, verified, isOpen, city, address, totalProducts, liveSync, catalogType, createdAt)
VALUES 
('vendor_alfatah', 'Al-Fatah Gourmet Mart', 'Al-Fatah Gourmet Mart', 'https://images.unsplash.com/photo-1578916171728-46686eac8d58?w=300', 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=800', 4.9, 1, 1, 'Lahore', 'Main Gulberg, Lahore, Punjab', 540, 1, 'grocery', datetime('now')),
('vendor_imtiaz', 'Imtiaz Super Market', 'Imtiaz Super Market', 'https://images.unsplash.com/photo-1534723452862-4c874018d66d?w=300', 'https://images.unsplash.com/photo-1604719312566-8912e9227c6a?w=800', 4.8, 1, 1, 'Karachi', 'Clifton Block 2, Karachi, Sindh', 820, 1, 'grocery', datetime('now')),
('vendor_chenone_official', 'ChenOne Luxury Home & Crockery', 'ChenOne Official Outlet', 'https://images.unsplash.com/photo-1610701596007-11502861dcfa?w=300', 'https://images.unsplash.com/photo-1578749556568-bc2c40e68b61?w=800', 4.9, 1, 1, 'Lahore', 'Mall of Lahore, Cantt, Lahore', 320, 1, 'crockery', datetime('now')),
('vendor_optp_pakistan', 'OPTP Express Foods', 'OPTP Express & K&N Deli', 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=300', 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=800', 4.7, 1, 1, 'Karachi', 'DHA Phase 6, Karachi, Sindh', 110, 1, 'fastFood', datetime('now'));

-- 2. COUPONS & PROMOTIONAL OFFERS
INSERT OR REPLACE INTO coupons (id, code, title, discountPercentage, maxDiscount, minOrderAmount, validUntil, isActive, usageCount, createdAt)
VALUES
('cpn_freeship', 'FREESHIP', 'Free Doorstep Delivery Across Pakistan', 100, 250.0, 1999.0, '2027-12-31T23:59:59Z', 1, 420, datetime('now')),
('cpn_cravings25', 'CRAVINGS25', 'Flat 25% Off Food & Fresh Delights', 25, 600.0, 1200.0, '2027-12-31T23:59:59Z', 1, 850, datetime('now')),
('cpn_royal15', 'ROYAL15', '15% Off Royal Bone China Dinner Sets', 15, 5000.0, 10000.0, '2027-12-31T23:59:59Z', 1, 140, datetime('now')),
('cpn_ramadan20', 'RAMADAN20', 'Flat 20% Off Mega Bazaar Groceries', 20, 1000.0, 2500.0, '2027-12-31T23:59:59Z', 1, 1290, datetime('now'));

-- 3. INITIAL SYSTEM TELEMETRY
INSERT OR REPLACE INTO system_telemetry (key, value, updatedAt)
VALUES
('schema_version', '1.0.0', datetime('now')),
('platform_status', 'operational', datetime('now')),
('last_catalog_sync', datetime('now'), datetime('now')),
('realtime_bus_status', 'active', datetime('now'));

-- 4. INITIAL MIGRATION RECORD
INSERT OR REPLACE INTO schema_migrations (version, name, appliedAt)
VALUES (1, 'initial_enterprise_schema_v1', datetime('now'));
