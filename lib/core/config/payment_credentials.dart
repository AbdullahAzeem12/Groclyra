import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PAYMENT GATEWAY CREDENTIALS
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Upgraded (security): real secrets are NO LONGER stored in this repository.
/// They are injected at build time via `--dart-define`, so the published APK
/// is the only place they exist (and even there, they are stripped of
/// version-control history).
///
/// HOW TO PASS YOUR REAL CREDENTIALS (local dev / release build):
///
/// flutter build apk \
///   --dart-define=JAZZCASH_MERCHANT_ID=MC-XXXXXXX \
///   --dart-define=JAZZCASH_PASSWORD=xxxxxxxxxx \
///   --dart-define=JAZZCASH_INTEGRITY_SALT=xxxxxxxxxxxxxxxx \
///   --dart-define=EASYPAISA_STORE_ID=xxxx \
///   --dart-define=EASYPAISA_HASH_KEY=xxxxxxxxxxxxxxxx \
///   --dart-define=PAYMENT_SANDBOX=true
///
/// WHERE TO GET EACH VALUE:
///  • JazzCash Merchant Portal → after merchant onboarding you receive
///    Merchant ID + Password + Integrity Salt (Sandbox and Live are separate
///    portals: sandbox.jazzcash.com.pk / payments.jazzcash.com.pk).
///  • Easypaisa Merchant Portal → "Your Store ID" and "Hash Key" (exactly 16
///    characters — AES-128 AES key length requirement).
///  • PAYMENT_SANDBOX toggles sandbox vs production endpoints for BOTH
///    gateways. Flip it to `false` only after live onboarding is complete.
///
/// When values are not provided, the service runs in UNITIALIZED state and
/// checkout gracefully falls back to Cash-on-Delivery with an explanatory
/// message instead of silently pretending the gateway worked (the previous
/// placeholder-string behaviour).
class PaymentCredentials {
  const PaymentCredentials._();

  // ── JAZZCASH ─────────────────────────────────────────────────────────────
  static const jazzCashMerchantId = String.fromEnvironment(
    'JAZZCASH_MERCHANT_ID',
    defaultValue: '',
  );
  static const jazzCashPassword = String.fromEnvironment(
    'JAZZCASH_PASSWORD',
    defaultValue: '',
  );
  static const jazzCashIntegritySalt = String.fromEnvironment(
    'JAZZCASH_INTEGRITY_SALT',
    defaultValue: '',
  );

  // ── EASYPAISA ────────────────────────────────────────────────────────────
  static const easypaisaStoreId = String.fromEnvironment(
    'EASYPAISA_STORE_ID',
    defaultValue: '',
  );
  static const easypaisaHashKey = String.fromEnvironment(
    'EASYPAISA_HASH_KEY',
    defaultValue: '',
  );

  // ── PAYFAST (gopayfast.com — State Bank authorised, easiest onboarding) ──
  // Only TWO credentials: Merchant ID + Secured Key. The hosted checkout page
  // then automatically offers cards (PayPak/Visa/Master), Google Pay, bank
  // accounts AND wallets (JazzCash / Easypaisa / UPaisa) — one integration
  // covers everything. PayFast emails you the exact REST API base URL with
  // your credential pack; set it via PAYFAST_API_URL.
  static const payFastMerchantId = String.fromEnvironment(
    'PAYFAST_MERCHANT_ID',
    defaultValue: '',
  );
  static const payFastMerchantName = String.fromEnvironment(
    'PAYFAST_MERCHANT_NAME',
    defaultValue: 'Groclyra',
  );
  static const payFastSecuredKey = String.fromEnvironment(
    'PAYFAST_SECURED_KEY',
    defaultValue: '',
  );

  /// Full REST base (must end with a '/'), e.g.
  /// https://ipguat.apps.net.pk/Ecommerce/api/1/  — printed in PayFast's
  /// welcome pack. Empty → well-known defaults per mode.
  static const payFastApiUrl = String.fromEnvironment(
    'PAYFAST_API_URL',
    defaultValue: '',
  );

  /// true  → sandbox endpoints (default — safe)
  /// false → production endpoints
  static const bool isSandbox =
      bool.fromEnvironment('PAYMENT_SANDBOX', defaultValue: true);

  // ── READINESS CHECKS ─────────────────────────────────────────────────────

  static bool get payFastConfigured =>
      payFastMerchantId.isNotEmpty && payFastSecuredKey.isNotEmpty;

  static bool get jazzCashConfigured =>
      jazzCashMerchantId !=
          'YOUR_JAZZCASH_MERCHANT_ID' && // legacy placeholder safety net
      jazzCashMerchantId.isNotEmpty &&
      jazzCashPassword.isNotEmpty &&
      jazzCashIntegritySalt.length >= 8;

  static bool get easypaisaConfigured =>
      easypaisaStoreId.isNotEmpty &&
      easypaisaHashKey.length == 16; // AES-128 key length

  /// Human-readable hint shown to the operator during development when a
  /// gateway has not been configured yet.
  static String get jazzCashSetupHint => kDebugMode
      ? 'JazzCash credentials missing — build with '
          '--dart-define=JAZZCASH_MERCHANT_ID=… '
          '--dart-define=JAZZCASH_PASSWORD=… '
          '--dart-define=JAZZCASH_INTEGRITY_SALT=…'
      : 'JazzCash is temporarily unavailable. '
          'Please try another payment method.';

  static String get easypaisaSetupHint => kDebugMode
      ? 'Easypaisa credentials missing — build with '
          '--dart-define=EASYPAISA_STORE_ID=… '
          '--dart-define=EASYPAISA_HASH_KEY=…'
      : 'Easypaisa is temporarily unavailable. '
          'Please try another payment method.';
}
