import 'package:venteapp/core/security/pin_hasher.dart';
import 'package:venteapp/core/security/recovery_token_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late RecoveryTokenService service;

  setUp(() {
    service = RecoveryTokenService(PinHasher(cost: 4));
  });

  test('génère un jeton et un hash vérifiable', () {
    final result = service.generate();

    expect(result.token, isNotEmpty);
    expect(result.hash, isNot(equals(result.token)));
    expect(PinHasher(cost: 4).compare(result.token, result.hash), isTrue);
  });

  test('génère des jetons distincts à chaque appel', () {
    final first = service.generate();
    final second = service.generate();

    expect(first.token, isNot(equals(second.token)));
  });
}
