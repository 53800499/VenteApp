import 'package:dio/dio.dart';

import '../errors/exception_mapper.dart';
import '../errors/failures.dart';
import '../storage/auth_credentials_storage.dart';
import 'api_client.dart';
import 'network_info.dart';

/// Vérifie que les appels API protégés peuvent être effectués.
class RemoteApiGuard {
  RemoteApiGuard({
    required NetworkInfo networkInfo,
    required AuthCredentialsStorage credentials,
    required ApiClient apiClient,
  })  : _networkInfo = networkInfo,
        _credentials = credentials,
        _apiClient = apiClient;

  final NetworkInfo _networkInfo;
  final AuthCredentialsStorage _credentials;
  final ApiClient _apiClient;

  Future<void> ensureReady() async {
    if (!await _networkInfo.isConnected) {
      throw const NetworkFailure(
        'Connexion internet requise. Vérifiez le réseau et l\'adresse du serveur (Plus → Connexion serveur).',
      );
    }
    if (!await _credentials.hasCredentials()) {
      throw const NetworkFailure(
        'Session en ligne indisponible. Données locales affichées — '
        'reconnectez le serveur et saisissez votre PIN.',
      );
    }

    if (!await _credentials.hasValidAccessToken()) {
      if (!await _credentials.hasValidRefreshToken()) {
        throw const UnauthorizedFailure(
          'Session expirée. Reconnectez-vous avec votre PIN (serveur accessible).',
        );
      }
      try {
        await _apiClient.refreshTokensIfNeeded();
      } on DioException catch (error) {
        throw await _mapRefreshFailure(error);
      }
    }
  }

  Future<Failure> _mapRefreshFailure(DioException error) async {
    final failure = mapDioException(error);
    if (failure is UnauthorizedFailure &&
        await _credentials.hasValidRefreshToken()) {
      return const NetworkFailure(
        'Serveur temporairement injoignable. Les données locales restent '
        'disponibles — synchronisation à la reconnexion.',
      );
    }
    return failure;
  }
}
