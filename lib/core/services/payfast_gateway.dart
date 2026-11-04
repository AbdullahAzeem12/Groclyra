import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/payment_credentials.dart';
import 'payment_service.dart';

// ═════════════════════════════════════════════════════════════════════════════
// PAYFAST GATEWAY (Premier Systems — gopayfast.com)
// ═════════════════════════════════════════════════════════════════════════════
// The operator-friendly gateway: exactly TWO credentials (Merchant ID +
// Secured Key) and ONE hosted checkout page that automatically offers cards
// (PayPak / Visa / Master), Google Pay, bank accounts and wallets (JazzCash /
// Easypaisa / UPaisa). Card data never touches this app → no PCI burden.
//
// Official hosted-checkout flow (gopayfast.com/docs):
//  1. POST {API_URL}token            → one-time access token (code '00')
//  2. signature = md5(merchantId ':' merchantName ':' amount ':' orderId)
//  3. form-POST payload to {API_URL}checkout → gateway renders its page
//  4. gateway redirects to SUCCESS_URL / FAILURE_URL with the signature we
//     submitted + order_id → we re-verify the MD5 locally
//  5. GET {API_URL}transaction/basket_id/{orderId} (Bearer token) — the
//     AUTHORITATIVE transaction state; this, not the redirect, marks `paid`.
//
// The exact API base URL is issued by PayFast together with the credentials
// and supplied via --dart-define=PAYFAST_API_URL (must end with '/').
// ═════════════════════════════════════════════════════════════════════════════

class _PayFastEndpoints {
  /// REST base — PayFast prints this into every merchant's welcome pack.
  static const String defaultUatBase =
      'https://ipguat.apps.net.pk/Ecommerce/api/1/';
  static const String defaultLiveBase =
      'https://ipg.apps.net.pk/Ecommerce/api/1/';

  static String get apiBase {
    const configured = PaymentCredentials.payFastApiUrl;
    if (configured.isNotEmpty) return configured;
    return PaymentCredentials.isSandbox ? defaultUatBase : defaultLiveBase;
  }

  static String get tokenUrl => '${apiBase}token';

  /// Hosted-checkout form target. Overridable in case PayFast provisioned a
  /// different checkout path.
  static String get checkoutUrl => const String.fromEnvironment(
        'PAYFAST_CHECKOUT_URL',
        defaultValue: '',
      ).isEmpty
          ? '${apiBase}checkout'
          : const String.fromEnvironment('PAYFAST_CHECKOUT_URL');

  static String get transactionByIdUrl =>
      '${apiBase}transaction/basket_id/';

  /// Where the gateway redirects the customer in-app.
  static const successPath = 'https://groclyra.app/payment/payfast/success';
  static const failurePath = 'https://groclyra.app/payment/payfast/failure';
}

/// Result of the PayFast checkout preparation.
class PayFastCheckoutResult {
  final bool success;
  final String? checkoutHtml;
  final String? txnRefNo;
  final String? errorMessage;

  const PayFastCheckoutResult({
    required this.success,
    this.checkoutHtml,
    this.txnRefNo,
    this.errorMessage,
  });
}

class PayFastGateway {
  const PayFastGateway._();

  static bool get isReady => PaymentCredentials.payFastConfigured;

  // ─────────────────────────────────────────────────────────────────────────
  // SIGNATURE (official scheme — md5 over the four pipe fields)
  // ─────────────────────────────────────────────────────────────────────────

  /// Canonical signature: md5(merchantId ':' merchantName ':' amount
  /// ':' orderId) — [amountStr] must be the EXACT same string sent as
  /// TXNAMT (that's the #1 sandbox-signature mismatch bug).
  static String computeSignature({
    required String merchantId,
    required String merchantName,
    required String amountStr,
    required String orderId,
  }) {
    final message = '$merchantId:$merchantName:$amountStr:$orderId';
    return md5.convert(utf8.encode(message)).toString();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 1) ACCESS TOKEN  (form-urlencoded POST {API_URL}token)
  // ─────────────────────────────────────────────────────────────────────────

  /// Returns the one-time access token, or null with error info on failure.
  static Future<(String?, String?)> _getAccessToken() async {
    try {
      final response = await http
          .post(
            Uri.parse(_PayFastEndpoints.tokenUrl),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: {
              'grant_type': 'client_credentials',
              'merchant_id': PaymentCredentials.payFastMerchantId,
              'secured_key': PaymentCredentials.payFastSecuredKey,
            },
          )
          .timeout(AppTimings.network);

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        return (null, 'Gateway returned a non-JSON response '
            '(HTTP ${response.statusCode}).');
      }
      if (decoded is! Map) {
        return (null, 'Malformed token response from PayFast.');
      }
      final data = decoded as Map<String, dynamic>;

      final code = data['code']?.toString() ?? '';
      final token = (data['token'] ??
              (data['data'] is Map
                  ? (data['data'] as Map)['token']
                  : null))
          ?.toString();

      if (token != null && token.isNotEmpty && (code.isEmpty || code == '00')) {
        return (token, null);
      }
      return (null,
          'PayFast rejected the credentials (code $code). ${data['message'] ?? ''}'
              .trim());
    } catch (e) {
      debugPrint('PayFastGateway._getAccessToken error: $e');
      return (null, _friendlyError(e));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2) HOSTED CHECKOUT
  // ─────────────────────────────────────────────────────────────────────────

  /// Prepares a hosted PayFast checkout. Returns an auto-submitting HTML form
  /// for the payment WebView. Call [verifyReturn] when the gateway redirects
  /// back; NEVER mark the order paid from the redirect alone.
  static Future<PayFastCheckoutResult> startCheckout({
    required String orderId,
    required double amount,
    required String customerMobile,
    required String customerEmail,
    required String customerName,
    String description = 'Groclyra grocery order',
  }) async {
    if (!isReady) {
      return const PayFastCheckoutResult(
        success: false,
        errorMessage: 'PayFast is not configured yet — build with '
            '--dart-define=PAYFAST_MERCHANT_ID / PAYFAST_SECURED_KEY / '
            'PAYFAST_API_URL.',
      );
    }
    final txnRefNo = 'PF${DateTime.now().millisecondsSinceEpoch}';
    final (token, tokenError) = await _getAccessToken();
    if (token == null) {
      return PayFastCheckoutResult(
        success: false,
        txnRefNo: txnRefNo,
        errorMessage: tokenError ?? 'Could not obtain the PayFast token.',
      );
    }

    // ONE canonical amount string shared by TXNAMT and the signature —
    // a difference of formatting would break the MD5 verification.
    final amountStr = amount.toStringAsFixed(2);
    const merchantName = PaymentCredentials.payFastMerchantName;
    final signature = computeSignature(
      merchantId: PaymentCredentials.payFastMerchantId,
      merchantName: merchantName,
      amountStr: amountStr,
      orderId: orderId,
    );

    final payload = <String, String>{
      'MERCHANT_ID': PaymentCredentials.payFastMerchantId,
      'MERCHANT_NAME': merchantName,
      'TOKEN': token,
      'PROCCODE': '00',
      'TXNAMT': amountStr,
      'CUSTOMER_MOBILE_NO': customerMobile,
      'CUSTOMER_EMAIL_ADDRESS': customerEmail,
      'SIGNATURE': signature,
      'VERSION': 'GROCLYRA-APP-PAYMENT-1.0',
      'TXNDESC': 'Groclyra grocery order $orderId — $customerName',
      'SUCCESS_URL': _PayFastEndpoints.successPath,
      'FAILURE_URL': _PayFastEndpoints.failurePath,
      'BASKET_ID': orderId,
      'ORDER_DATE': DateTime.now()
          .toIso8601String()
          .split('T')
          .first, // yyyy-MM-dd
      'CHECKOUT_URL':
          'signature=$signature&order_id=$orderId',
    };

    await PaymentService.recordTransaction(
      txnRefNo: txnRefNo,
      orderId: orderId,
      gateway: 'payFast',
      amount: amount,
      responseCode: 'initiated',
      responseMessage: 'PayFast hosted checkout opened',
      status: 'awaiting_verification',
      extra: const {'flow': 'hostedCheckout'},
    );

    return PayFastCheckoutResult(
      success: true,
      txnRefNo: txnRefNo,
      checkoutHtml: _checkoutHtml(_PayFastEndpoints.checkoutUrl, payload),
    );
  }

  static String _checkoutHtml(String action, Map<String, String> fields) {
    final inputs = fields.entries
        .map((e) => '<input type="hidden" name="${e.key}" '
            'value="${_htmlEscape(e.value)}"/>')
        .join('\n');
    return '<!DOCTYPE html><html><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width, initial-scale=1">'
        '<title>Redirecting to PayFast…</title></head>'
        '<body style="font-family:sans-serif;text-align:center;padding-top:45vh">'
        '<p>Connecting to PayFast secure checkout…</p>'
        '<form id="pay" method="post" action="${_htmlEscape(action)}">'
        '$inputs</form>'
        '<script>document.getElementById("pay").submit();</script>'
        '</body></html>';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3) RETURN-URL VERIFICATION + AUTHORITATIVE STATUS CHECK
  // ─────────────────────────────────────────────────────────────────────────

  /// Verifies the redirect signature locally, then asks PayFast for the
  /// authoritative transaction state for [orderId]. The order lifecycle
  /// (paid / failed) is updated here. Never throw.
  static Future<PaymentVerifyResult> verifyAndSettle({
    required String orderId,
    required String txnRefNo,
    required double amount,
    required Map<String, String> returnParams,
  }) async {
    // Fail CLOSED when the gateway isn't provisioned: without credentials we
    // cannot ask PayFast for the authoritative state, so money can never be
    // confirmed from a redirect alone.
    if (!isReady) {
      await PaymentService.updateTransaction(txnRefNo, {
        'status': 'failed',
        'responseCode': 'NOT_CONFIGURED',
        'responseMessage':
            'PayFast credentials missing — redirect ignored (fail-closed).',
      });
      await PaymentService.markOrderPaymentFailed(orderId);
      return const PaymentVerifyResult(
        paid: false,
        responseCode: 'NOT_CONFIGURED',
        responseMessage:
            'Online payment is not set up yet. Please use Cash on Delivery.',
      );
    }
    final receivedSignature =
        returnParams['signature'] ?? returnParams['SIGNATURE'] ?? '';
    final expectedSignature = computeSignature(
      merchantId: PaymentCredentials.payFastMerchantId,
      merchantName: PaymentCredentials.payFastMerchantName,
      amountStr: amount.toStringAsFixed(2),
      orderId: orderId,
    );

    // A tampered/garbage signature → do not trust the redirect. We still
    // fall through to the authoritative inquiry, but record the mismatch.
    final signatureValid =
        receivedSignature.isNotEmpty &&
            receivedSignature.toLowerCase() == expectedSignature.toLowerCase();

    if (!signatureValid && receivedSignature.isNotEmpty) {
      debugPrint('PayFastGateway: redirect signature MISMATCH for $orderId');
    }

    final status = await inquireTransactionStatus(orderId);
    switch (status.outcome) {
      case PaymentPollOutcome.paid:
        await PaymentService.updateTransaction(txnRefNo, {
          'status': 'paid',
          'gatewayStatus': status.gatewayStatus,
          'gatewayTransactionId': status.transactionId,
          'responseCode': 'PAID',
          'verifiedVia': 'transactionInquiry',
          'returnSignatureValid': signatureValid,
        });
        await PaymentService.markOrderAsPaid(orderId, txnRefNo);
        return PaymentVerifyResult(
          paid: true,
          txnRefNo: txnRefNo,
          responseCode: 'PAID',
          responseMessage: 'Confirmed by PayFast',
        );
      case PaymentPollOutcome.failed:
        await PaymentService.updateTransaction(txnRefNo, {
          'status': 'failed',
          'gatewayStatus': status.gatewayStatus,
          'responseCode': 'FAILED',
          'responseMessage': status.message ?? 'PayFast reported failure',
          'returnSignatureValid': signatureValid,
        });
        await PaymentService.markOrderPaymentFailed(orderId);
        return PaymentVerifyResult(
          paid: false,
          txnRefNo: txnRefNo,
          responseCode: 'FAILED',
          responseMessage: status.message ?? 'Payment was not completed.',
        );
      case PaymentPollOutcome.pending:
      case PaymentPollOutcome.transportError:
        await PaymentService.updateTransaction(txnRefNo, {
          if (status.outcome != PaymentPollOutcome.pending) 'status': 'pending',
          'gatewayStatus': status.gatewayStatus,
          'responseCode': 'PENDING',
          'responseMessage':
              status.message ?? 'Awaiting PayFast confirmation.',
          'returnSignatureValid': signatureValid,
        });
        return PaymentVerifyResult(
          paid: false,
          txnRefNo: txnRefNo,
          responseCode: 'PENDING',
          responseMessage: status.message ?? 'Awaiting PayFast confirmation.',
        );
    }
  }

  /// GET {API_URL}transaction/basket_id/{orderId} — authoritative state.
  static Future<PaymentStatusPollResult> inquireTransactionStatus(
      String orderId) async {
    final (token, tokenError) = await _getAccessToken();
    if (token == null) {
      return PaymentStatusPollResult(
        outcome: PaymentPollOutcome.transportError,
        message: tokenError,
      );
    }
    try {
      final response = await http
          .get(
            Uri.parse('${_PayFastEndpoints.transactionByIdUrl}$orderId'),
            headers: {
              'Content-Type': 'application/x-www-form-urlencoded',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(AppTimings.network);

      if (response.statusCode >= 400) {
        return PaymentStatusPollResult(
          outcome: PaymentPollOutcome.transportError,
          message: 'PayFast HTTP ${response.statusCode}.',
        );
      }
      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } catch (_) {
        return const PaymentStatusPollResult(
          outcome: PaymentPollOutcome.transportError,
          message: 'Non-JSON response from PayFast.',
        );
      }
      if (decoded is! Map) {
        return const PaymentStatusPollResult(
          outcome: PaymentPollOutcome.transportError,
          message: 'Malformed PayFast response.',
        );
      }
      final data = decoded as Map<String, dynamic>;

      final code = data['code']?.toString() ?? '';
      final statusField = (data['status'] ??
              data['statusAfter'] ??
              data['orderStatus'] ??
              data['state'] ??
              '')
          .toString()
          .toUpperCase();
      final txnId = (data['transactionId'] ??
              data['transaction_id'] ??
              data['txn_ref_no'])
          ?.toString();

      final paid = code == '00' &&
          (statusField.contains('PAID') ||
              statusField.contains('COMPLETE') ||
              statusField.contains('SUCCESS'));
      if (paid) {
        return PaymentStatusPollResult(
          outcome: PaymentPollOutcome.paid,
          gatewayStatus: statusField.isEmpty ? 'PAID' : statusField,
          transactionId: txnId,
        );
      }
      if (statusField.contains('FAIL') ||
          statusField.contains('DECLIN') ||
          statusField.contains('REJECT') ||
          statusField.contains('CANCEL') ||
          statusField.contains('EXPIR')) {
        return PaymentStatusPollResult(
          outcome: PaymentPollOutcome.failed,
          gatewayStatus: statusField,
          transactionId: txnId,
          message: data['message']?.toString() ??
              data['errorDescription']?.toString() ??
              'PayFast reported: $statusField',
        );
      }
      return PaymentStatusPollResult(
        outcome: PaymentPollOutcome.pending,
        gatewayStatus: statusField.isEmpty ? 'PENDING' : statusField,
        transactionId: txnId,
      );
    } catch (e) {
      debugPrint('PayFastGateway.inquireTransactionStatus error: $e');
      return PaymentStatusPollResult(
        outcome: PaymentPollOutcome.transportError,
        message: _friendlyError(e),
      );
    }
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  static String _htmlEscape(String v) => v
      .replaceAll('&', '&amp;')
      .replaceAll('"', '&quot;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');

  static String _friendlyError(Object e) =>
      e.toString().contains('SocketException') ||
              e.toString().contains('timeout')
          ? 'Could not reach PayFast. Check your internet connection and try again.'
          : e.toString();
}
