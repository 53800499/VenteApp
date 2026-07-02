import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/backup/shop_backup_crypto.dart';
import 'package:venteapp/core/errors/failures.dart';

void main() {
  test('chiffre et déchiffre un fichier .venteapp', () {
    const payload = '{"shopName":"Test"}';
    const passphrase = 'ma-phrase-secrete';

    final envelope = ShopBackupCrypto.seal(payload, passphrase);
    final decoded = ShopBackupCrypto.open(envelope, passphrase);

    expect(decoded, payload);
    expect(envelope['format'], 'venteapp');
  });

  test('rejette une phrase secrète incorrecte', () {
    final envelope = ShopBackupCrypto.seal('{"ok":true}', 'bonne-phrase-123');
    expect(
      () => ShopBackupCrypto.open(envelope, 'mauvaise-phrase'),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('rejette une phrase secrète trop courte', () {
    expect(
      () => ShopBackupCrypto.seal('data', 'court'),
      throwsA(isA<ValidationFailure>()),
    );
  });

  test('produit un fichier JSON sérialisable', () {
    final envelope = ShopBackupCrypto.seal('{"a":1}', 'phrase-1234');
    final encoded = jsonEncode(envelope);
    final roundTrip = jsonDecode(encoded) as Map<String, dynamic>;
    expect(ShopBackupCrypto.open(roundTrip, 'phrase-1234'), '{"a":1}');
  });
}
