import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/core/errors/exception_mapper.dart';
import 'package:frontend/core/errors/failures.dart';

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
        'Le nom de la boutique doit contenir au moins 2 caractères.',
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
    test('convertit une Failure sans la modifier', () {
      const failure = UnauthorizedFailure('Code incorrect.');
      expect(friendlyErrorMessage(failure), 'Code incorrect.');
    });
  });
}
