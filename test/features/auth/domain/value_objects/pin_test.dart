import 'package:venteapp/features/auth/domain/value_objects/pin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Pin.create', () {
    test('accepte un PIN de 4 chiffres', () {
      final pin = Pin.create('1234');
      expect(pin.value, '1234');
    });

    test('accepte un PIN de 6 chiffres', () {
      final pin = Pin.create('123456');
      expect(pin.value, '123456');
    });

    test('ignore les espaces autour du PIN', () {
      final pin = Pin.create('  4321  ');
      expect(pin.value, '4321');
    });

    test('rejette un PIN trop court', () {
      expect(() => Pin.create('123'), throwsArgumentError);
    });

    test('rejette un PIN trop long', () {
      expect(() => Pin.create('1234567'), throwsArgumentError);
    });

    test('rejette les caractères non numériques', () {
      expect(() => Pin.create('12ab'), throwsArgumentError);
    });
  });
}
