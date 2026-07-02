import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:venteapp/core/errors/exception_mapper.dart';
import 'package:venteapp/core/errors/failures.dart';

void main() {
  group('mapDioException', () {
    test('ne renvoie pas le message technique Dio sur une 400', () {
      final failure = mapDioException(
        DioException(
          requestOptions: RequestOptions(path: '/auth/pin/login'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/auth/pin/login'),
            statusCode: 400,
          ),
        ),
      );

      expect(failure, isA<NetworkFailure>());
      expect(failure.message, 'Données invalides. Vérifiez votre saisie.');
      expect(failure.message, isNot(contains('validateStatus')));
    });

    test('extrait le format erreur API NestJS (error.message)', () {
      final failure = mapDioException(
        DioException(
          requestOptions: RequestOptions(path: '/shops'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/shops'),
            statusCode: 400,
            data: {
              'success': false,
              'error': {
                'code': 'VALIDATION_ERROR',
                'message': 'Données invalides.',
                'details': {
                  'errors': ['name must be longer than or equal to 2 characters'],
                },
              },
            },
          ),
        ),
      );

      expect(failure, isA<ValidationFailure>());
      expect(
        failure.message,
        'Le nom doit contenir au moins 2 caractères.',
      );
    });

    test('extrait un PIN invalide structuré', () {
      final failure = mapDioException(
        DioException(
          requestOptions: RequestOptions(path: '/auth/pin/login'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/auth/pin/login'),
            statusCode: 400,
            data: {
              'message': {'remainingAttempts': 3},
            },
          ),
        ),
      );

      expect(failure, isA<InvalidPinFailure>());
      expect(failure.message, contains('3'));
    });
  });

  group('friendlyErrorMessage', () {
    test('humanise une Failure auth', () {
      const failure = ConflictFailure(
        'duplicate key value violates unique constraint "users_name_shop_id_key"',
      );
      final message = friendlyErrorMessage(failure);
      expect(message, contains('nom'));
      expect(message, isNot(contains('duplicate key')));
    });
  });
}
