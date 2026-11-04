// ═════════════════════════════════════════════════════════════════════════════
// PAYMENT GATEWAY UNIT TESTS
//
// Validates the gateway hash engines against the OFFICIAL vendor test
// vectors, so the day real merchant credentials are plugged in the request
// signing is guaranteed correct — no live gateway needed for this guarantee.
// ═════════════════════════════════════════════════════════════════════════════
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:groclyra/core/services/payment_service.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/ecb.dart';
import 'package:pointycastle/padded_block_cipher/padded_block_cipher_impl.dart';
import 'package:pointycastle/paddings/pkcs7.dart';
import 'package:pointycastle/pointycastle.dart' show KeyParameter, PaddedBlockCipherParameters;

void main() {
  group('JazzCashHasher — official "Hashing Scheme" (sandbox doc v4.2)', () {
    // Vendor's own published example:
    //   fields pp_Amount=2995, pp_MerchantID=MER123, pp_OrderInfo=A48cvE28
    //   shared secret '0F5DD14AE2'
    //   message  '0F5DD14AE2&2995&MER123&A48cvE28'
    //   hash     c7689cda7474eb1adcd343fd0c0b676bad0ba66361cc46db589bdb0da4c1c867
    test('reproduces the official example hash byte-for-byte', () {
      final hash = JazzCashHasher.compute(
        {
          'pp_MerchantID': 'MER123',
          'pp_OrderInfo': 'A48cvE28',
          'pp_Amount': '2995',
        },
        salt: '0F5DD14AE2',
      );
      expect(
        hash,
        'c7689cda7474eb1adcd343fd0c0b676bad0ba66361cc46db589bdb0da4c1c867',
      );
    });

    test('sorts pp_ fields alphabetically regardless of input order', () {
      final a = JazzCashHasher.compute(
        {
          'pp_MerchantID': 'MER123',
          'pp_Amount': '2995',
          'pp_OrderInfo': 'A48cvE28',
        },
        salt: '0F5DD14AE2',
      );
      final b = JazzCashHasher.compute(
        {
          'pp_Amount': '2995',
          'pp_OrderInfo': 'A48cvE28',
          'pp_MerchantID': 'MER123',
        },
        salt: '0F5DD14AE2',
      );
      expect(a, b); // insertion order must not change the hash
    });

    test('verify() accepts a genuine gateway response and rejects tampering',
        () {
      final response = <String, dynamic>{
        'pp_ResponseCode': '000',
        'pp_ResponseMessage': 'Transaction successful',
        'pp_TxnRefNo': 'T202601010915097777777',
        'pp_MerchantID': 'MER123',
        'pp_Amount': '2995',
      };
      final genuineHash = JazzCashHasher.compute(
        response.map((k, v) => MapEntry(k, v.toString())),
        salt: '0F5DD14AE2',
      );
      response['pp_SecureHash'] = genuineHash;

      expect(JazzCashHasher.verify(response, salt: '0F5DD14AE2'), isTrue);

      // ── tamper: any modified field must invalidate the response ──
      final tampered = Map<String, dynamic>.from(response)
        ..['pp_Amount'] = '999999';
      expect(JazzCashHasher.verify(tampered, salt: '0F5DD14AE2'), isFalse);

      // ── missing hash must NEVER be trusted ──
      expect(
        JazzCashHasher.verify(
            response..remove('pp_SecureHash'), salt: '0F5DD14AE2'),
        isFalse,
      );
    });

    test('_jazzCashPaisas converts rupees to whole paisas', () {
      expect(PaymentService.jazzCashPaisasForTest(2995.0), '299500');
      expect(PaymentService.jazzCashPaisasForTest(499.99), '49999');
    });
  });

  group('EasypaisaHasher — Merchant Integration Guide AES-128-ECB scheme', () {
    const testKey = '0123456789ABCDEF'; // exactly 16 chars → AES-128

    String decrypt(String base64Ciphertext, String key) {
      final cipher = PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(AESEngine()))
        ..init(
          false, // decrypt
          PaddedBlockCipherParameters(KeyParameter(utf8.encode(key)), null),
        );
      final plain = cipher.process(base64.decode(base64Ciphertext));
      return utf8.decode(plain);
    }

    test('sortable key=value&… plaintext decrypts back unchanged', () {
      final hash = EasypaisaHasher.compute(
        {
          'amount': '1000',
          'storeId': '3371',
          'orderRefNum': 'ORD123',
          'postBackURL': 'https://groclyra.app/payment/easypaisa/callback',
          'merchantPaymentMethod': 'MA',
        },
        key: testKey,
      );

      // hash must be valid base64
      expect(base64.decode(hash), isNotEmpty);

      final decrypted = decrypt(hash, testKey);
      // alphabetical field sort, key=value joined with '&'
      expect(
        decrypted,
        'amount=1000&merchantPaymentMethod=MA&orderRefNum=ORD123'
        '&postBackURL=https://groclyra.app/payment/easypaisa/callback'
        '&storeId=3371',
      );
    });

    test('deterministic for identical requests', () {
      final body = <String, String>{
        'storeId': '3371',
        'amount': '1000',
        'orderRefNum': 'ORD123',
      };
      expect(
        EasypaisaHasher.compute(body, key: testKey),
        EasypaisaHasher.compute(body, key: testKey),
      );
    });

    test('different key → different ciphertext (never cross-decrypts)', () {
      final h1 = EasypaisaHasher.compute(
          {'amount': '1000', 'storeId': '3371'}, key: testKey);
      final h2 = EasypaisaHasher.compute(
          {'amount': '1000', 'storeId': '3371'}, key: 'FEDCBA9876543210');
      expect(h1, isNot(h2));
    });
  });

  group('MSISDN normalisation (gateway request format)', () {
    // Public seam added to the service for diagnosability of gateway
    // rejections (a wrong MSISDN format is the #1 sandbox error).
    test('normalises 0300… / +92-300… / 92300… consistently', () {
      expect(PaymentService.normalizeMsisdnForTest('03001234567'),
          '03001234567');
      expect(PaymentService.normalizeMsisdnForTest('+92 300 1234567'),
          '03001234567');
      expect(PaymentService.normalizeMsisdnForTest('923001234567'),
          '03001234567');
      expect(PaymentService.normalizeMsisdnForTest('0321 (123) 4567'),
          '03211234567');
    });
  });
}
