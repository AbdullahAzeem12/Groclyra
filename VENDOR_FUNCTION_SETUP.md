# Vendor Integration Backend Setup

This patch is additive to the supplied `lib/` source. The uploaded archive did not contain the project root, `pubspec.yaml`, existing Functions package, Firestore Rules, or indexes. Merge these files into the existing project instead of replacing working backend code.

## 1. Flutter dependency

The admin screen uses `cloud_functions`. Ensure the project root `pubspec.yaml` includes a compatible version of `cloud_functions` for the version of `firebase_core`/FlutterFire already in the app. Then run `flutter pub get`. Do not blindly replace all dependency versions.

## 2. Functions package

A standalone additive package is in `functions/`. If the project already has `functions/package.json`, `functions/tsconfig.json`, or `functions/src/index.ts`, merge the dependencies/compiler options and export the three vendor functions from the existing index. Do not overwrite existing order, payment, KYC, or notification functions.

From the existing Functions directory, install dependencies and compile before deployment. The supplied functions package uses Node 20, TypeScript, Firebase Admin, Firebase Functions v2, and Google Secret Manager. Confirm the active Firebase project and billing/Blaze requirements for scheduled functions and Secret Manager before deploying.

The functions are regioned to `asia-south1`; keep the Flutter `FirebaseFunctions.instanceFor(region: 'asia-south1')` in sync with the deployed region.

## 3. Secret Manager

Create a separate secret per vendor integration. The database stores only its resource name, never the credential payload. Example secret JSON shapes:

WooCommerce:
```json
{"consumerKey":"ck_read_only_value","consumerSecret":"cs_read_only_value"}
```

Shopify Admin:
```json
{"accessToken":"shpat_authorized_value"}
```

Use vendor-created, minimum-scope credentials. WooCommerce credentials should be read-only for catalog-only sync. Shopify must have the least catalog/variant/inventory scopes required by the exact fields the integration reads. Never commit values to source control, paste them into the Flutter app, write them into Firestore, or log them.

Enable the Secret Manager API. Grant the deployed Functions runtime service account `roles/secretmanager.secretAccessor` only on secrets it needs. Validate domain ownership and merchant authorization out of band before activating a store integration.

## 4. Admin authorization and App Check

The callable requires a trusted Firebase custom claim `admin: true` and App Check. The supplied `lib/` code does not include a reviewed custom-claim provisioning tool or App Check setup, so these must be integrated with the project's existing trusted admin allowlist/role workflow. Only server-side Admin SDK code or an audited operator script may set custom claims; never allow a client to grant itself `admin: true`.

If Groclyra already uses a different trusted admin authorization scheme, adapt `requirePlatformAdmin` to it after reviewing current rules. Do not trust a mutable `users/{uid}.role` field alone unless it is protected and the backend reads it through an equally trusted authorization path.

## 5. Firestore rules and indexes

The admin UI reads `vendorIntegrations`, `catalogSyncRuns` and requests status. Vendor staging records are intended to remain admin-only initially. Add equivalent access restrictions to the existing Rules and create only needed indexes. Do not replace the current rules with the fragment file.

Important Firestore semantics: matching `allow` expressions are ORed. An `allow write: if false` in one matching block does not override a different broad matching rule that grants writes. Review all current overlapping match blocks and remove/limit any permissive wildcard rule for these paths. Test with the Firebase Emulator Suite before deployment.

Suggested indexes are usually not needed for the simple reads in this patch, but the actual `orderBy('startedAt')` and integration filters should be exercised in the target project. Add the exact indexes requested by Firestore's error messages to the existing index file, then deploy them with the current indexes.

## 6. Integration document: example only

```json
{
  "vendorId": "approved-vendor-uuid",
  "vendorName": "Authorized Partner Store",
  "provider": "wooCommerce",
  "status": "pendingAuthorization",
  "commerceMode": "catalogOnly",
  "externalStoreUrl": "https://merchant-controlled-domain.example",
  "domainOwnershipVerified": false,
  "vendorAuthorizationVerified": false,
  "catalogUseRightsVerified": false,
  "agreementRef": "",
  "secretVersionName": "projects/PROJECT_ID/secrets/GROCLYRA_VENDOR_SECRET/versions/latest",
  "defaultCategoryType": "grocery",
  "defaultCategoryName": "Groceries",
  "categoryMappings": {
    "Tableware": "crockery",
    "Prepared Meals": "fastFood",
    "Dairy": "dairyBakery",
    "Bakery": "dairyBakery",
    "Grocery": "grocery"
  },
  "currency": "PKR",
  "syncIntervalMinutes": 30,
  "maxProductsPerSync": 3000,
  "allowEmptyCatalogDeactivate": false,
  "publishToMainCatalog": false,
  "orderWorkflowReady": false,
  "inventoryMode": "vendor_authoritative",
  "inventoryReservationEnabled": false,
  "autoApproveCatalog": false,
  "supportsCatalogSync": true,
  "supportsInventorySync": false,
  "supportsOrderCreate": false,
  "supportsOrderStatus": false,
  "supportsWebhooks": false
}
```

The values are illustrative and do not represent a connected vendor. Use a real vendor-authorized URL, exact currency, secret reference, and approved category mappings. Set `domainOwnershipVerified: true`, `vendorAuthorizationVerified: true`, `catalogUseRightsVerified: true`, and a non-empty `agreementRef` only after the operator has documented those approvals. Sync refuses integrations that lack those gates. The connector rejects IP-literal, localhost, private/local-style, credential-bearing, non-HTTPS, and non-standard-port store URLs. The sync code requires an explicit three-letter currency; it does not infer currency from the country.

## 7. Status before publishing

The initial connectors write normalized product records into `vendorCatalogItems`. This is a staging area, not a claim that the vendor is ready to fulfil Groclyra orders. Publishing to the existing customer `products` collection is blocked unless all configured marketplace readiness checks pass. Because the patch does not yet implement vendor-specific stock reservation/order creation/write-back, do not mark a vendor-authoritative store as publish-ready.

First run against an authorized test store with `commerceMode: catalogOnly`, check the records and sync run, validate pricing/currency/variant/image rights, and test the stale-product safety behavior. Then implement the vendor's approved order, cancellation, status, and inventory reconciliation methods before marketplace release.

## 8. Legacy demo data

`scripts/retire_legacy_demo_catalog.mjs` is dry-run-first. Use it only after backing up the production database and verifying the exact IDs. It marks only known legacy demo product IDs unapproved; it never deletes documents. Review the dry-run output before using `--apply` with an authenticated admin environment.

## 9. Verification commands

From the Flutter project root (once `pubspec.yaml` is available):

```bash
flutter pub get
flutter analyze
flutter test
```

From the Functions directory:

```bash
npm install
npm run build
```

Then add Functions emulator tests for secret lookup, vendor fixture normalization, sync lease contention, skipped/invalid products, empty catalog safeguards, publication gating, authorization failures, and duplicate requests. The patch was authored without the project root/vendor credentials and has not yet been verified by compiling against your exact existing dependency versions or by connecting to a live merchant account.
