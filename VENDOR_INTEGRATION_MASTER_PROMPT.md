# Expert Master Prompt — Real Vendor Catalogs and Commerce for Groclyra

You are a principal Flutter/Firebase marketplace architect, retail integration engineer, geospatial commerce engineer, vendor partnership strategist, security engineer and senior test engineer.

## Goal

Continue work on the existing Groclyra Flutter project and transform its product catalog from static/demo content into a lawful, vendor-authorized, near-real-time multi-vendor commerce system for grocery, packaged foods, fast food, dairy, bakery and crockery across Pakistan.

**Do not claim that every Pakistani shop has a free public API.** Discover each vendor's real commerce/POS platform and obtain its authorization. Use only merchant-approved APIs, webhooks, feeds, CSV/SFTP files and documented affiliate programs. Do not scrape private endpoints or reuse product images/descriptions without rights.

Start by reading the existing implementation plan, source code, Firestore Rules/indexes, functions code, dependency manifest and tests. Preserve existing working flows and data formats unless a migration is justified. Audit all static catalog fallbacks, seed-on-boot calls, default fake ratings/images, hardcoded products, static flash deals, hardcoded vendor availability and fallback pricing.

## Existing audit findings to preserve

The supplied `lib/` source previously:
- seeded `MockCatalogData` into Firestore at application startup when the catalog was empty;
- returned mock products/categories on empty Firestore, offline, or query errors;
- resolved missing product IDs by searching the mock catalog;
- defaulted to a generic Unsplash product image and a 4.5 rating if source fields were absent;
- had `externalPosId`/`posProvider` fields but no complete external-vendor catalog integration.

The additive patch has removed those runtime mock fallbacks, made demo seeding debug-only, added external source metadata to `ProductEntity`, added vendor integration/sync-run models and an admin status screen, and added initial server-side WooCommerce/Shopify staging connectors. Verify these changes against the full project and complete integration; do not assume the missing root Firebase configuration has already been updated.

## Non-negotiable principles

1. Never fabricate a live vendor, product, price, stock count, discount, review, location, API endpoint, commission or successful synchronization.
2. Never expose vendor API secrets, private POS tokens, model keys or customer data to Flutter.
3. Keep external API integrations in trusted Cloud Functions/backend code.
4. Vendor permission, data-use rights, source image rights, order-flow authority and commission terms must be recorded before activation.
5. The app must distinguish `catalogOnly`, `affiliate`, and `marketplace` vendors. Their checkout and fulfillment models are not interchangeable.
6. Inventory must have one declared authority: vendor POS, or Groclyra Seller Portal. If vendor POS owns inventory, implement reservation/write-back and checkout validation before listing those products for sale.
7. Do not mark an order paid, stock reserved, a refund completed, or an order placed until the authoritative backend confirms it.
8. Keep existing seller, customer, rider, admin, orders, cart, payments and product routes working. Use additive migrations and feature flags.
9. Do not deploy production code until tests pass against the complete project.
10. Report what is implemented, what is tested, what needs credentials, and what remains unimplemented.

## Provider discovery and partnership workflow

Create a vendor integration registry and admin onboarding workflow. For each target vendor, research official developer/partner docs and record:

- official company/product and contact route;
- API/POS/shop platform and country coverage;
- required partner agreement, app review or paid API license;
- accessible product fields and image-use conditions;
- inventory and price endpoints, update mechanisms, rate limits and webhook signatures;
- supported order, cancel, return and status endpoints;
- checkout ownership, payments, tax, delivery and settlement responsibilities;
- commission/referral terms and attribution method;
- sandbox credentials, live credentials and test cases;
- contract/permission evidence and review date.

Do not treat the following as universal free feeds:
- Foodpanda Partner API: partner-authorized operational APIs; obtain its approval and permitted use case before attempting to ingest any catalog.
- WooCommerce REST API: available for a specific merchant only after that store owner issues authorized API credentials.
- Shopify Admin API: merchant-authorized token and appropriate API scopes are required.
- Foodics or other POS APIs: check merchant account/license and owner authorization.
- Imtiaz and other retail chains: contact the official partnership/supplier/technology team where a public product API is not documented.
- Affiliate programs: verify commission terms and whether product feeds are permitted. A referral link alone does not provide realtime stock or allow a unified Groclyra checkout.

## Required marketplace architecture

### Flutter

Maintain the existing feature-oriented architecture. Keep catalog presentation driven by repositories and Riverpod streams. Add:

- live-source status/freshness labels that only appear when supported by sync metadata;
- a vendor integration admin screen with provider, status, last successful sync, next sync, product counts, warnings, recent runs and a secure Sync Now action;
- loading, empty, permission-denied, timeout, stale-data, offline, retry and fatal provider error states;
- category/type filters for Grocery, Fast Food, Dairy & Bakery and Crockery;
- vendor/store selector and area/serviceability filters;
- correct product images from authorized feeds, safe placeholders for missing images, verified ratings only, and real discount calculations;
- source-aware product routing: Groclyra checkout for marketplace offers, vendor checkout for direct purchase only when supported, affiliate deep link for affiliate offers, and no buy button for catalog-only records.

Do not show “live” merely because Firestore snapshots are used. Display source's last successful sync and mark stale when the source SLA is exceeded.

### Firestore data model

Retain `products/{productId}` for backward compatibility. Add:

- `vendorIntegrations/{integrationId}`: provider, vendorId, vendorName, status, commerceMode, store URL, Secret Manager resource name, sync interval, category mapping, inventory authority, order readiness, publication gate, source capabilities, last sync status, next sync and failure fields.
- `vendorCatalogItems/{stableId}`: staged normalized source product with integration ID, external product ID, SKU, title, description, brand, category, currency, price, compare-at price, variants, stock state/quantity if actually known, product URL, permitted image URLs, source modification time, last-seen sync run and active flag.
- `catalogSyncRuns/{runId}`: provider, integration, running/succeeded/failed status, timestamps, counts, warnings and sanitized error code.
- `vendorSyncRequests/{requestId}`: only backend-created queue requests with authorized requester and queue status.
- `vendorOrders/{vendorOrderId}` where needed to map Groclyra order IDs to vendor API IDs idempotently.
- `vendorSettlementLedger/{entryId}` for auditable commission, vendor payable, refunds and payout lines.

Keep user/customer data separate from vendor configuration. Secret Manager stores actual key JSON. Firestore stores only the `secretVersionName` resource reference. Use stable IDs derived from integration ID and external product ID; preserve source IDs so updates are deterministic.

Longer term, separate a normalized product master (`catalogProducts`) from each vendor's offer (`sellerOffers`). A single branded SKU can have several offers with distinct prices, inventory, locations, shipping promises and seller identifiers. Do not merge by title alone.

### Backend adapters

Implement a provider interface, e.g. `fetchCatalog`, `getProduct`, `checkAvailability`, `reserveInventory`, `createVendorOrder`, `getVendorOrderStatus`, `cancelVendorOrder`, and `verifyWebhook`. Only implement operations actually supported by the provider and contract. Use provider adapters for:

- WooCommerce REST API;
- Shopify Admin GraphQL API;
- CSV/SFTP feed;
- signed webhooks where a vendor provides them;
- later, Foodics or Foodpanda partner APIs after access is approved;
- manual Groclyra seller catalog for merchants without an API.

Do not implement unsupported provider names as a fake success. Fail with an explicit `provider_not_implemented` status.

For every HTTP call: HTTPS only, strict host allowlist/domain validation for known stores, timeouts, bounded retries for 429/5xx, respect Retry-After, paginate, validate schemas, impose maximum products/page sizes, record latency, and sanitize logs. Use the supported API version and necessary minimum scopes. Verify merchant domain ownership, partner authorization, catalog/image use rights and agreement reference before outbound calls; reject IP literals/local/private-style hosts and require explicit ISO currency, and never print auth headers or response payloads with sensitive data.

### Sync algorithm

1. Load an active integration and validate vendor identity, provider, currency, permission status and secret reference.
2. Create a durable `catalogSyncRuns` record before network activity.
3. Load secret JSON from Secret Manager using the runtime service account.
4. Retrieve source products with pagination or a delta cursor/ETag when the provider supports it.
5. Normalize into a staging schema; validate product ID, title, price, currency, variants, unit, image URLs, stock semantics and categories.
6. Skip or flag invalid prices; never create fake zero-priced offers or fake quantities.
7. Write data using stable IDs and batched chunks below Firestore's write limit.
8. Preserve local fields, moderation, reviews and Groclyra-managed inventory. Only update fields marked authoritative by the integration configuration.
9. On a complete successful non-truncated sync, mark upstream-missing records inactive. On a failed or truncated sync, do not deactivate good records.
10. Record counts, warnings, timestamps, next scheduled sync, health status and safe error codes.
11. Use webhook events for low-latency updates only if the vendor documents them and signatures can be verified; keep scheduled reconciliation as recovery.
12. Propagate published Firestore changes through existing real-time product streams to all authorized portals.
13. At cart/checkout, refresh price/stock and revalidate address/serviceability. Prevent overselling through reservation or transaction/inventory authority.

## Publication rules

Keep `catalogOnly` and `affiliate` products in staging or the dedicated external-offer view until their user experience is complete.

Publish into the existing `products` collection only if:
- the vendor agreement/authorization is approved;
- the mapped Groclyra seller is approved;
- commerce mode is `marketplace`;
- `orderWorkflowReady` has been tested end-to-end;
- inventory authority is correctly defined;
- if vendor POS owns inventory, a working reservation/write-back adapter exists;
- local category, currency and image rights are verified;
- moderation policy is satisfied.

If a user is sent to the vendor checkout, make that explicit and preserve the vendor's terms. Do not make the customer think Groclyra has placed an order in a vendor system when it has only written a local Firestore document.

## Pakistan localization and category data

Use PKR only where the source and vendor agreement confirm that currency. Support Urdu and English titles/descriptions when supplied by the vendor. Normalize units (g/kg/ml/litre/pack/piece/set), food ingredients/allergens, expiry/batch/cold-chain fields, and crockery material/quantity/size. Treat delivery area and serviceability as separate backend rules from geographic search.

For fast food, include outlet branch, operating status, preparation estimate, option/modifier data, sold-out menu status and allergen data when supported. For dairy and bakery, include freshness date/expiry, storage mode, batch and delivery-window constraints if the vendor supplies them. For crockery, retain material, piece count, color/size/variant and handling details. Do not invent nutrition, halal certification, reviews or product safety claims.

## Commercial mechanics and two-sided benefits

Implement configurable, contract-backed business rules:

- marketplace commission by vendor/category/agreement;
- affiliate click/conversion attribution and reconciliation;
- optional promoted placement with clear sponsored labeling;
- seller tools such as inventory sync, catalogue import, order acceptance, analytics and settlement reports;
- vendor dashboard showing attributed sales, orders, commission, returns, payouts and sync health;
- customer benefits such as accurate stock, local availability, transparent delivery promises and comparison only where price/variant/unit/coverage are comparable.

Persist financial calculations in a ledger. Do not use a hardcoded commission percentage across screens. Define how refunds, cancellation, taxes, discounts, delivery fees and payment gateway costs affect commission and payable. Reconcile payout records to payment and order data.

## Security requirements

- Use Cloud Functions and least-privilege service accounts for outbound APIs.
- Keep provider secrets in Secret Manager; grant access only to the functions that need them.
- Verify a trusted admin custom claim or an existing equivalent trusted admin allowlist in callable functions.
- Deny all client writes to vendor integration config, raw sync items, sync runs and request queues.
- Scope vendor users to their own integration status and products only.
- Protect existing products/order rules; do not weaken the current rules to make sync work.
- Apply App Check, rate limits, webhook signatures/replay protection, audit trail, retention limits and data minimization.
- Validate all provider URLs to prevent SSRF. Never accept arbitrary user-supplied URLs in backend fetches without a reviewed allowlist/domain policy.

## Testing requirements

Create tests for:
- WooCommerce and Shopify fixture normalization;
- paginated catalogs, empty catalogs, missing SKUs, duplicate IDs, variants, missing images, bad prices and rate limits;
- empty/partial feeds, incorrect source categories, concurrent scheduled/manual runs and duplicate Firestore trigger delivery;
- timeout, 401/403, 429, 5xx and invalid JSON;
- retry idempotency and duplicate webhook delivery;
- missing/truncated feed not causing mass unpublishing;
- credentials never included in logs/client data;
- admin custom claim enforcement;
- publication gate blocks catalog-only/affiliate or not-ready vendors;
- stock authority never overwritten by the wrong source;
- stale products and source removal handling;
- cross-tenant Firestore Rules;
- live UI updates and error states;
- vendor order creation, cancellation, inventory reservation and webhook confirmation when those adapters become available;
- settlement/refund/commission ledger correctness.

Use Firebase Emulator Suite plus the vendor's official sandbox. Do not make live purchases during tests. Add reconciliation and rollback tests before production.

## Required deliverables

1. Source code changes in the existing project rather than a replacement app.
2. Flutter vendor integration repository, admin screen, status/history streams and secure manual sync action.
3. Server connector adapters and sync job functions.
4. Updated source metadata models and compatibility tests.
5. Firestore Rules additions and indexes merged into the existing project.
6. Secret Manager/IAM/App Check setup instructions.
7. Vendor integration onboarding checklist and example configuration without any real secret values.
8. A legacy-demo-product migration plan and dry-run script.
9. Automated tests and commands/results.
10. Vendor partnership target list with official docs, actual access requirements and clear distinction between verified API access and contact-needed partnerships.
11. A production readiness matrix showing connected, tested in sandbox, waiting for vendor credentials, waiting for agreement, staged-only, and fully published statuses.

## Begin now

Audit the full repository, including the root `pubspec.yaml`, `firebase.json`, Firestore rules/indexes, existing Firebase Functions and tests. Review the additive patch and do not overwrite existing backend functions. Add the missing `cloud_functions` FlutterFire dependency if it is not already present.

Implement one authorized pilot vendor end-to-end before scaling. A pilot is complete only when catalog updates are seen in the app, a real stock/price check is made at checkout, an order reaches the vendor's approved fulfilment workflow, cancellations and order status reconcile, commission is calculated from the contract, and all test evidence is recorded. If vendor credentials or permissions are absent, finish the interface and staging workflow but label that vendor as not connected.
