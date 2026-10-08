import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/security/production_message_policy.dart';

void main() {
  group('ProductionMessagePolicy.sanitize', () {
    test('purges DioException [bad response] and technical status codes', () {
      const raw =
          "Le module 'PROCUREMENT' n'est pas inclus dans votre forfait d'abonnement actuel (FREE) Veuillez mettre à niveau votre abonnement pour y acceder. DioException [bad response]: The request returned an invalid status code of 403.";

      final result = ProductionMessagePolicy.sanitize(raw);

      expect(result, isNot(contains('DioException')));
      expect(result, isNot(contains('bad response')));
      expect(result, isNot(contains('invalid status code')));
      expect(result, contains("Le module 'PROCUREMENT' n'est pas inclus dans votre forfait"));
    });

    test('replaces pure DioException 403 with friendly French fallback', () {
      const raw = 'DioException [bad response]: The request returned an invalid status code of 403.';

      final result = ProductionMessagePolicy.sanitize(raw);

      expect(result, isNot(contains('DioException')));
      expect(result, isNot(contains('403')));
      expect(result, contains('Cette action n’est pas autorisée ou n’est pas incluse dans votre forfait'));
    });

    test('replaces exact Dio 5.x bad response exception message', () {
      const raw =
          'DioException [bad response]: This exception was thrown because the response has a status code of 403 and RequestOptions.validateStatus was configured to throw for this status code.';

      final result = ProductionMessagePolicy.sanitize(raw);

      expect(result, isNot(contains('DioException')));
      expect(result, isNot(contains('bad response')));
      expect(result, isNot(contains('This exception was thrown')));
      expect(result, isNot(contains('403')));
      expect(result, isNot(contains('validateStatus')));
      expect(result, contains('Cette action n’est pas autorisée ou n’est pas incluse dans votre forfait'));
    });

    test('replaces pure 500 server crash with reassuring French fallback', () {
      const raw = 'DioException [bad response]: The request returned an invalid status code of 500.';

      final result = ProductionMessagePolicy.sanitize(raw);

      expect(result, isNot(contains('DioException')));
      expect(result, isNot(contains('500')));
      expect(result, contains('Le service en ligne rencontre une indisponibilité momentanée'));
    });

    test('purges stack traces and hostnames', () {
      const raw =
          'Erreur survenue. #0 ApiClient.post package:frontend/core/network/api_client.dart:150 https://api.arike.app/purchases';

      final result = ProductionMessagePolicy.sanitize(raw);

      expect(result, isNot(contains('ApiClient.post')));
      expect(result, isNot(contains('package:')));
      expect(result, isNot(contains('https://')));
      expect(result, contains('Erreur survenue.'));
    });
  });
}
