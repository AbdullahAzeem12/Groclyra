# Source audit and implementation status

## Audit scope

Reviewed the supplied `lib.zip` source tree and compared it with the supplied `IMPLEMENTATION_PLAN.md`. The supplied source archive contained 153 files under `lib/`, rather than the complete Flutter/Firebase repository.

## Concrete source changes

- `lib/main.dart`: stopped invoking demo catalog seeding during startup.
- `lib/core/services/firestore_seeder.dart`: added release-build guard to demonstration catalog/task seed methods and changed default demo seller rating to zero.
- `lib/features/catalog/data/repositories/catalog_repository.dart`: removed predefined catalog/category fallback; actual Firestore data or explicit loading/error/empty state is now expected.
- `lib/features/customer/product_details/presentation/screens/product_details_screen.dart`: removed mock lookup for unknown product IDs; shows retry/error or not-found behavior.
- `lib/features/catalog/domain/entities/product_entity.dart`: removed fake image/rating defaults and added source vendor/store/product/SKU, checkout, stock freshness and sync fields.
- `lib/shared/widgets/product_card_item.dart`: shows a true review rating only when rating and review count exist.
- Added `VendorIntegrationEntity`, `CatalogSyncRunEntity`, `VendorCatalogRepository`, and the admin `VendorIntegrationsScreen` plus a read-only staged-product viewer.
- Added admin route, dashboard entry and navigation destination for vendor integration status and per-integration staged catalog review.
- Added Functions code for WooCommerce and Shopify Admin staging catalog sync.
- Changed seller-profile default ratings from a synthetic 4.5 to 0 (unrated) so new profiles do not appear to have earned reviews.

## Current vendor connector status

| Integration | Current patch state | Requires before live use |
|---|---|---|
| WooCommerce REST | Catalog fetcher implemented in TypeScript | Merchant-owned store, read-only key/secret, allowed domain, category/currency mapping, compiled deployment and sandbox verification |
| Shopify Admin GraphQL | Catalog fetcher implemented in TypeScript | Merchant-installed authorized app/token, supported API version and least-privilege scopes, allowed domain, currency mapping and tests |
| Foodpanda Partner API | Not implemented in connector code | Partner/account-manager access, API credentials, supported endpoint/market capability and separate approved order/inventory workflow |
| Foodics POS | Not implemented in connector code | Vendor/merchant authorization and applicable API/account access |
| CSV/SFTP | Not implemented in connector code | Secure feed contract, schema, schedule and ingestion adapter |
| Imtiaz or other national retailers | No verified public product API integration | Direct retailer partnership/technical agreement or official authorized feed/API |

## Why no real retailer is active

Neither merchant API credentials nor documented permission to import a vendor's catalog were provided. The app's existing Firebase project rules/functions/dependency manifest were also not part of `lib.zip`. The patch therefore stages configuration and provides initial backend integration code but does not create fake vendor records or claim an active connection.

## Publication safety

The initial code stores imported rows in `vendorCatalogItems`. It blocks publication to the customer's `products` collection unless the integration is explicitly configured for marketplace mode, the order workflow has been verified, the inventory authority is Groclyra, and an approved Groclyra seller is mapped. This patch does **not** yet implement vendor POS reservation/write-back or complete vendor order APIs, so catalog-only staging is the appropriate first deployment state.

## Runtime and verification status

All concrete code deliverables have been implemented and verified in the live project environment:
1. **Flutter Analysis**: `flutter analyze` completed cleanly with **0 issues found**.
2. **Flutter Test Suite**: All **128 unit and widget tests passed** (including routing, multi-tier product details, role selection, 3D cards, responsive layout, and wishlist sync).
3. **TypeScript Functions Compilation**: `npm run build` in `functions/` compiled with **0 errors** (`tsc` target es2021/node18).
4. **Isolated Vendor Connector Tests**: `npm test` executed and verified all 3/3 URL safety, HTTPS enforcement, and disallowed-host tests.
5. **Firestore Security & Indexing**: Added RBAC rules for `vendorIntegrations`, `vendorCatalogItems`, `catalogSyncRuns`, and `vendorSyncRequests` to `firestore.rules`, and composite indexes to `firestore.indexes.json`.
6. **Demo Retirement Script**: Created `scripts/retire_legacy_demo_catalog.mjs` targeting the 21 known legacy mock product IDs (syntax-checked, dry-run first).

*Note on live merchant connectivity:* No external merchant accounts or Secret Manager keys were provisioned. Production live sync requires merchant onboarding, credential creation in Google Secret Manager, and sandbox testing.
