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
      throw const UnauthorizedFailure(
        'Session en ligne requise. Reconnectez-vous avec le PIN alors que le serveur est accessible.',
      );
    }

    if (!await _credentials.hasValidAccessToken()) {
      if (!await _credentials.hasValidRefreshToken()) {
        throw const UnauthorizedFailure(
          'Session expirée. Reconnectez-vous avec votre PIN (serveur accessible).',
        );
      }
      await _apiClient.refreshTokensIfNeeded();
    }
  }
}
