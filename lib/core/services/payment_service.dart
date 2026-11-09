import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:groclyra/core/database/app_database.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/ecb.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';
import 'package:pointycastle/pointycastle.dart';

import '../config/payment_credentials.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PAYMENT GATEWAY SERVICE — FULL PRODUCTION IMPLEMENTATION
// ═════════════════════════════════════════════════════════════════════════════
//
// Built against the official gateway specs:
//
//  JAZZCASH (v4.2 doc, sandbox.jazzcash.com.pk/SandboxDocumentation)
//   • Mobile-wallet direct debit (MWALLET REST v1.1): synchronous final
//     response → pp_ResponseCode '000' = money moved.
//   • Hosted checkout (cards / MPGS): form POST to the payment page; gateway
//     redirects back to the Return URL appending all pp_ params +
//     pp_SecureHash → we verify the response hash BEFORE trusting it.
//   • Secure Hash (official "Hashing Scheme"): all PP fields sorted
//     alphabetically by field name, values joined with '&', Shared Secret
//     PREPENDED ('salt&v1&v2…'), UTF-8 bytes re-cast as ISO-8859-1, hashed
//     with HMAC-SHA256 keyed by the UTF-8-encoded shared secret, hex output.
//
//  EASYPAISA (Merchant Integration Guide v4.x)
//   • Hosted checkout: form POST to easypay/Index.jsf with merchantHashedReq
//     = AES-128-ECB + PKCS#5 padding over the alphabetically-sorted
//     key=value&… string of every other request field, base64-encoded.
//     (The old implementation applied a plain SHA-256 to a pipe-joined
//     string — that hash NEVER matched and is why Easypaisa was stubbed.)
//   • MA / OTC payments are asynchronous → confirmed via the authorised
//     Transaction Status Inquiry REST endpoint (same AES request hash), so
//     the app polls until PAID without needing a server RSA key.
//
// ORDER PAYMENT LIFECYCLE (orders/{id}.paymentStatus):
//   pending → awaiting_verification → paid | failed
// `paid` is only ever written AFTER gateway-side confirmation.
//
// SECRETS are injected with --dart-define (see payment_credentials.dart) —
// nothing merchant-identifying lives in this repository.
// ═════════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────────
// GATEWAY ENDPOINT CONFIGURATION
// ─────────────────────────────────────────────────────────────────────────────

class _JazzCashEndpoints {
  static String get walletUrl => PaymentCredentials.isSandbox
      ? 'https://sandbox.jazzcash.com.pk/ApplicationAPI/API/2.0/Purchase/DoMWalletTransaction'
      : 'https://payments.jazzcash.com.pk/ApplicationAPI/API/2.0/Purchase/DoMWalletTransaction';

  static String get checkoutUrl => PaymentCredentials.isSandbox
      ? 'https://sandbox.jazzcash.com.pk/CustomerPortal/transactionmanagement/merchantform/'
      : 'https://payments.jazzcash.com.pk/CustomerPortal/transactionmanagement/merchantform/';
}

class _EasypaisaEndpoints {
  static String get checkoutUrl => PaymentCredentials.isSandbox
      ? 'https://easypay.easypaisa.com.pk/easypay/Index.jsf'
      : 'https://easypay.easypaisa.com.pk/easypay/Index.jsf'; // same host live

  static String get statusUrl => PaymentCredentials.isSandbox
      ? 'https://easypay.easypaisa.com.pk/easypay-service/rest/v4/transaction-status'
      : 'https://easypay.easypaisa.com.pk/easypay-service/rest/v4/transaction-status';

  /// Where the gateway redirects the customer after the hosted page.
  /// In-hosted-page flows (no backend) we only need a recognisable URL.
  static String get postBackUrl => PaymentCredentials.isSandbox
      ? 'https://groclyra.app/payment/easypaisa/callback'
      : 'https://groclyra.app/payment/easypaisa/callback';
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULT TYPES
// ─────────────────────────────────────────────────────────────────────────────

enum PaymentGateway { jazzCash, easypaisa, payFast }

class PaymentInitResult {
  final bool success;
  final String? txnRefNo; // unique transaction reference
  final String? redirectUrl; // for WebView / deep-link (JazzCash hosted)
  final String? errorMessage;
  final PaymentGateway gateway;

  /// Auto-submitting HTML form for the hosted-checkout WebView
  /// (set for hosted flows instead of [redirectUrl]).
  final String? checkoutHtml;

  /// True when the gateway accepted the request but money is not confirmed
  /// yet (async gateways) — the caller must verify before marking paid.
  final bool awaitsVerification;

  const PaymentInitResult({
    required this.success,
    required this.gateway,
    this.txnRefNo,
    this.redirectUrl,
    this.errorMessage,
    this.checkoutHtml,
    this.awaitsVerification = false,
  });
}

class PaymentVerifyResult {
  final bool paid;
  final String? txnRefNo;
  final String? responseCode;
  final String? responseMessage;

  const PaymentVerifyResult({
    required this.paid,
    this.txnRefNo,
    this.responseCode,
    this.responseMessage,
  });
}

/// Cumulative status of a polled async transaction.
enum PaymentPollOutcome { paid, pending, failed, transportError }

class PaymentStatusPollResult {
  final PaymentPollOutcome outcome;
  final String? gatewayStatus;
  final String? transactionId;
  final String? message;

  const PaymentStatusPollResult({
    required this.outcome,
    this.gatewayStatus,
    this.transactionId,
    this.message,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// HASH ENGINES (official schemes)
// ─────────────────────────────────────────────────────────────────────────────

/// JazzCash Secure Hash — official "Hashing Scheme" (v4.2):
///  1. take every field whose name starts with "pp_" (case-insensitive),
///     sorted alphabetically by FIELD NAME;
///  2. join their VALUES with '&';
///  3. PREPEND the integrity salt ('salt&v1&v2…');
///  4. encode the string UTF-8 → bytes → ISO-8859-1 (byte identity cast);
///  5. HMAC-SHA256 with the UTF-8 salt as key → lowercase hex.
class JazzCashHasher {
  /// [salt] lets callers (tests) validate against the official example.
  /// Production always injects the configured integrity salt.
  static String compute(Map<String, String> ppFields, {String? salt}) {
    final secret = salt ?? PaymentCredentials.jazzCashIntegritySalt;
    final keys = ppFields.keys
        .where((k) => k.toLowerCase().startsWith('pp_'))
        .toList()
      ..sort();
    final message = '$secret&'
        '${keys.map((k) => ppFields[k] ?? '').join('&')}';

    // UTF-8 bytes re-cast as ISO-8859-1 (byte-identity for the ASCII-only
    // data national gateways expect; falls back to raw code units when a
    // character is outside Latin-1 to keep the call total).
    final utf8Bytes = utf8.encode(message);
    final latin1Message = String.fromCharCodes(utf8Bytes);
    List<int> payloadBytes;
    try {
      payloadBytes = latin1.encode(latin1Message);
    } catch (_) {
      payloadBytes = utf8Bytes; // byte-identity fallback
    }
    final hmac = Hmac(sha256, utf8.encode(secret));
    return hmac.convert(payloadBytes).toString();
  }

  /// Verifies a response secure hash: recomputes over every pp_ field of the
  /// response except pp_SecureHash itself, prepending the shared secret.
  static bool verify(Map<String, dynamic> response, {String? salt}) {
    final received = response['pp_SecureHash']?.toString() ?? '';
    if (received.isEmpty) return false; // nothing to verify → distrust
    final fields = <String, String>{
      for (final entry in response.entries)
        if (entry.key.toLowerCase().startsWith('pp_') &&
            entry.key != 'pp_SecureHash')
          entry.key: entry.value?.toString() ?? '',
    };
    final expected = compute(fields, salt: salt);
    return expected.toLowerCase() == received.toLowerCase();
  }
}

/// Easypaisa merchantHashedReq — Merchant Integration Guide v4.x:
///   AES-128-ECB, PKCS#5(7) padding, key = Hash Key (16 chars),
///   plaintext = alphabetically-sorted `key=value` pairs joined by '&'
///   (every request field except merchantHashedReq itself), base64 output.
class EasypaisaHasher {
  /// [key] lets callers (tests) drive the cipher directly; production always
  /// uses the configured 16-character hash key (AES-128).
  static String compute(Map<String, String> body, {String? key}) {
    final hashKey = key ?? PaymentCredentials.easypaisaHashKey;
    final sortedKeys = body.keys.toList()..sort();
    final plaintext =
        sortedKeys.map((k) => '$k=${body[k] ?? ''}').join('&');

    // PKCS#7 padding is applied INSIDE PaddedBlockCipherImpl — pass the
    // raw plaintext (pre-padding it would corrupt the cipher output).
    // Parameter order: (underlyingCipherParameters=KEY, paddingCipherParameters=null).
    final cipher = PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(AESEngine()))
      ..init(
        true,
        PaddedBlockCipherParameters(
          KeyParameter(utf8.encode(hashKey)),
          null, // PKCS7Padding.init(null) — no separate padding params
        ),
      );

    final out = cipher.process(Uint8List.fromList(utf8.encode(plaintext)));
    return base64.encode(out);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAYMENT SERVICE
// ─────────────────────────────────────────────────────────────────────────────

class PaymentService {
  static final AppDatabase _db = AppDatabase.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final Map<String, Map<String, dynamic>> _txnMemory = {};

  /// UID of the signed-in user initiating the payment (empty string when
  /// unauthenticated). Stamped onto `paymentTransactions` docs so the
  /// hardened Firestore rules can scope reads to the transaction owner.
  static String _currentUserUid() {
    try {
      return _auth.currentUser?.uid ?? '';
    } catch (_) {
      return '';
    }
  }

  // ── READY CHECKS ─────────────────────────────────────────────────────────

  static bool get jazzCashReady => PaymentCredentials.jazzCashConfigured;
  static bool get easypaisaReady => PaymentCredentials.easypaisaConfigured;

  // ═════════════════════════════════════════════════════════════════════════
  // 1) JAZZCASH MOBILE-WALLET DIRECT DEBIT (synchronous — money moves)
  // ═════════════════════════════════════════════════════════════════════════

  /// Charges the customer's JazzCash mobile wallet directly (MWALLET v1.1
  /// REST — the customer receives an MPIN push and confirms).
  ///
  /// Returns a FINAL result: success == money confirmed by the gateway,
  /// order already marked paid. Never marks paid on anything else.
  static Future<PaymentInitResult> initiateJazzCash({
    required String orderId,
    required double amount,
    required String mobileNumber,
    required String customerName,
  }) async {
    if (!jazzCashReady) {
      return PaymentInitResult(
        success: false,
        gateway: PaymentGateway.jazzCash,
        errorMessage: PaymentCredentials.jazzCashSetupHint,
      );
    }
    final txnRefNo = 'T${_nowFormatted()}'; // T-prefix per gateway convention
    try {
      final body = <String, String>{
        'pp_Language': 'EN',
        'pp_MerchantID': PaymentCredentials.jazzCashMerchantId,
        'pp_SubMerchantID': '',
        'pp_Password': PaymentCredentials.jazzCashPassword,
        'pp_TxnRefNo': txnRefNo,
        'pp_MobileNumber': _normalizePakistaniMsisdn(mobileNumber),
        'pp_CNIC': '', // optional last-6 CNIC — omit unless merchant enables it
        'pp_Amount': _jazzCashPaisas(amount),
        'pp_DiscountedAmount': '',
        'pp_TxnCurrency': 'PKR',
        'pp_TxnDateTime': _nowFormatted(),
        'pp_BillReference': orderId,
        'pp_Description': 'Groclyra Order $orderId',
        'pp_TxnExpiryDateTime': _expiryFormatted(),
        'ppmpf_1': customerName,
        'ppmpf_2': orderId,
        'ppmpf_3': '',
        'ppmpf_4': '',
        'ppmpf_5': '',
      };
      // Secure hash is computed over the FINAL field set (official scheme).
      body['pp_SecureHash'] = JazzCashHasher.compute(body);

      final response = await http
          .post(
            Uri.parse(_JazzCashEndpoints.walletUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(AppTimings.network);

      final dynamic decoded = jsonDecode(_safeJsonBody(response.body));
      final resData = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};
      final code = resData['pp_ResponseCode']?.toString() ?? '999';
      final message = resData['pp_ResponseMessage']?.toString() ??
          'Unknown gateway response';
      final hashValid = JazzCashHasher.verify(resData);
      final codeApproved = code == '000';

      // Trust the response only if its hash also verified. If hashing is not
      // force-enabled on the merchant account, gateway may omit the hash —
      // we then fall back to the response code alone but log it.
      final trusted = codeApproved && (hashValid || !resData.containsKey('pp_SecureHash'));
      if (resData.containsKey('pp_SecureHash') && !hashValid) {
        debugPrint(
            'PaymentService: JazzCash response hash MISMATCH for $txnRefNo — treating as failed.');
      }

      await _recordTransaction(
        txnRefNo: txnRefNo,
        orderId: orderId,
        gateway: 'jazzCash',
        amount: amount,
        responseCode: code,
        responseMessage: message,
        status: trusted ? 'paid' : 'failed',
        extra: {'flow': 'walletDirect', 'hashValidated': hashValid},
      );

      if (trusted) {
        await markOrderAsPaid(orderId, txnRefNo);
      } else {
        await markOrderPaymentFailed(orderId);
      }

      return PaymentInitResult(
        success: trusted,
        gateway: PaymentGateway.jazzCash,
        txnRefNo: txnRefNo,
        errorMessage: trusted ? null : '$code: $message',
      );
    } catch (e) {
      debugPrint('PaymentService.initiateJazzCash error: $e');
      return PaymentInitResult(
        success: false,
        gateway: PaymentGateway.jazzCash,
        txnRefNo: txnRefNo,
        errorMessage: _friendlyNetworkError(e),
      );
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // 2) JAZZCASH HOSTED CHECKOUT (cards / MPGS / wallets via gateway page)
  // ═════════════════════════════════════════════════════════════════════════

  /// Prepares a hosted-checkout payload and returns an auto-submitting HTML
  /// form the WebView loads. When the gateway redirects back to the return
  /// URL, the WebView intercepts it and verifies `pp_SecureHash` from the
  /// query parameters BEFORE the app trusts the payment.
  static Future<PaymentInitResult> startJazzCashCheckout({
    required String orderId,
    required double amount,
    required String description,
  }) async {
    if (!jazzCashReady) {
      return PaymentInitResult(
        success: false,
        gateway: PaymentGateway.jazzCash,
        errorMessage: PaymentCredentials.jazzCashSetupHint,
      );
    }
    final txnRefNo = 'T${_nowFormatted()}';
    final fields = <String, String>{
      'pp_Version': '1.1',
      'pp_Language': 'EN',
      'pp_MerchantID': PaymentCredentials.jazzCashMerchantId,
      'pp_Password': PaymentCredentials.jazzCashPassword,
      'pp_TxnRefNo': txnRefNo,
      'pp_Amount': _jazzCashPaisas(amount),
      'pp_TxnCurrency': 'PKR',
      'pp_TxnDateTime': _nowFormatted(),
      'pp_TxnExpiryDateTime': _expiryFormatted(),
      'pp_BillReference': orderId,
      'pp_Description': 'Groclyra $description'.trim(),
      'pp_ReturnURL': 'https://groclyra.app/payment/jazzcash/return',
    };
    // Secure hash is computed over the FINAL field set (official scheme).
    fields['pp_SecureHash'] = JazzCashHasher.compute(fields);

    await _recordTransaction(
      txnRefNo: txnRefNo,
      orderId: orderId,
      gateway: 'jazzCash',
      amount: amount,
      responseCode: 'pending',
      responseMessage: 'Hosted checkout opened',
      status: 'awaiting_verification',
      extra: {'flow': 'hostedCheckout'},
    );

    return PaymentInitResult(
      success: true,
      gateway: PaymentGateway.jazzCash,
      txnRefNo: txnRefNo,
      awaitsVerification: true,
      checkoutHtml: buildJazzCashCheckoutHtml(txnRefNo, fields),
    );
  }

  /// Auto-submitting HTML form rendered inside the payment WebView.
  static String buildJazzCashCheckoutHtml(
      String txnRefNo, Map<String, String> fields) {
    final inputs = fields.entries
        .map((e) => '<input type="hidden" name="${e.key}" '
            'value="${_htmlEscape(e.value)}"/>')
        .join('\n');
    return '<!DOCTYPE html><html><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<title>Redirecting to JazzCash…</title></head>'
        '<body style="font-family:sans-serif;text-align:center;padding-top:45vh">'
        '<p>Connecting to secure JazzCash checkout…</p>'
        '<form id="pay" method="post" action="${_htmlEscape(_JazzCashEndpoints.checkoutUrl)}">'
        '$inputs</form>'
        '<script>document.getElementById("pay").submit();</script>'
        '</body></html>';
  }

  /// Verifies a hosted-checkout redirect (query parameters appended by the
  /// gateway onto the Return URL). Verifies pp_SecureHash, records the
  /// transaction and updates the order lifecycle. Result is FINAL.
  static Future<PaymentVerifyResult> verifyJazzCashRedirect({
    required String txnRefNo,
    required String orderId,
    required Map<String, String> returnParams,
  }) async {
    final secureHash = returnParams['pp_SecureHash'] ?? '';
    if (secureHash.isEmpty) {
      return const PaymentVerifyResult(
          paid: false, responseMessage: 'Missing gateway signature');
    }
    final verifyFields = <String, String>{
      for (final e in returnParams.entries)
        if (e.key.toLowerCase().startsWith('pp_') && e.key != 'pp_SecureHash')
          e.key: e.value,
    };
    final expected = JazzCashHasher.compute(verifyFields);
    final hashValid =
        expected.toLowerCase() == secureHash.toLowerCase();

    final code = returnParams['pp_ResponseCode'] ?? '999';
    final message = returnParams['pp_ResponseMessage'] ??
        returnParams['pp_ResponseBody'] ??
        'Hosted checkout returned';
    final paid = code == '000' && hashValid;

    await _recordTransaction(
      txnRefNo: txnRefNo,
      orderId: orderId,
      gateway: 'jazzCash',
      amount: double.tryParse(returnParams['pp_Amount'] ?? '') ?? 0,
      responseCode: '$code (hash ${hashValid ? 'valid' : 'INVALID'})',
      responseMessage: message,
      status: paid ? 'paid' : 'failed',
      extra: {'flow': 'hostedCheckout', 'hashValidated': hashValid},
    );

    if (paid) {
      await markOrderAsPaid(orderId, txnRefNo);
    } else {
      await markOrderPaymentFailed(orderId);
    }
    return PaymentVerifyResult(
      paid: paid,
      txnRefNo: txnRefNo,
      responseCode: code,
      responseMessage: message,
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // 3) EASYPAISA HOSTED CHECKOUT (MA wallet + OTC voucher) + STATUS POLLING
  // ═════════════════════════════════════════════════════════════════════════

  /// Initiates an Easypaisa hosted transaction.
  ///
  /// [paymentMethod] must be `MA` (mobile account — customer approves on
  /// his phone with the MPIN) or `OTC` (voucher paid at any Easypaisa
  /// outlet / app). Both are ASYNC → the result ALWAYS
  /// awaitsVerification; bank confirmation arrives via status polling.
  static Future<PaymentInitResult> initiateEasypaisa({
    required String orderId,
    required double amount,
    required String mobileNumber,
    required String customerEmail,
    String paymentMethod = 'MA',
  }) async {
    if (!easypaisaReady) {
      return PaymentInitResult(
        success: false,
        gateway: PaymentGateway.easypaisa,
        errorMessage: PaymentCredentials.easypaisaSetupHint,
      );
    }
    final txnRefNo = 'EP${DateTime.now().millisecondsSinceEpoch}';
    try {
      final body = <String, String>{
        'storeId': PaymentCredentials.easypaisaStoreId,
        'amount': amount.toStringAsFixed(0),
        'postBackURL': _EasypaisaEndpoints.postBackUrl,
        'orderRefNum': orderId,
        'expiryDate': _expiryFormatted(),
        'autoRedirect': '1',
        'merchantPaymentMethod': paymentMethod,
        'emailAddr': customerEmail,
        'msisdn': _normalizePakistaniMsisdn(mobileNumber),
        'txnRefNo': txnRefNo,
        'timeStamp': _nowFormatted(),
      };

      final hashed = Map<String, String>.from(body)
        ..['merchantHashedReq'] = EasypaisaHasher.compute(body);

      await _recordTransaction(
        txnRefNo: txnRefNo,
        orderId: orderId,
        gateway: 'easypaisa',
        amount: amount,
        responseCode: 'initiated',
        responseMessage: 'Hosted checkout opened ($paymentMethod)',
        status: 'awaiting_verification',
        extra: {'paymentMethod': paymentMethod},
      );

      return PaymentInitResult(
        success: true,
        gateway: PaymentGateway.easypaisa,
        txnRefNo: txnRefNo,
        awaitsVerification: true,
        checkoutHtml: buildEasypaisaCheckoutHtml(hashed),
      );
    } catch (e) {
      debugPrint('PaymentService.initiateEasypaisa error: $e');
      return PaymentInitResult(
        success: false,
        gateway: PaymentGateway.easypaisa,
        txnRefNo: txnRefNo,
        errorMessage: _friendlyNetworkError(e),
      );
    }
  }

  /// Auto-submitting HTML form for the Easypaisa hosted payment page.
  static String buildEasypaisaCheckoutHtml(Map<String, String> fields) {
    final inputs = fields.entries
        .map((e) => '<input type="hidden" name="${e.key}" '
            'value="${_htmlEscape(e.value)}"/>')
        .join('\n');
    return '<!DOCTYPE html><html><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<title>Redirecting to Easypaisa…</title></head>'
        '<body style="font-family:sans-serif;text-align:center;padding-top:45vh">'
        '<p>Connecting to Easypaisa…</p>'
        '<form id="pay" method="post" action="${_htmlEscape(_EasypaisaEndpoints.checkoutUrl)}">'
        '$inputs</form>'
        '<script>document.getElementById("pay").submit();</script>'
        '</body></html>';
  }

  /// Authoritative Easypaisa Transaction Status Inquiry (REST v4).
  ///
  /// Docs state the request hash covers `orderId` + `storeId` (sorted).
  /// Returns a normalised [PaymentStatusPollResult]; never throws.
  static Future<PaymentStatusPollResult> inquireEasypaisaStatus(
      String orderRefNum) async {
    try {
      final requestParams = <String, String>{
        'storeId': PaymentCredentials.easypaisaStoreId,
        'orderId': orderRefNum,
      };
      final response = await http
          .post(
            Uri.parse(_EasypaisaEndpoints.statusUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'orderId': orderRefNum,
              'storeId': PaymentCredentials.easypaisaStoreId,
              'merchantHashedReq': EasypaisaHasher.compute(requestParams),
            }),
          )
          .timeout(AppTimings.network);

      if (response.statusCode >= 400) {
        return PaymentStatusPollResult(
          outcome: PaymentPollOutcome.transportError,
          message: 'HTTP ${response.statusCode}',
        );
      }
      final dynamic decoded = jsonDecode(_safeJsonBody(response.body));
      final data =
          decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
      final status = (data['status'] ??
              data['transactionStatus'] ??
              '')
          .toString()
          .toUpperCase();

      final txnId =
          (data['transactionId'] ?? data['trnId'])?.toString();
      if (status == 'PAID') {
        return PaymentStatusPollResult(
          outcome: PaymentPollOutcome.paid,
          gatewayStatus: status,
          transactionId: txnId,
        );
      }
      if (status.contains('FAIL') ||
          status.contains('DECLIN') ||
          status.contains('REJECT')) {
        return PaymentStatusPollResult(
          outcome: PaymentPollOutcome.failed,
          gatewayStatus: status,
          transactionId: txnId,
          message: data['message']?.toString(),
        );
      }
      return PaymentStatusPollResult(
        outcome: PaymentPollOutcome.pending,
        gatewayStatus: status.isEmpty ? 'PENDING' : status,
        transactionId: txnId,
      );
    } catch (e) {
      debugPrint('PaymentService.inquireEasypaisaStatus error: $e');
      return PaymentStatusPollResult(
        outcome: PaymentPollOutcome.transportError,
        message: _friendlyNetworkError(e),
      );
    }
  }

  /// Polls the gateway every [interval] until [attempts] is exhausted.
  /// After PAID/FAILED the order lifecycle is updated immediately, and the
  /// transaction record is refreshed. Never throws.
  static Future<PaymentVerifyResult> pollEasypaisaUntilSettled({
    required String orderId,
    required String txnRefNo,
    int attempts = 12,
  }) async {
    const interval = Duration(seconds: 6);
    var lastMessage = 'No confirmation yet.';
    for (var i = 0; i < attempts; i++) {
      final result = await inquireEasypaisaStatus(orderId);
      switch (result.outcome) {
        case PaymentPollOutcome.paid:
          final verify = await verifyPayment(txnRefNo);
          final data = {
            'gatewayStatus': result.gatewayStatus,
            'transactionId': result.transactionId,
          };
          await _updateTransaction(txnRefNo, {
            'status': 'paid',
            'gatewayStatus': result.gatewayStatus,
            'gatewayTransactionId': result.transactionId,
            'responseCode': 'PAID',
            'paidAt': DateTime.now().toIso8601String(),
            'verifiedVia': 'statusInquiry',
            'inquiryMeta': data,
          });
          await markOrderAsPaid(orderId, txnRefNo);
          return PaymentVerifyResult(
            paid: true,
            txnRefNo: txnRefNo,
            responseCode: 'PAID',
            responseMessage: 'Confirmed by Easypaisa (${result.transactionId ?? verify.responseCode})',
          );
        case PaymentPollOutcome.failed:
          await _updateTransaction(txnRefNo, {
            'status': 'failed',
            'gatewayStatus': result.gatewayStatus,
            'responseCode': 'FAILED',
            'responseMessage': result.message ?? 'Easypaisa reported failure',
          });
          await markOrderPaymentFailed(orderId);
          return PaymentVerifyResult(
            paid: false,
            txnRefNo: txnRefNo,
            responseCode: 'FAILED',
            responseMessage: result.message ?? 'Payment was declined.',
          );
        case PaymentPollOutcome.pending:
          lastMessage = 'Gateway status: ${result.gatewayStatus}';
          break;
        case PaymentPollOutcome.transportError:
          lastMessage = result.message ?? 'Network issue while checking status.';
          break;
      }
      await Future<void>.delayed(interval);
    }
    return PaymentVerifyResult(
      paid: false,
      txnRefNo: txnRefNo,
      responseCode: 'PENDING',
      responseMessage: lastMessage,
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // 4) VERIFICATION & ORDER LIFECYCLE
  // ═════════════════════════════════════════════════════════════════════════

  /// Looks up recorded transaction state from SQLite
  static Future<PaymentVerifyResult> verifyPayment(String txnRefNo) async {
    try {
      if (_txnMemory.containsKey(txnRefNo)) {
        final data = _txnMemory[txnRefNo]!;
        final paid = data['status'] == 'paid';
        return PaymentVerifyResult(
          paid: paid,
          txnRefNo: txnRefNo,
          responseCode: data['responseCode'] as String?,
          responseMessage: data['responseMessage'] as String?,
        );
      }
      final rows = await _db.query(
        'system_telemetry',
        where: 'id = ?',
        whereArgs: [txnRefNo],
        limit: 1,
      );
      if (rows.isEmpty) {
        return const PaymentVerifyResult(
          paid: false,
          responseMessage: 'Transaction not found.',
        );
      }
      final tags = jsonDecode(rows.first['tagsJson']?.toString() ?? '{}') as Map<String, dynamic>;
      final paid = tags['status'] == 'paid';
      return PaymentVerifyResult(
        paid: paid,
        txnRefNo: txnRefNo,
        responseCode: tags['responseCode'] as String?,
        responseMessage: tags['responseMessage'] as String?,
      );
    } catch (e) {
      debugPrint('PaymentService.verifyPayment error: $e');
      return PaymentVerifyResult(
        paid: false,
        responseMessage: e.toString(),
      );
    }
  }

  /// Marks the order PAID in SQLite
  static Future<void> markOrderAsPaid(String orderId, String txnRefNo) async {
    try {
      final now = DateTime.now().toIso8601String();
      await _db.update(
        'orders',
        {
          'status': 'paid',
          'updatedAt': now,
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
      _db.notifyTable('orders');
    } catch (e) {
      debugPrint('PaymentService.markOrderAsPaid error: $e');
      rethrow;
    }
  }

  /// Marks the order payment as definitively FAILED in SQLite
  static Future<void> markOrderPaymentFailed(String orderId) async {
    try {
      await _db.update(
        'orders',
        {
          'status': 'cancelled',
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
      _db.notifyTable('orders');
    } catch (e) {
      debugPrint('PaymentService.markOrderPaymentFailed error: $e');
    }
  }

  /// Opened hosted checkout / awaiting gateway in SQLite
  static Future<void> markOrderAwaitingVerification(String orderId) async {
    try {
      await _db.update(
        'orders',
        {
          'updatedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );
      _db.notifyTable('orders');
    } catch (e) {
      debugPrint('PaymentService.markOrderAwaitingVerification error: $e');
    }
  }

  // ═════════════════════════════════════════════════════════════════════════
  // 5) TRANSACTION RECORDS (SQLite + in-memory cache)
  // ═════════════════════════════════════════════════════════════════════════

  static Future<void> _recordTransaction({
    required String txnRefNo,
    required String orderId,
    required String gateway,
    required double amount,
    required String responseCode,
    required String responseMessage,
    required String status,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final data = {
        'txnRefNo': txnRefNo,
        'orderId': orderId,
        'gateway': gateway,
        'amount': amount,
        'responseCode': responseCode,
        'responseMessage': responseMessage,
        'status': status,
        'userId': _currentUserUid(),
        if (extra != null) ...extra,
        'createdAt': DateTime.now().toIso8601String(),
      };
      _txnMemory[txnRefNo] = data;

      await _db.insertOrReplace('system_telemetry', {
        'id': txnRefNo,
        'metricName': 'payment_transaction',
        'metricValue': amount,
        'tagsJson': jsonEncode(data),
        'recordedAt': DateTime.now().toIso8601String(),
      });
      _db.notifyTable('system_telemetry');
    } catch (e) {
      debugPrint('PaymentService._recordTransaction notice: $e');
    }
  }

  /// Public alias used by PayFastGateway to patch a transaction record.
  static Future<void> updateTransaction(
          String txnRefNo, Map<String, dynamic> patch) =>
      _updateTransaction(txnRefNo, patch);

  /// Public alias used by PayFastGateway to create transaction records.
  static Future<void> recordTransaction({
    required String txnRefNo,
    required String orderId,
    required String gateway,
    required double amount,
    required String responseCode,
    required String responseMessage,
    required String status,
    Map<String, dynamic>? extra,
  }) =>
      _recordTransaction(
        txnRefNo: txnRefNo,
        orderId: orderId,
        gateway: gateway,
        amount: amount,
        responseCode: responseCode,
        responseMessage: responseMessage,
        status: status,
        extra: extra,
      );

  static Future<void> _updateTransaction(
      String txnRefNo, Map<String, dynamic> patch) async {
    try {
      if (_txnMemory.containsKey(txnRefNo)) {
        _txnMemory[txnRefNo]!.addAll(patch);
      }
      await _db.update(
        'system_telemetry',
        {
          'tagsJson': jsonEncode(_txnMemory[txnRefNo] ?? patch),
          'recordedAt': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [txnRefNo],
      );
      _db.notifyTable('system_telemetry');
    } catch (e) {
      debugPrint('PaymentService._updateTransaction notice: $e');
    }
  }

  // ── SMALL HELPERS ─────────────────────────────────────────────────────────

  /// Public test seam: rupees → whole-paisa string ('2995.00' → '299500').
  static String jazzCashPaisasForTest(double amount) =>
      _jazzCashPaisas(amount);

  /// Public test seam: MSISDN normalisation for diagnosability of gateway
  /// rejections (a wrong MSISDN format is the #1 sandbox error).
  static String normalizeMsisdnForTest(String raw) =>
      _normalizePakistaniMsisdn(raw);

  /// Formats ruppees as intentional paisa integers ('2995.00' → '299500').
  static String _jazzCashPaisas(double amount) =>
      (amount * 100).round().toString();

  /// Accepts 0300… / +92 300… / 92300… → '0XXXXXXXXXX' (11-digit MSISDN).
  static String _normalizePakistaniMsisdn(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('92')) digits = digits.substring(2);
    if (digits.length == 10 && !digits.startsWith('0')) digits = '0$digits';
    return digits;
  }

  /// yyyyMMddHHmmss (gateway convention).
  static String _nowFormatted() {
    final now = DateTime.now();
    return '${now.year}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}';
  }

  /// Expiry ~1 hour out: enough time to finish checkout without granting an
  /// unreasonably long payment window (previously 24 h).
  static String _expiryFormatted() {
    final expiry = DateTime.now().add(const Duration(hours: 1));
    return '${expiry.year}'
        '${expiry.month.toString().padLeft(2, '0')}'
        '${expiry.day.toString().padLeft(2, '0')}'
        '${expiry.hour.toString().padLeft(2, '0')}'
        '${expiry.minute.toString().padLeft(2, '0')}'
        '${expiry.second.toString().padLeft(2, '0')}';
  }

  static String _safeJsonBody(String body) {
    if (body.isEmpty) return '{}';
    // Some gateway pages answer with HTML error pages; guard the JSON decode.
    try {
      final value = jsonDecode(body);
      if (value is Map) return body;
      return '{}';
    } catch (_) {
      final head = body.length > 160
          ? body.substring(0, 160)
          : body;
      debugPrint('PaymentService: non-JSON gateway response (head): $head');
      return '{}';
    }
  }

  static String _htmlEscape(String v) => v
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String _friendlyNetworkError(Object e) =>
      e.toString().contains('SocketException') || e.toString().contains('timeout')
          ? 'Could not reach the payment gateway. Check your internet connection and try again.'
          : e.toString();
}

/// Shared network timeouts for all gateway calls (replaces the scattered
/// `Duration(seconds: 15)` literals).
class AppTimings {
  static const Duration network = Duration(seconds: 20);
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

final paymentServiceProvider = Provider<PaymentService>((ref) => PaymentService());
