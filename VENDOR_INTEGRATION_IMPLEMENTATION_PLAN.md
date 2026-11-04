# Groclyra Real Vendor Catalogs — Implementation Plan

**Scope:** Replace demo product fallbacks with an authoritative live catalog; build the authorized external-vendor ingestion foundation; define vendor onboarding, inventory/order integrity, commission attribution, and a phased path to genuine production connectivity.

**Important boundary:** This patch does not claim that any retailer has granted Groclyra API access. Real sync requires the retailer's approval, credentials, data-use rights, and a safe order/fulfilment path. The integration functions support authorized WooCommerce and Shopify Admin API connections. Other connector types are future adapters and are not represented as connected until implemented and tested.

## 1. Source audit findings

The supplied archive contains `lib/` source code, but not the full Flutter project root, so the dependency manifest, deployed Firestore rules/indexes, complete Firebase Functions project, and release configuration could not be audited or built here.

Findings in the supplied source:

- `lib/main.dart` called `FirestoreSeeder.seedIfEmpty()` on app startup.
- `lib/core/services/firestore_seeder.dart` seeded `MockCatalogData` categories and products into Firestore.
- `lib/features/catalog/data/repositories/catalog_repository.dart` returned mock categories/products when Firebase was unavailable, collections were empty, or requests failed.
- `lib/features/customer/product_details/presentation/screens/product_details_screen.dart` searched `MockCatalogData` after real data sources failed.
- `ProductEntity` already included `externalPosId` and `posProvider`, but that did not constitute a live connector.
- Product display defaults included a generic Unsplash image and a 4.5 star fallback, which could be mistaken for real product imagery or reviews.

The applied patch stops automatic demonstration seeding, removes runtime mock fallbacks, adds source metadata to `ProductEntity`, adds a vendor integration status repository and admin screen, adds a server-side sync queue and scheduled sync implementation, and adds a dry-run-first script to retire the 21 exact legacy demo product IDs.

## 2. Vendor connectivity: what is realistically available

There is no universal, free, public API that grants access to every Pakistani shop, mall, supermarket, dairy, bakery, restaurant, and crockery store. Access depends on the retailer's commerce system and its permission model.

### Recommended integration lanes

1. **Groclyra marketplace sellers:** a seller signs up, completes KYC/contract onboarding, adds products or imports a vendor-authorized feed, and accepts orders in the Groclyra seller portal. This is the fastest route to unified checkout for independent businesses.
2. **WooCommerce merchant-owned store:** read catalog through the WooCommerce REST API using a read-only key issued by the store owner. Stock reservations, order write-back and cancellations require separately authorized write permissions and tested order integration.
3. **Shopify merchant-owned store:** use the Shopify Admin GraphQL API with a merchant-authorized app token and only the required scopes, for example product/inventory read scopes. Do not ask merchants for a token copied from another app or expose the token to Flutter.
4. **POS integration:** Foodics or another POS can be integrated only for a merchant who has enabled/licensed the applicable API and authorized Groclyra. Product/inventory access is not automatically equivalent to a license to place or fulfill Groclyra orders.
5. **Retail chain partnerships:** ask the chain's commercial/technology team for a contract, catalog feed, stock/price update method, order acceptance interface, and service-level agreement. The patch does not fabricate public endpoints for retailers that do not expose them.
6. **CSV/SFTP feed:** for small shops without an API, accept a documented UTF-8 CSV template over a secured upload/SFTP channel. Validate and stage it exactly like an API feed. This is not real-time by itself; a refresh schedule is negotiated with the seller.
7. **Affiliate route:** where a retailer offers a valid affiliate program, show a clearly labeled external-vendor link and track eligible referral attribution according to that program. Affiliate access does not automatically grant catalog-feed access, real-time stock, in-app checkout, or an entitlement to copy product images.

Official references:

- Foodpanda Partner API: https://developer.foodpanda.com/api-specifications
- Foodpanda Partner API overview: https://developer.foodpanda.com/en/documentation/api-partner-api-overview
- WooCommerce REST API authentication: https://developer.woocommerce.com/docs/apis/rest-api/authentication
- WooCommerce REST API: https://developer.woocommerce.com/docs/apis/rest-api/
- Shopify Storefront API: https://shopify.dev/docs/api/storefront/latest
- Imtiaz supplier form: https://imtiaz.com.pk/global-supplier-form/
- Foodics integration guidance: https://sites.google.com/foodics.com/coe-foodics/product-knowledge/foodics-integration/support-sop/personal-integration

Foodpanda's official Partner API requires partner credentials and is designed around vendor catalog/operations for authorized partners; it must not be treated as a free, unrestricted third-party catalog API. Imtiaz's public supplier form supports a partnership enquiry, not a verified public product API. A supplier/partner request is the right next step for chains without public developer docs.

## 3. Product-data architecture

Preserve the current `products/{productId}` shape for backward compatibility with existing customer, seller, order and search code. Extend it with source provenance and sync state:

- `sourceType`: `native_seller`, `vendor_api`, `pos`, `csv_feed`, or `affiliate`
- `sourceVendorId`: approved Groclyra vendor identifier
- `sourceStoreId`: integration ID
- `sourceProductId`: source provider product ID
- `sourceSku`: source SKU
- `externalProductUrl`: approved vendor's product URL
- `checkoutMode`: `groclyra_marketplace`, `vendor_checkout`, or `affiliate_link`
- `stockStatus`: `in_stock`, `out_of_stock`, or `unknown`
- `inventoryQuantityKnown`: true only when the upstream quantity is actually known
- `sourceUpdatedAt`, `lastSyncedAt`, `catalogSyncStatus`

New external data is first written to `vendorCatalogItems/{stableId}`. This staging collection preserves current vendor truth, source SKU, raw provider identifiers, price/availability, URLs, variants, and source freshness without prematurely exposing a product for sale.

Sync history is stored in `catalogSyncRuns/{runId}` and requested jobs in `vendorSyncRequests/{requestId}`. Integration configuration is stored in `vendorIntegrations/{integrationId}`. API credentials remain in Google Secret Manager; Firestore stores only a Secret Manager resource name.

### Catalog publication safety gate

The connector can publish staged data into the existing `products` collection only when all of these are true:

- domain ownership is verified (`domainOwnershipVerified == true`);
- vendor authorization and product/catalog-use rights are approved (`vendorAuthorizationVerified == true`, `catalogUseRightsVerified == true`) and an agreement reference is recorded;
- `publishToMainCatalog == true`
- `commerceMode == 'marketplace'
- `orderWorkflowReady == true`
- `inventoryMode == 'groclyra_authoritative'`
- `groclyraSellerId` refers to an approved Groclyra seller account

This path means the seller has agreed that Groclyra is the inventory authority and accepts fulfilment through the Groclyra seller workflow. The sync preserves Groclyra-managed quantity and variant stock rather than overwriting it from the external product feed.

If inventory remains authoritative in the vendor's POS, do **not** enable main-catalog publication until an authenticated reservation/order/write-back adapter is implemented and tested. Otherwise Groclyra could oversell stock after an external sale. `catalogOnly` and `affiliate` integrations remain in staging until their presentation, attribution, and checkout rules are implemented.

Newly imported main-catalog products are unapproved by default unless an administrator has explicitly approved the partner and enabled `autoApproveCatalog`. A missing source item is marked inactive in staging; a previously published item is unpublished after a complete, non-truncated successful sync.

## 4. Sync behavior

### Triggers

- A scheduled function checks active integrations every 15 minutes, honors each integration's `nextSyncAt`, and enqueues deterministic per-integration jobs. Each job runs in its own Firestore-triggered function. The current polling granularity is 15 minutes; a 5-minute per-integration interval does not make the scheduler run every 5 minutes.
- Admins can queue a one-off sync through the callable `requestVendorCatalogSync` function. A transactionally claimed request and per-integration lease reduce duplicate/concurrent execution.
- Vendor webhooks should be added only for providers and event types that contractually support them; validate signatures, timestamps, and replay protection. Scheduled reconciliation remains the recovery mechanism.

### Robustness rules

- Run only in trusted backend code.
- Cache or reuse OAuth tokens according to vendor instructions; never put credentials into Flutter or logs.
- Enforce HTTPS and use Secret Manager for credentials.
- Use bounded retries with backoff for 429 and transient 5xx failures; keep upstream response bodies and credentials out of logs.
- Require operator verification of merchant domain ownership, vendor authorization/catalog-use rights, an agreement reference, and explicit ISO 4217 currency configuration.
- Do not deactivate products when a sync failed, was truncated, contained incomplete variants/invalid products, or returned an empty catalog without explicit operator approval.
- Keep a durable sync run with start/end timestamps, counts, warnings and a sanitized error code.
- Never silently claim a queued sync has completed.
- Recheck stock and price at cart/checkout through a supported live vendor endpoint when the vendor remains the source of truth.
- Use stable IDs derived from integration ID and external product ID so repeated syncs update the same records.
- Preserve product moderation and locally managed inventory when updating vendor descriptions/prices/images.
- Avoid overwriting manually curated Groclyra fields unless the integration configuration clearly defines the source as authoritative.

### Freshness policy

Use a source-specific SLA. A fast food menu may need more frequent availability checks than packaged crockery; dairy stock and expiry information can change quickly. Mark records stale when `now - lastSyncedAt` exceeds the configured freshness threshold. Never display an old stock quantity as currently confirmed.

## 5. Current vendor connector support

The additive TypeScript backend code includes two initial connectors:

- `wooCommerce`: WooCommerce REST API product pagination, optional variation import, HTTPS validation, read-only credential use, stock status/quantity normalization, source URL and source modified time.
- `shopifyAdmin`: Shopify Admin GraphQL product pagination, variant/price/image normalization, and warnings where variant pagination needs further handling.

The Flutter model also reserves types for Foodics, Foodpanda Partner, CSV/SFTP, signed webhook, custom API and manual import, but those adapters are **not yet implemented** by this patch. They must not be switched to active until connector code and tests exist.

Provider-specific versions, scopes and payloads change. Pin a supported Shopify API version in each integration and test vendor responses in a sandbox before production. The connector source passed three isolated Node tests and all provided TypeScript files passed the TypeScript parser, but a full dependency-aware build is blocked by missing installed packages. The connectors have not been executed using a real merchant account.

## 6. Data-flow outline

1. An administrator approves a vendor, records the contract/terms, maps its Groclyra seller profile, and stores provider credentials in Secret Manager.
2. An integration record is created using the schema below and starts in `pendingAuthorization`.
3. Validate connectivity in test/sandbox mode and verify catalog, currency, images, SKU/variant mapping and stock semantics.
4. Activate the integration. The scheduler creates a sync run and pulls the vendor catalog.
5. Normalize data into `vendorCatalogItems`, retaining provider IDs and freshness metadata.
6. Review mappings, duplicates, local category mapping, vendor license to use product copy/images, and commerce mode.
7. Only after the order/inventory workflow is proven, set the safe publication gate. Firestore product listeners then update the customer/seller/admin portals.
8. Before each order, validate price, variant, availability, fulfilment area and stock/reservation with the correct authority.
9. Record orders, commissions, vendor payable, refunds, cancellations and attribution using an immutable ledger.
10. Monitor sync health, failures, stale data, vendor response latency and product mismatches. Disable/unpublish a feed safely when access is revoked.

## 7. Suggested integration document

`vendorIntegrations/{integrationId}`:

```json
{
  "vendorId": "approved-groclyra-seller-id",
  "vendorName": "Partner Store Name",
  "provider": "wooCommerce",
  "status": "pendingAuthorization",
  "commerceMode": "catalogOnly",
  "externalStoreName": "Partner Store",
  "externalStoreUrl": "https://merchant.example",
  "secretVersionName": "projects/PROJECT_ID/secrets/GROCLYRA_VENDOR_SECRET/versions/latest",
  "defaultCategoryType": "grocery",
  "defaultCategoryName": "Groceries",
  "currency": "PKR",
  "syncIntervalMinutes": 30,
  "maxProductsPerSync": 3000,
  "supportsCatalogSync": true,
  "supportsInventorySync": true,
  "supportsOrderCreate": false,
  "supportsOrderStatus": false,
  "supportsWebhooks": false,
  "publishToMainCatalog": false,
  "orderWorkflowReady": false,
  "inventoryMode": "vendor_authoritative",
  "inventoryReservationEnabled": false,
  "autoApproveCatalog": false
}
```

This is illustrative configuration, not a connected store. Replace placeholders only with values approved by the merchant. `secretVersionName` must point to a JSON secret containing WooCommerce `consumerKey`/`consumerSecret` or Shopify `accessToken`. Do not store the secret JSON in Firestore.

## 8. Security prerequisites

- Grant the Cloud Functions runtime service account access only to relevant Secret Manager secrets.
- Enable the Secret Manager API and Cloud Functions/Cloud Scheduler services.
- The callable expects a trusted Firebase custom claim `admin: true`. Only a secured administrator provisioning flow may set it.
- Enable App Check for the callable and configure the app's valid App Check provider/debug procedure.
- Merge the proposed Rules fragment into the existing rules; do not replace all current rules with a partial snippet.
- Deny client writes to `vendorIntegrations`, `vendorCatalogItems`, `catalogSyncRuns` and `vendorSyncRequests`; Cloud Functions Admin SDK writes these records.
- Ensure only authorized administrators can read integration configuration and sync errors; vendor users should only see their own sanitized status.
- Do not log Secret Manager payloads, authorization headers, API keys, complete customer addresses or payment details.
- Validate merchant ownership, legal catalog use, country/currency, and data-retention terms before enabling sync.

## 9. Money-making models

### Marketplace commission

The vendor accepts Groclyra orders and fulfils them under a signed agreement. Groclyra records a configurable commission and vendor payable per order line. The commission percentage must be contract-configured per vendor/category and must never be hardcoded inconsistently across seller/admin screens.

`gross_item_amount = quantity × committed_unit_price`

`platform_commission = agreed_rate × commissionable_amount`

`vendor_payable = commissionable_amount - platform_commission - agreed_adjustments`

Refunds, cancellations, discounts, taxes, delivery fees and payment gateway fees need clearly defined treatment in the vendor contract and immutable ledger. Do not treat total order GMV as platform profit.

### Affiliate / referral

Groclyra directs a customer to the partner's own checkout and earns a contractual commission for attributed purchases. Track campaign/affiliate IDs and click IDs, disclose the external checkout, and reconcile conversions against the affiliate network's reports. Do not mix affiliate items into a Groclyra cart unless the partner allows that and supplies the required commerce APIs.

### Software/service fee

Optional vendor subscription for premium analytics, catalogue import, POS synchronization or promoted placement. Label sponsored placement clearly and keep it separate from organic ranking logic.

Do not present any public commission rate as guaranteed. The exact commercial terms must be negotiated and verified with each partner.

## 10. Categories and product quality

Support the four current Groclyra category pillars:

- `grocery`
- `fastFood`
- `dairyBakery`
- `crockery`

For each integration, map source taxonomy to these enums and a reviewed `categoryName`. Add source-specific fields such as unit/weight, ingredients/allergens, nutrition, expiry date or batch/lot, cold-storage requirement, food preparation time, crockery material, pieces count, dishwasher/microwave safety, and SKU/barcode as appropriate.

Keep a normalized product master distinct from a seller offer in the long-term design. The same branded SKU may be offered by multiple stores at different prices/stock. The offer must preserve store, seller, location, price currency, stock authority, delivery coverage and last verified time. Deduplicate using GTIN/barcode where legally available, otherwise a reviewed composite key. Never merge products solely because the titles look similar.

## 11. Rollout phases

### Phase A — Remove false data (implemented in patch)
- Remove startup demo seeding.
- Remove catalog/product-details mock fallbacks.
- Prevent demo seed functions from running in release builds.
- Avoid synthetic default images and default review ratings.
- Include a dry-run-first script to unpublish exact legacy demo product IDs.

### Phase B — Integration administration (partially implemented in patch)
- Vendor integration models and read-only status repository.
- Admin status/sync-history screen and callable sync request.
- Configure Firebase Functions dependencies, rules, App Check, custom admin claim and Secret Manager IAM in the complete project root.

### Phase C — Authorized vendor sync (initial connector implementation added)
- WooCommerce and Shopify Admin connectors to staging collection.
- Credential loading from Secret Manager.
- Pagination, bounded retries, mapping, source provenance and sync history.
- Run compile/tests in the full Functions project and validate with vendor sandboxes.

### Phase D — Order/stock integrity before customer publication
- Implement vendor-specific order creation/reservation, cancellation and status webhooks when the merchant's API permits them.
- Implement external checkout/affiliate links separately.
- Decide whether Groclyra or vendor POS owns quantity.
- Add inventory reservation or write-back and reconciliation.
- Only then enable publication for appropriate integrations.

### Phase E — Commercial onboarding and expansion
- Start with 3–5 willing vendors in one launch city.
- Prioritize WooCommerce merchants, small vendors managed through Groclyra Seller Portal, and participating restaurants/POS vendors.
- Approach large chains such as Imtiaz through official supplier/partnership contacts.
- Expand to additional providers only after their APIs/feeds and contract allow it.

### Phase F — Verification and operations
- Automated tests, live sandbox validation, monitoring, financial reconciliation and rollback playbook.
- Alert when sync age passes the SLA, inventory mismatch rises, or upstream API failures occur.
- Run a controlled beta before city-wide rollout.

## 12. Acceptance checklist

- No app-start demo seeding.
- No mock fallback from customer catalog or product details.
- A genuine empty catalog displays empty state; permission/network errors display an error and retry path.
- Existing seeded mock IDs are reviewed and retired through the dry-run migration script if they exist in production.
- Secrets live in Secret Manager and are never sent to Flutter or saved in plain Firestore fields.
- Integration, sync-run and staged-product state are visible to authorized admins in real time.
- Manual sync requests are authenticated, authorized, deduplicated where appropriate, and report queued/running/succeeded/failed states.
- Partial/truncated/failed source sync never deactivates good catalog data.
- Vendor catalog is not customer-published unless authorization, seller mapping, order workflow and inventory authority satisfy the publication gate.
- Price, currency, SKU, variants, product URLs, image-use rights and source timestamps are preserved.
- Live stock is validated against its true authority at checkout.
- Refunds/cancellations/commissions are ledgered and reconciled with contracts.
- Tests are built and executed in the full project root before a production claim is made.

## 13. Full-project files still needed to finish production deployment

The supplied `lib.zip` was not the complete Flutter/Firebase project. To safely finish integration and verify compilation, the remaining required inputs are the root `pubspec.yaml`, existing `firestore.rules`, `firestore.indexes.json`, `firebase.json`, the existing `functions/` folder if any, current tests and catalog/checkout/order repositories outside the uploaded `lib/` tree, and the vendor accounts/API keys obtained with permission. Do not upload secret values into a chat or commit them to Git; use a secure secrets setup flow.
