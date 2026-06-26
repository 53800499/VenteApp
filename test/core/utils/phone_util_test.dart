import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/utils/phone_util.dart';

void main() {
  group('normalizePhone', () {
    test('accepte le format national béninois 01...', () {
      expect(normalizePhone('01 97 00 00 00'), '+2290197000000');
    });

    test('convertit l\'ancien format 8 chiffres béninois', () {
      expect(normalizePhone('97000000'), '+2290197000000');
    });

    test('accepte un numéro international avec +', () {
      expect(normalizePhone('+33612345678'), '+33612345678');
    });

    test('accepte un indicatif sans +', () {
      expect(normalizePhone('33612345678'), '+33612345678');
    });

    test('rejette un numéro invalide', () {
      expect(() => normalizePhone(''), throwsFormatException);
      expect(() => normalizePhone('123'), throwsFormatException);
    });
  });

  group('isValidPhone', () {
    test('valide bénin et international', () {
      expect(isValidPhone('01 97 00 00 00'), isTrue);
      expect(isValidPhone('+33612345678'), isTrue);
    });
  });
}
