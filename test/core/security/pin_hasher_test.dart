import 'package:frontend/core/security/pin_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late PinHasher hasher;

  setUp(() {
    hasher = PinHasher(cost: 4);
  });

  test('hash et compare un PIN correctement', () {
    const pin = '1234';
    final hash = hasher.hash(pin);

    expect(hash, isNot(equals(pin)));
    expect(hasher.compare(pin, hash), isTrue);
    expect(hasher.compare('9999', hash), isFalse);
  });

  test('deux hash du même PIN sont différents (sel bcrypt)', () {
    const pin = '5678';

    final hash1 = hasher.hash(pin);
    final hash2 = hasher.hash(pin);

    expect(hash1, isNot(equals(hash2)));
    expect(hasher.compare(pin, hash1), isTrue);
    expect(hasher.compare(pin, hash2), isTrue);
  });
}
