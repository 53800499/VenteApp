import 'package:dio/dio.dart';

import 'failures.dart';

/// Convertit toute exception en message lisible pour l'utilisateur.
String friendlyErrorMessage(Object error) {
  if (error is Failure) return error.message;
  if (error is DioException) return mapDioException(error).message;
  return 'Une erreur inattendue est survenue. Réessayez.';
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
    final hint = isLocalHost
        ? ' Démarrez le backend (port 3010). Sur téléphone physique, configurez l\'adresse du serveur dans Plus → Connexion serveur.'
        : ' Vérifiez l\'adresse dans Plus → Connexion serveur.';
    return NetworkFailure(
      'Impossible de joindre le serveur (${error.requestOptions.baseUrl}).$hint',
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
        return ValidationFailure(texts.first);
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
      if (statusCode == 409) return ConflictFailure(message);
      if (statusCode == 404) return NotFoundFailure(message);
      if (statusCode == 403) return UnauthorizedFailure(message);
      if (statusCode == 401) {
        return const UnauthorizedFailure(
          'Session expirée. Reconnectez-vous avec votre PIN (serveur accessible).',
        );
      }
      return UnauthorizedFailure(message);
    }
    final errorField = body['error'];
    if (errorField is String && errorField.isNotEmpty) {
      return UnauthorizedFailure(errorField);
    }
  }

  if (body is String && body.isNotEmpty) {
    return UnauthorizedFailure(body);
  }

  return NetworkFailure(_httpStatusMessage(statusCode));
}

String _httpStatusMessage(int? statusCode) {
  return switch (statusCode) {
    400 => 'Données invalides. Vérifiez votre saisie.',
    401 => 'Session expirée. Reconnectez-vous avec votre PIN (serveur accessible).',
    403 => 'Action non autorisée.',
    404 => 'Boutique ou utilisateur introuvable.',
    409 => 'Une boutique existe déjà sur ce serveur. Utilisez « Se connecter » si vous êtes employé.',
    422 => 'Informations incorrectes. Vérifiez votre saisie.',
    429 => 'Trop de tentatives. Patientez avant de réessayer.',
    500 => 'Erreur serveur. Réessayez plus tard.',
    502 || 503 || 504 => 'Service temporairement indisponible.',
    _ => 'Erreur réseau. Réessayez.',
  };
}

Failure? _mapApiErrorPayload(Map<String, dynamic> apiError, int? statusCode) {
  final details = apiError['details'];
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
    if (statusCode == 400) {
      return ValidationFailure(
        message == 'Données invalides.'
            ? 'Données invalides. Vérifiez votre saisie.'
            : message,
      );
    }
    if (statusCode == 409) return ConflictFailure(message);
    if (statusCode == 404) return NotFoundFailure(message);
    if (statusCode == 403) return UnauthorizedFailure(message);
    if (statusCode == 401) {
      return const UnauthorizedFailure(
        'Session expirée. Reconnectez-vous avec votre PIN (serveur accessible).',
      );
    }
    return UnauthorizedFailure(message);
  }

  return null;
}

String _humanizeValidationMessage(String raw) {
  final normalized = raw.toLowerCase();
  if (normalized.contains('name') &&
      (normalized.contains('short') ||
          normalized.contains('longer than') ||
          normalized.contains('minlength'))) {
    return 'Le nom de la boutique doit contenir au moins 2 caractères.';
  }
  if (normalized.contains('row-level security') ||
      normalized.contains('violates row-level security')) {
    return 'Création refusée par le serveur. Redémarrez le backend puis réessayez.';
  }
  return raw;
}
