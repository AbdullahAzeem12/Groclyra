-- Migration v2: Add Coupons and Schema Migrations Tracking
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

CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY NOT NULL,
    name TEXT NOT NULL,
    appliedAt TEXT NOT NULL
);

INSERT OR REPLACE INTO schema_migrations (version, name, appliedAt)
VALUES (2, 'v2_add_coupons_and_audit', datetime('now'));

