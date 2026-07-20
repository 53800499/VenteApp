import 'dart:async';

import 'package:dio/dio.dart';
import 'package:sqlite3/sqlite3.dart';

import '../security/production_message_policy.dart';
import 'auth_error_humanizer.dart';
import 'api_error_humanizer.dart';
import 'failures.dart';

/// Convertit toute exception en message lisible pour l'utilisateur.
String friendlyErrorMessage(Object error) {
  if (error is Failure) {
    return ProductionMessagePolicy.sanitize(
      humanizeAuthErrorMessage(error.message),
    );
  }
  if (error is TimeoutException) {
    return ProductionMessagePolicy.sanitize(
      humanizeAuthErrorMessage(
        'Le service met trop de temps à répondre. Réessayez.',
      ),
    );
  }
  if (error is DioException) {
    return ProductionMessagePolicy.sanitize(mapDioException(error).message);
  }
  if (error is SqliteException) {
    return ProductionMessagePolicy.sanitize(
      humanizeAuthErrorMessage(error.message),
    );
  }
  return ProductionMessagePolicy.sanitize(
    humanizeAuthErrorMessage(error.toString()),
  );
}

/// Convertit une [DioException] en [Failure] métier.
Failure mapDioException(DioException error) {
  if (error.type == DioExceptionType.connectionError ||
      error.type == DioExceptionType.connectionTimeout ||
      error.type == DioExceptionType.receiveTimeout ||
      error.type == DioExceptionType.sendTimeout) {
    final host = error.requestOptions.uri.host;
    final isLocalHost = host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '10.0.2.2';
    return NetworkFailure(
      ProductionMessagePolicy.networkUnreachableMessage(
        localDevelopmentContext: isLocalHost,
      ),
    );
  }

  final statusCode = error.response?.statusCode;
  final body = error.response?.data;

  if (body is Map<String, dynamic>) {
    final apiError = body['error'];
    if (apiError is Map<String, dynamic>) {
      final failure = _mapApiErrorPayload(apiError, statusCode);
      if (failure != null) return failure;
    }

    final message = body['message'];
    if (message is List) {
      final texts = message.whereType<String>().where((m) => m.isNotEmpty).toList();
      if (texts.isNotEmpty) {
        return ValidationFailure(humanizeApiErrorMessage(texts.first));
      }
    }
    if (message is Map<String, dynamic>) {
      if (message['requiresEmergencyRecovery'] == true) {
        return const EmergencyRecoveryRequiredFailure();
      }
      if (message['remainingAttempts'] is int) {
        return InvalidPinFailure(message['remainingAttempts'] as int);
      }
      if (message['lockedUntil'] is int &&
          message['remainingSeconds'] is int) {
        return AccountLockedFailure(
          lockedUntil: message['lockedUntil'] as int,
          remainingSeconds: message['remainingSeconds'] as int,
        );
      }
      final text = message['message'];
      if (text is String && text.isNotEmpty) {
        return UnauthorizedFailure(text);
      }
    }
    if (message is String && message.isNotEmpty) {
      final human = humanizeAuthErrorMessage(message);
      if (statusCode == 409) {
        return _conflictFailure(human, body);
      }
      if (statusCode == 404) return NotFoundFailure(human);
      if (statusCode == 403) return UnauthorizedFailure(human);
      if (statusCode == 401) {
        return UnauthorizedFailure(
          human == message
              ? 'Session expirée. Saisissez votre PIN de connexion.'
              : human,
        );
      }
      if (statusCode == 400) return ValidationFailure(human);
      return UnauthorizedFailure(human);
    }
    final errorField = body['error'];
    if (errorField is String && errorField.isNotEmpty) {
      return UnauthorizedFailure(humanizeApiErrorMessage(errorField));
    }
  }

  if (body is String && body.isNotEmpty) {
    return UnauthorizedFailure(humanizeApiErrorMessage(body));
  }

  return NetworkFailure(_httpStatusMessage(statusCode));
}

String _httpStatusMessage(int? statusCode) {
  return switch (statusCode) {
    400 => 'Données invalides. Vérifiez votre saisie.',
    401 => 'Session expirée. Saisissez votre PIN de connexion.',
    403 => 'Action non autorisée.',
    404 => 'Boutique ou utilisateur introuvable.',
    409 => 'Conflit avec des données déjà enregistrées sur le cloud.',
    422 => 'Informations incorrectes. Vérifiez votre saisie.',
    429 => 'Trop de tentatives. Patientez avant de réessayer.',
    500 => 'Le service en ligne a rencontré une erreur. Réessayez.',
    502 || 503 || 504 => 'Service temporairement indisponible.',
    _ => 'Erreur réseau. Réessayez.',
  };
}

Failure? _mapApiErrorPayload(Map<String, dynamic> apiError, int? statusCode) {
  final details = apiError['details'];
  final fieldErrors = _extractSetupFieldErrors(details is Map<String, dynamic> ? details : null) ??
      _extractSetupFieldErrors(apiError);

  if (fieldErrors != null && fieldErrors.isNotEmpty) {
    final message = apiError['message'] is String
        ? humanizeAuthErrorMessage(apiError['message'] as String)
        : 'Corrigez les champs signalés avant de continuer.';
    return SetupFieldConflictFailure(message: message, fieldErrors: fieldErrors);
  }

  if (details is Map<String, dynamic>) {
    final errors = details['errors'];
    if (errors is List) {
      final texts = errors.whereType<String>().where((m) => m.isNotEmpty).toList();
      if (texts.isNotEmpty) {
        return ValidationFailure(_humanizeValidationMessage(texts.first));
      }
    }
  }

  final message = apiError['message'];
  if (message is String && message.isNotEmpty) {
    final human = humanizeAuthErrorMessage(message);
    if (statusCode == 400) {
      return ValidationFailure(
        human == message && message == 'Données invalides.'
            ? 'Données invalides. Vérifiez votre saisie.'
            : human,
      );
    }
    if (statusCode == 409) {
      return _conflictFailure(human, details is Map<String, dynamic> ? details : null);
    }
    if (statusCode == 404) return NotFoundFailure(human);
    if (statusCode == 403) return UnauthorizedFailure(human);
    if (statusCode == 401) {
      return UnauthorizedFailure(
        human == message
            ? 'Session expirée. Saisissez votre PIN de connexion.'
            : human,
      );
    }
    return UnauthorizedFailure(human);
  }

  return null;
}

String _humanizeValidationMessage(String raw) {
  return humanizeApiErrorMessage(humanizeAuthErrorMessage(raw));
}

Map<String, String>? _extractSetupFieldErrors(Map<String, dynamic>? source) {
  if (source == null) return null;

  final fields = source['fields'];
  if (fields is Map<String, dynamic>) {
    return fields.map((key, value) => MapEntry(key, '$value'));
  }

  final conflicts = source['conflicts'];
  if (conflicts is List) {
    final result = <String, String>{};
    for (final item in conflicts) {
      if (item is Map<String, dynamic>) {
        final field = item['field']?.toString();
        final message = item['message']?.toString();
        if (field != null && message != null && message.isNotEmpty) {
          result[field] = message;
        }
      }
    }
    if (result.isNotEmpty) return result;
  }

  return null;
}

Failure _conflictFailure(String message, Map<String, dynamic>? details) {
  final fieldErrors = _extractSetupFieldErrors(details);
  if (fieldErrors != null && fieldErrors.isNotEmpty) {
    return SetupFieldConflictFailure(
      message: message,
      fieldErrors: fieldErrors,
    );
  }

  final classified = classifySetupDuplicateMessage(message);
  if (classified.fieldErrors.isNotEmpty) {
    return SetupFieldConflictFailure(
      message: classified.summary,
      fieldErrors: classified.fieldErrors,
    );
  }

  return ConflictFailure(message);
}
