# Groclyra vendor catalog integration patch

This patch contains changes to the supplied `lib/` source plus additive Firebase Functions code, a dry-run-first legacy catalog migration script, and integration documentation.

## Important status

**No retailer is connected yet.** The upload contained the `lib/` tree and a plan document, but not the complete project root, existing Functions backend, Firestore Rules/indexes, dependency manifest, or vendor-authorized API credentials. The patch removes demo fallbacks and adds an integration foundation; it cannot truthfully claim live products from a real vendor until a merchant has authorized access and the server setup is completed.

## Included

- Removed automatic demo catalog seeding from app startup.
- Prevented the demo seeder from running in release builds.
- Removed mock product/category fallback behavior in the customer catalog repository and mock product lookup in product details.
- Removed synthetic default product image and rating values.
- Added product source provenance fields to `ProductEntity`.
- Added admin-facing vendor integration, sync-history, and staged-product screens.
- Added provider-neutral vendor integration models and Firestore/Callable repository.
- Added server-side initial WooCommerce REST and Shopify Admin GraphQL catalog fetchers.
- Added Secret Manager credential lookup, staging catalog, sync runs, sync queue, 15-minute scheduling, deduplicated scheduled job IDs, sync lease, category mapping, currency/domain/authorization checks, and conservative missing-item deactivation.
- Kept customer-facing product publishing gated until marketplace order/stock ownership workflow is verified.
- Added a dry-run-first script to unpublish exactly 21 known legacy demo product IDs without deleting documents or order history.
- Added setup notes, Rules fragment, detailed plan, master implementation prompt, and the previously supplied implementation plan.

## Required before running

1. Merge the patched `lib/` files into the complete project.
2. Add a compatible `cloud_functions` FlutterFire dependency if the existing `pubspec.yaml` does not already contain it.
3. Merge `functions/` into the existing Firebase Functions project. Do not overwrite existing payment, order, notification, or role functions; merge the exports and dependencies.
4. Merge security changes into the current Firestore Rules, review all overlapping wildcard rules, and test using the Emulator Suite.
5. Configure Firebase App Check, trusted admin custom claims, Secret Manager API/IAM, and the correct Firebase project/region.
6. Obtain vendor permission, valid read-only credentials, product/image data rights, domain verification, explicit currency, and category mapping.
7. Test a catalog-only integration against an authorized merchant sandbox/store. The supplied connectors support WooCommerce and Shopify Admin only; Foodpanda, Foodics, CSV/SFTP, and generic webhook adapters remain future work.
8. Implement and test stock reservation/write-back, order creation, cancellation, order status, and vendor settlement before enabling marketplace publication for vendor-owned inventory.

## Checks actually performed

- Compared the uploaded original `lib.zip` with the patched source: 15 Dart files changed or added.
- Confirmed `MockCatalogData` is no longer referenced by the app-startup path, customer catalog repository, or product-details screen; the demo seeder remains available only for explicit debug use.
- TypeScript parser check passed for all five supplied `.ts` files.
- Three isolated Node connector tests passed (WooCommerce normalization/category mapping, unsafe URL rejection, and Shopify variant/category normalization). The connector source was transpiled with the locally available TypeScript compiler for this isolated run.
- Full dependency-aware TypeScript compilation was **not verified** because npm dependency installation timed out and Firebase/Secret Manager type packages were not available in this environment.
- Flutter analysis/tests were **not run** because `flutter`, `dart`, and the root `pubspec.yaml` were not included/available here.
- No live vendor credentials were supplied, so no retailer connection or real sync was executed.

See `docs/VENDOR_FUNCTION_SETUP.md` for the required configuration and `docs/VENDOR_INTEGRATION_IMPLEMENTATION_PLAN.md` for the staged rollout.
