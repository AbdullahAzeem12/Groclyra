# Groclyra — Advanced Upgrade Implementation Plan

> Generated from a full codebase audit (all 130 Dart files, Firestore rules, indexes, Android config, tests).
> **Guiding rule: additive only.** No existing logic, screens, collections, or flows are removed.
> Every phase below extends the app; existing code paths keep working.
>
> ## EXECUTION STATUS (@ 2026-10-16)
> - ✅ **Phase 0** — DONE. Cart persistence bug fixed; rider earnings wired; seller stats query fixed; delivery tasks carry real seller data + coordinates; POD OTP prefill debug-gated; product not-found state; indexes deployed via firebase.json; maps/payment timeout hygiene; escaped `\$e` bugs fixed.
> - ✅ **Phase 1 (1.1–1.9)** — DONE. Hardened firewall rules (role escalation, forged orders, KYC self-approval, PII, product re-approval, delivery-task lifecycle); transactional task claiming; `AppSecurityService` seam; `SecurePaymentGateway` user stamping; `validateStrongPassword`; all three demo backdoors debug-gated.
> - ✅ **Phase 1B** — DONE (in-app). `features/notifications/` module (entity, repository, dispatcher hooked into order placement / delivery status / KYC review), real-time notification centre bottom sheet + badge bell on all four role dashboards. FCM push = remaining optional step.
> - ✅ **Phase 1.7 PAYMENTS + FIRESTORE DEPLOY: DONE (proper end-to-end build).** `firestore.rules` + composite indexes **live via `firebase deploy --only firestore:rules,firestore:indexes`** (rules engine required a `riderIds` array denormalisation + removal of the invalid single-field `categories` index entry).
> - ✅ **PAYMENTS COMPLETED:** secrets moved out of source into `lib/core/config/payment_credentials.dart` (injected via `--dart-define`, never committed); the WRONG Easypaisa "SHA-256 pipe-hash" replaced with the official **AES-128-ECB/PKCS5 `merchantHashedReq`** (the actual reason Easypaisa was stubbed); JazzCash signed per the official v4.2 hashing scheme — **verified against the vendor's own published test vector** in unit tests; enforced lifecycle `pending → awaiting_verification → paid/failed` on `orders.paymentStatus` where `paid` is written ONLY after gateway confirmation (wallet-debit sync result, hosted-checkout return-URL `pp_SecureHash` verification, or Easypaisa Transaction-Status-Inquiry polling); new hosted-checkout WebView (auto-submitting form, hash-verified redirect interception, MPIN-push resume handling); `creditDebitCard` checkout wired through JazzCash hosted checkout; transaction audit mirror in `paymentTransactions`. **Remaining operator step:** build with real merchant creds via `--dart-define` (see `payment_credentials.dart` header) + register the return/callback URLs in both merchant portals.
> - ✅ **PAYMENTS (v2 — PayFast primary): DONE.** After operator feedback that JazzCash/Easypaisa merchant onboarding is too hard, **PayFast (gopayfast.com — State Bank authorised, only 2 credentials: Merchant ID + Secured Key)** is now the primary online method: one hosted checkout page automatically offers cards (PayPak/Visa/MC), Google Pay, bank accounts AND wallets (JazzCash/Easypaisa/UPaisa — it aggregates them, no separate accounts needed). New `lib/core/services/payfast_gateway.dart`: access-token API → MD5(merchant:name:amount:order) signed form → hosted page → redirect signature re-verified → **authoritative `transaction/basket_id` inquiry settles the order** (redirect alone can never mark paid — fail-closed tests prove it). Checkout gained a "Pay Online (Recommended)" method + routes; secrets via `--dart-define=PAYFAST_MERCHANT_ID/SECURED_KEY/API_URL`. JazzCash/Easypaisa direct integrations remain fully wired but dormant behind their own d defines (additive, revisit later).
> - ✅ Test suite: **47/47 passing** (34 core + 8 Jazz/Easy gateway + 5 PayFast). `flutter analyze` 0 errors (6 pre-existing info lints). Admin dashboard layout overflow bugs fixed; still-failing playbook test remediated with scroll + finite pumps.
> - 🔜 Next: Phases 2–6 per table below.

---

## AUDIT SUMMARY — What Exists Today

| Role | Implemented |
|---|---|
| **Auth** | Email/password, Google, phone OTP (login modal), role isolation (customer/seller/rider/admin), account pending approval w/ live Firestore stream, password reset, email verification, owner backdoor (`kheroali66@gmail.com`) |
| **Customer** | Home (real Firestore streams), categories, search (client-side), product details, cart (memory only), checkout (COD/JazzCash/Easypaisa sandbox), orders history, *simulated* live tracking, profile |
| **Seller** | Dashboard KPIs, product list, add-product wizard (auto-approved), inventory management, orders fulfillment, POS "Foodics" fake integration, profile |
| **Rider** | Dashboard w/ real GPS map, delivery queue, turn-by-turn navigation (OSRM), OTP POD (prefilled), COD ledger (dead-zero), duty toggle (local only) |
| **Admin** | Live analytics, seller KYC, rider KYC (best built), catalog moderation, health telemetry, audit logs |
| **Backend** | Firestore direct from client, seed-on-boot, 13 composite indexes (not deployed), rules with critical vulnerabilities |

---

## CRITICAL GAPS FOUND (ranked)

1. 🔴 **Security holes** — `users/{uid}` self-update allows `role: "admin"` self-escalation; forged orders (`create: any authenticated`); sellers/riders can self-approve KYC & flip `isApproved`; PII public; no rules on `serviceHealth`/`paymentTransactions`; commission inconsistency (8% in repo vs 10% in UI).
2. 🔴 **Payments are a stub** — placeholder credentials, HMAC secret in client, status written as `paid` before verification, no callback/IPN loop, no card-method handler.
3. 🔴 **Rider flow incomplete** — no Accept button anywhere (`accepted → pickedUp → inTransit` are dead code); no race-safe task claiming; earnings stream exists but never wired (dashboard shows Rs. 0 forever); POD signature/GPS/photo are fakes; task docs lack customer lat/lng so navigation snaps to Karachi center.
4. 🔴 **Cart not persisted** — `localCacheServiceProvider` is a bug that always returns `null`; cart dies on restart.
5. 🔴 **Tracking screen simulated** — streams exist but the screen reads snapshot state; hardcoded timeline; fake map.
6. 🟠 **Images as base64 in Firestore docs** — 1 MiB doc limit risk, huge reads/writes; `firebase_storage` in pubspec but never imported.
7. 🟠 **No notifications** — no FCM at all; no new-order/slash-assignment/approval alerts.
8. 🟠 **No order cancellation / refund / reviews / wishlist persistence / address book** — customer-side essentials missing.
9. 🟠 **Seller analytics fragile** — `arrayContains` with partial map query likely never matches; payout/commission inline math, never persisted; handover "Scan" is a placeholder; rejection reason not persisted.
10. 🟠 **Admin** — no customer management (tile is `onTap: null`), `/admin/orders` route declared but unimplemented, commission edit fake, analytics loads full collections into memory.
11. 🟡 **iOS/macOS Firebase configs are placeholders**; `applicationId = com.example.myapplication`; release signs with debug key; `firebase.json` missing `indexes` entry; tests: 3 fail (admin test doesn't compile).

---

# PHASE 0 — FIX BROKEN FOUNDATIONS (no behavior change, everything keeps working)

**Goal: nothing removed — dislodged bugs patched in place.**

| # | Task | File(s) |
|---|---|---|
| 0.1 | Fix `localCacheServiceProvider` to actually construct `LocalCacheService` → cart, wishlist, offline queue all activate | `cart_repository.dart:84–88` |
| 0.2 | Wire `riderEarningsStreamProvider` into `RiderController` (fill `todayEarnings`, `codCashInHand`) | `rider_controller.dart` |
| 0.3 | Fix seller stats query `arrayContains` on partial map → use a denormalized `subOrderIds`/`sellerIds` array field on orders (written *in addition* to existing subOrders, not replacing) | `order_repository.dart`, `seller_repository.dart` |
| 0.4 | Write `customerLat/customerLng/sellerLat/sellerLng` onto `deliveryTasks` at creation (previous fields preserved) | `order_repository.dart` |
| 0.5 | Remove prefill `'4829'` demo OTP; read real OTP from task doc | `pod_verification_screen.dart` |
| 0.6 | Fix product-lookup fallback (unknown id → not-found UI instead of first product) | `product_details_screen.dart` |
| 0.7 | Fix `firebase.json` to deploy `firestore.indexes.json`; add rules for `serviceHealth` + `paymentTransactions` | Firebase configs |
| 0.8 | Fix failing tests (admin test compile errors: `unavailable()` vs `empty()`, missing `clearMessages`, label mismatch) — tests only, no app change | `test/admin_rider_kyc_test.dart` |
| 0.9 | Fix escaped `\$e` debugPrint bugs; use `AppConfig.timeout*` constants | `maps_service.dart`, `rider_location_picker_screen.dart` |

---

# PHASE 1 — SECURITY HARDENING + SERVER TRUST (biggest risk reduction)

**Goal: Firestore can no longer be abused; roles approved only by admins. All app code keeps working because we keep the same shape of data.**

| # | Task | Approach |
|---|---|---|
| 1.1 | Rewrite `firestore.rules` additively, field-level validation: users can update own doc but **cannot modify `role`, `accountStatus`, `isKycApproved`, `isVerified`** (those require admin); enroll users so `isOwner()` checks a server-managed allowlist in `config/admins` doc instead of trusting doc field | New rules version, same collection names |
| 1.2 | Orders: create requires `request.resource.data.customerId == request.auth.uid`; update restricted per-role field sets (customer can only cancel-within-window, rider only their assigned task fields, seller only their subOrder status) | Rules only |
| 1.3 | `deliveryTasks`: create only (admin/system or seller+their order); riders claim via transaction guarded by `status == 'available'` → this also fixes the race-claim bug | Rules + small repo change |
| 1.4 | Restrict PII: `sellers`/`riders` readable only by owner + admin (customer reads stay on `users` docs which don't carry CNIC/license) | Rules only |
| 1.5 | Products: sellers can no longer set/flip `isApproved` — remove that one diff-key in their mutation guard; admin-only moderation stays | Rules only |
| 1.6 | Add Cloud-Functions-style Callable shim interface (`AppSecurityService`) so future Functions (payment verify, role claims) can drop in without app refactor | New service class |
| 1.7 | Remove client-side signing from payments path *structure* (keep working sandbox flow): extract `SecurePaymentGateway` with server-proxy hook; add `paymentStatus` field (`initializing → awaitingVerification → paid/failed`) alongside existing `OrderStatus` so nothing breaks | `payment_service.dart` additive classes |
| 1.8 | Password policy: keep `validatePassword` (existing behavior retained via `validatePassword`), add `validateStrongPassword` used only in registration + change of password | `validator_utils.dart` |
| 1.9 | Remove hardcoded admin backdoor and 5-tap admin unlock **only if user approves** (it's demo access) — default: keep behind debug flag | `auth_repository.dart`, `registration_screen.dart` |

---

# PHASE 1B — NOTIFICATIONS & LIVE PLATFORM AWARENESS (new capability)

**New feature: Firebase Cloud Messaging everywhere, additive to all roles.**

| # | Feature | Files |
|---|---|---|
| 1B.1 | Add `firebase_messaging` + `flutter_local_notifications`, `POST_NOTIFICATIONS` permission | pubspec + AndroidManifest |
| 1B.2 | Token registry: save FCM token per device to `users/{uid}.devices[]` (new field, additive) | auth flow |
| 1B.3 | In-app realtime notification center: `notifications` collection streams, shown on all 4 shells (badge on bell icon; customer gets order updates; seller gets new orders; rider gets new assignment + COD unlock; admin gets KYC submissions) | ★ new `features/notifications/` module + all shells |
| 1B.4 | Firestore-trigger-style local watcher: `NotificationDispatcher` service writes events from within existing repo methods *after* their current logic completes (no code-path replacement) | repo hooks |

---

# PHASE 2 — CUSTOMER EXPERIENCE ADVANCED FEATURES

All cart/checkout logic preserved; features added as optional layers.

| # | Feature | Details |
|---|---|---|
| 2.1 | **Persistent cart** (Phase 0 fix realized): cart repo writes through LocalCacheService, plus optional Firestore `carts/{uid}` doc for cross-device sync (merge on login; local cart wins on conflict) | cart module |
| 2.2 | **Address book**: new `addresses` subcollection per user; CRUD + default flag; checkout now lists all addresses (replace the no-op Change button); auto-fill from GPS via map picker | new screens + models |
| 2.3 | **Wishlist (real)**: `wishlists/{uid}/items/{productId}` real Firestore-backed; heart state streams; wishlist screen wired to profile tile; home product card snaps to wishlist | catalogs + profile |
| 2.4 | **Product reviews & ratings**: new `reviews` collection, rating mutation writes `reviewCount`+`ratingAvg` on the existing product doc (the existing Rating row becomes live); selling screen existing stats stay intact | reviews module |
| 2.5 | **Server-authoritative coupons**: new `coupons` collection with validation engine (expiry, usage limits, per-user, min order, % vs fixed); cart controller's hardcoded vouchers now backed/priortized through the same API (existing codes seeded into Firestore too so they keep working) | cart + coupons |
| 2.6 | **Order cancellation + refund request**: customer-cancel allowed only pre-`sellerProcessing`; refund request doc created, admin seller flows untouched; status-enum already covers `cancelled*` | order module |
| 2.7 | **Real live tracking**: location of assignment from rider's `users/{uid}.lastLocation` (already streaming when navigation screen is open — routed here with correct lat/lng from Phase 0.4); timeline driven by actual `OrderStatus` instead of hardcoded steps | tracking screen |
| 2.8 | **Reorder button + order filters** in history (status tabs, date distribution), receipt summary sheet | history screen |
| 2.9 | **Search v2**: debounced suggestions, recent searches (prefs), price/rating filter chips, server-side `orderBy` with pagination (`startAfter`), supported on all 4 category pillars (currently grocery/crockery only) | search screen + repository |
| 2.10 | **Home upgrades**: real flash-deal countdown (from product doc `flashDealEndsAt`), personalized "Just for You" (repeat purchases: `yikes, based on order history`), working address header + notification bell | home screen |
| 2.11 | **Delivery scheduling**: choose date + slot at checkout stored as new optional fields | checkout order |

---

# PHASE 3 — SELLER ADVANCED FEATURES

| # | Feature | Details |
|---|---|---|
| 3.1 | **Commission & payout ledger**: `sellerLedger/{sellerId}/entries/{entryId}` docs written by order events (sale, commission, payout); commission rate configurable per seller in Firestore (defaults to current 10% so UI keeps showing same numbers); dashboard payout card reads real computed balance | seller repo/module |
| 3.2 | **Real approve flow**: KYC-approved flag checked before `isApproved:true` (removes auto-approve bypass without removing field) | add-product wizard |
| 3.3 | **Sales analytics screen**: revenue per day chart (fl_chart), top products, orders by status, profit vs commission — computed inside `streamSellerStats` (fixed in 0.3) | ★ new analytics screen |
| 3.4 | **Order operations**: persist rejection reason (new field), QR handover scan using `mobile_scanner` (matches rider OTP/tokens), packing-slip print sheet, batch status actions | fulfillment screen |
| 3.5 | **Inventory pro**: configurable low-stock threshold per seller, CSV export (local), expiry/batch tracking fields for dairy, bulk restock via single multi-set document batch (`WriteBatch`) instead of sequential loops | inventory screen |
| 3.6 | **Variant editor**: allow sellers to add/edit multiple variants at product-edit (wizard currently only writes one base variant); barcode + SKU edit | wizard |
| 3.7 | **POS truth**: connection state persisted to `sellerProfiles.posConnections[]`; Foodics connector keeps fake catalog but through a `PosAdapter` interface with a real-HTTP stub server endpoint config, Square/Toast stubs via same interface | catalog integration |
| 3.8 | **Images → Firebase Storage**: default upload to Storage w/ public CDN URL; base64 path retained as a fallback flag so old data still renders | storage_service |
| 3.9 | **Draft saving for the wizard** (auto-save per step to `productDrafts` col) | wizard |

---

# PHASE 4 — RIDER ADVANCED FEATURES

| # | Feature | Details |
|---|---|---|
| 4.1 | **Duty & presence**: real online/offline backed by `riderProfiles.isOnline` + heartbeat timestamp; assignment only considers online riders | rider shell/dashboard |
| 4.2 | **Task claiming lifecycle made real**: Accept, Arrived-at-pickup, Picked-up, In-Transit, Delivered buttons in queue + navigation screens using the transactional claim (fixing race issue); release-task option with violation meter | queue/nav screens |
| 4.3 | **Real POD**: hand-drawn signature pad (digitally captured → base64 to task doc), actual photo capture with camera, real GPS stamp from device (fake stamp removed, everything else preserved) | POD screen |
| 4.4 | **COD truth**: COD amount confirmed & deducted from task; COD ledger shows real collections (0.3) and generates a real remittance record `codDeposits/{id}` with QR payload from real data | COD screen |
| 4.5 | **Ratings & performance**: customers rate riders after delivery; rider sees rating, acceptance rate, penalties on dashboard | new fields + screen |
| 4.6 | **Multi-stop batch route**: OSRM waypoints optimization when rider has multiple tasks grouped into a batch → stop optimizing in navigation screen | navigation |
| 4.7 | **Delivery history & weekly statement screen** | rider shell |
| 4.8 | (Optional, needs extra native setup) background GPS via `flutter_background_geolocation`-style foreground service with user consent | Android service |

---

# PHASE 5 — ADMIN ADVANCED FEATURES

| # | Feature | Details |
|---|---|---|
| 5.1 | **Customer management**: replaces dead tile → browse/search customers, view order history, suspend/reinstate accounts (uses account-status entity already existing) | ★ new screen |
| 5.2 | **Live order monitor** at existing dead route `/admin/orders`: all orders across state machine, filters, reassign riders, mark delivered, refund overrides | ★ new screen (route exists) |
| 5.3 | **Dispute resolution center**: open disputes from refund requests (2.6) + failed deliveries; conversation threads + resolution verdict | ★ new module |
| 5.4 | **Finance module**: platform GMV, commission actually collected (vs hardcoded 8% today — unified 10% default pulled from `config/platform`), seller payout management (approve/reject withdraw requests), refunds ledger | ★ new screen |
| 5.5 | **Promotions & banners management**: CRUD banners shown on home (home currently hardcoded — switched to stream when banners exist, hardcoded banners kept as fallback); coupons CRUD for Phase 2.5 | ★ new screens |
| 5.6 | **Support tickets**: READ FAQ + customer tickets, reply threads | ★ new module |
| 5.7 | **Audit trail browser**: filterable, paged, exportable logs (recent 30 feed exists) | health screen ext |
| 5.8 | **Analytics perf**: aggregation architecture — replace full-collection reads with KV counters + scheduled background aggregation via a pluggable `AnalyticsAggregator` (keep current real-time fallback) | admin repo |

---

# PHASE 6 — ENGINEERING QUALITY (cross-cutting)

| # | Task |
|---|---|
| 6.1 | Global error handling: `FlutterError.onError` + `PlatformDispatcher.onError`, boot-guard screen when Firebase fails, Crashlytics (or `debugPrint` gate) |
| 6.2 | Firestore offline persistence configured explicitly + `connectivity_plus` triggers draining offline mutation queue (scaffold exists since Phase 0.1) |
| 6.3 | Real Firebase Storage image pipeline (3.8) + remove dead deps (`sqflite`, `path_provider`, `package_info_plus`) — or adopt sqflite as proper cart/review cache if user prefers offline-first SQLite |
| 6.4 | `NetworkImage` fade-in for remote images; remove unused `cached_network_image` import |
| 6.5 | Riverpod modernization stamps: keep `StateNotifier` (existing) but wrap new modules with v2 `Notifier` for consistency guideline going forward |
| 6.6 | Localization framework scaffold (`l10n.yaml` + delegate) with English base |
| 6.7 | Test expansion: repo fakes for Order/Seller/Rider repos, security rules unit tests via `@firebase/rules-unit-testing` equivalents, restore 3 broken tests, add golden tests for shells |
| 6.8 | CI-ready tooling: `flutter analyze` clean, `flutter test` green |
| 6.9 | Release hygiene: real applicationId, release signing config, iOS Firebase options via `flutterfire configure` |

---

# EXECUTION ORDER & DEPENDENCIES

```
Phase 0 ──► Phase 1 ──► Phase 1B ──► Phases 2/3/4 (parallelizable) ──► Phase 5 ──► Phase 6
   │            │
   │            └── payment verification rule work should ship with a
   │                server-side callback (user decision required: do we
   │                ship sandbox-server or Firebase Functions?)
   └── 0.1 cart cache fix, 0.2 earnings wiring are instant wins — ship first
```

## File-impact map (new modules only — zero deletions)
```
lib/features/notifications/        (new, Phase 1B)
lib/features/customer/addresses/   (new, Phase 2.2)
lib/features/customer/wishlist/    (new, Phase 2.3)
lib/features/customer/reviews/     (new, Phase 2.4)
lib/features/coupons/              (new, Phase 2.5)
lib/features/seller/analytics/     (new, Phase 3.3)
lib/features/seller/ledger/        (new, Phase 3.1)
lib/features/rider/ratings/        (new, Phase 4.5)
lib/features/admin/orders/         (new, Phase 5.2)
lib/features/admin/disputes/       (new, Phase 5.3)
lib/features/admin/finance/        (new, Phase 5.4)
lib/features/admin/promotions/     (new, Phase 5.5)
lib/features/admin/support/        (new, Phase 5.6)
```

## New Firestore collections (all previously unused — additive)
`notifications`, `carts`, `addresses`, `wishlists`, `reviews`, `coupons`, `sellerLedger`, `codDeposits`, `disputes`, `tickets`, `banners`, `productDrafts`, `counters` (+ hardened field rules for every existing collection)
