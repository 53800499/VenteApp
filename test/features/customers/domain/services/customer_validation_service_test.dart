import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/errors/failures.dart';
import 'package:venteapp/features/customers/domain/services/customer_validation_service.dart';

void main() {
  const service = CustomerValidationService();

  group('CustomerValidationService', () {
    test('accepte un nom valide', () {
      expect(() => service.assertName('Kossi Mensah'), returnsNormally);
    });

    test('rejette un nom trop court (RG-CLI-01)', () {
      expect(
        () => service.assertName('A'),
        throwsA(isA<ValidationFailure>()),
      );
    });

    test('refuse l\'archivage avec dettes ouvertes (RG-CLI-03)', () {
      expect(
        () => service.assertCanArchive(2),
        throwsA(isA<ConflictFailure>()),
      );
    });

    test('autorise l\'archivage sans dette ouverte', () {
      expect(() => service.assertCanArchive(0), returnsNormally);
    });

    test('avertit si téléphone manquant ou incomplet', () {
      expect(service.phoneWarning(null), isNotNull);
      expect(service.phoneWarning('123'), isNotNull);
      expect(service.phoneWarning('+22990123456'), isNull);
    });
  });
}
