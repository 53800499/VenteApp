import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:venteapp/core/errors/auth_error_humanizer.dart';
import 'package:venteapp/core/errors/exception_mapper.dart';
import 'package:venteapp/core/errors/failures.dart';

void main() {
  group('humanizeAuthErrorMessage', () {
    test('traduit une erreur duplicate key PostgreSQL', () {
      const raw =
          'duplicate key value violates unique constraint "users_name_shop_id_key"';
      final message = humanizeAuthErrorMessage(raw);

      expect(message, contains('nom'));
      expect(message, isNot(contains('duplicate key')));
    });

    test('traduit une erreur SQLite UNIQUE', () {
      const raw =
          'SqliteException(2067): UNIQUE constraint failed: settings.shop_id';
      final message = humanizeAuthErrorMessage(raw);

      expect(message, contains('boutique'));
      expect(message, isNot(contains('UNIQUE constraint')));
    });

    test('conserve un message WhatsApp déjà explicite', () {
      const raw =
          'Aucun compte associé à ce numéro. Demandez à votre patron d\'enregistrer votre WhatsApp.';
      expect(humanizeAuthErrorMessage(raw), raw);
    });
  });

  group('mapDioException — duplicate key installation', () {
    test('retourne un ConflictFailure lisible sur 409', () {
      final failure = mapDioException(
        DioException(
          requestOptions: RequestOptions(path: '/auth/setup'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/auth/setup'),
            statusCode: 409,
            data: {
              'success': false,
              'error': {
                'code': 'CONFLICT',
                'message':
                    'Ces informations existent déjà. Si la boutique a déjà été créée, connectez-vous avec WhatsApp.',
              },
            },
          ),
        ),
      );

      expect(failure, isA<ConflictFailure>());
      expect(failure.message, contains('WhatsApp'));
    });

    test('humanise settings_pkey sans accuser le nom de boutique', () {
      const raw =
          'duplicate key value violates unique constraint "settings_pkey"';
      final classified = classifySetupDuplicateMessage(raw);

      expect(classified.summary, contains('paramètres'));
      expect(classified.fieldErrors['shopName'], isNull);
    });

    test('humanise un duplicate key brut en 400', () {
      final failure = mapDioException(
        DioException(
          requestOptions: RequestOptions(path: '/auth/setup'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/auth/setup'),
            statusCode: 400,
            data: {
              'message':
                  'duplicate key value violates unique constraint "settings_shop_id_key"',
            },
          ),
        ),
      );

      expect(failure, isA<ValidationFailure>());
      expect(failure.message, contains('boutique'));
    });
  });
}
