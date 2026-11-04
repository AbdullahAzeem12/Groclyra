// ═════════════════════════════════════════════════════════════════════════════
// PAYFAST GATEWAY UNIT TESTS
//
// PayFast (gopayfast.com — Premier Systems) is the primary online gateway.
// These tests pin the OFFICIAL hosted-checkout contract:
//   signature = md5(merchantId ':' merchantName ':' amount ':' orderId)
// The expected bytes are built here from the canonical string independently
// of the gateway helper, so the field composition is what's being proven.
// ═════════════════════════════════════════════════════════════════════════════
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:groclyra/core/services/payfast_gateway.dart';

void main() {
  group('PayFast signature — official md5 scheme', () {
    const merchantId = 'MC-777';
    const merchantName = 'Groclyra';
    const amountStr = '1234.50';
    const orderId = 'ORD-42';

    test('signature equals md5 of the canonical 4-field string', () {
      final sig = PayFastGateway.computeSignature(
        merchantId: merchantId,
        merchantName: merchantName,
        amountStr: amountStr,
        orderId: orderId,
      );
      final expectedCanonical = md5
          .convert(utf8.encode('$merchantId:$merchantName:$amountStr:$orderId'))
          .toString();
      expect(sig, expectedCanonical);
    });

    test('field composition matters — a different field flips the sig', () {
      final a = PayFastGateway.computeSignature(
          merchantId: merchantId,
          merchantName: merchantName,
          amountStr: amountStr,
          orderId: 'ORD-42');
      final b = PayFastGateway.computeSignature(
          merchantId: merchantId,
          merchantName: merchantName,
          amountStr: amountStr,
          orderId: 'ORD-43');
      final c = PayFastGateway.computeSignature(
          merchantId: merchantId,
          merchantName: merchantName,
          amountStr: '1234.51',
          orderId: 'ORD-42');
      final d = PayFastGateway.computeSignature(
          merchantId: merchantId,
          merchantName: 'GroclyraWrong',
          amountStr: amountStr,
          orderId: 'ORD-42');
      expect(a, isNot(b));
      expect(a, isNot(c));
      expect(a, isNot(d));
    });

    test('amount formatting is exact — 1234.50 ≠ 1234.5', () {
      // The #1 sandbox signature-mismatch bug: the gateway re-computes the
      // md5 over the string WE SEND as TXNAMT, so both must literally use
      // the same text.
      final a = PayFastGateway.computeSignature(
          merchantId: merchantId,
          merchantName: merchantName,
          amountStr: '1234.50',
          orderId: orderId);
      final b = PayFastGateway.computeSignature(
          merchantId: merchantId,
          merchantName: merchantName,
          amountStr: '1234.5',
          orderId: orderId);
      expect(a, isNot(b));
    });
  });

  group('verifyAndSettle — fail-closed contract', () {
    test('unreachable gateway / garbage signature → never marks paid',
        () async {
      final result = await PayFastGateway.verifyAndSettle(
        orderId: 'TEST-ORDER',
        txnRefNo: 'PF1',
        amount: 10.0,
        returnParams: const {'signature': 'garbage', 'order_id': 'TEST-ORDER'},
      );
      expect(result.paid, isFalse);
    });

    test('manufactured signature cannot conjure a payment (no gateway OK)',
        () async {
      // Even with a PERFECT locally-computed signature on the callback,
      // without the gateway's authoritative 'paid' the result must not
      // report paid — money comes from the gateway's transaction inquiry
      // only, never from a signed-looking redirect.
      final forged = PayFastGateway.computeSignature(
        merchantId: 'MC-777',
        merchantName: 'Groclyra',
        amountStr: '10.00',
        orderId: 'TEST-ORDER-2',
      );
      final result = await PayFastGateway.verifyAndSettle(
        orderId: 'TEST-ORDER-2',
        txnRefNo: 'PF2',
        amount: 10.0,
        returnParams: {'signature': forged, 'order_id': 'TEST-ORDER-2'},
      );
      expect(result.paid, isFalse);
    });
  });
}
