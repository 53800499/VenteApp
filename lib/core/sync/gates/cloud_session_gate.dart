import 'dart:async';

import '../../network/api_client.dart';
import '../../storage/auth_credentials_storage.dart';

/// États possibles de la porte d'entrée Cloud (CloudSessionGate).
enum CloudSessionStatus {
  /// Le cloud est prêt et les jetons JWT sont valides.
  cloudReady,

  /// Rafraîchissement des jetons en cours.
  refreshing,

  /// Restauration automatique d'appareil nécessaire / en cours.
  deviceRestore,

  /// Pause Cloud : Le cloud est inaccessible ou la session ne peut pas être rétablie
  /// sans déconnecter le marchand. L'application reste 100% fonctionnelle hors-ligne.
  /// AUCUN dialogue PIN ne doit être demandé par le moteur de synchronisation.
  pauseCloud,
}

/// Porte de contrôle de session Cloud pour le moteur de synchronisation ARIKE.
///
/// **Règle Absolue d'Architecture** :
/// Une erreur de synchronisation cloud ne doit JAMAIS déclencher un verrouillage
/// d'écran local ni réclamer de PIN. Le PIN appartient exclusivement à `AppLockController`.
class CloudSessionGate {
  CloudSessionGate({
    required ApiClient apiClient,
    AuthCredentialsStorage? credentialsStorage,
  })  : _apiClient = apiClient,
        _credentialsStorage = credentialsStorage;

  final ApiClient _apiClient;
  final AuthCredentialsStorage? _credentialsStorage;

  CloudSessionStatus _currentStatus = CloudSessionStatus.pauseCloud;
  DateTime? _lastCheckTime;

  CloudSessionStatus get currentStatus => _currentStatus;
  bool get isCloudReady => _currentStatus == CloudSessionStatus.cloudReady;
  DateTime? get lastCheckTime => _lastCheckTime;

  /// Évalue l'état de la session cloud de manière totalement silencieuse (zéro écran PIN).
  Future<CloudSessionStatus> evaluateSession() async {
    final credentials = _credentialsStorage;
    if (credentials == null || !_apiClient.isConfigured) {
      _currentStatus = CloudSessionStatus.pauseCloud;
      return _currentStatus;
    }

    try {
      final hasValidAccess = await credentials.hasValidAccessToken();
      if (hasValidAccess) {
        _currentStatus = CloudSessionStatus.cloudReady;
        _lastCheckTime = DateTime.now();
        return _currentStatus;
      }

      // Tentative de refresh de jeton si le refresh token est disponible
      final hasRefreshToken = await credentials.hasValidRefreshToken();
      if (hasRefreshToken) {
        _currentStatus = CloudSessionStatus.refreshing;
        await _apiClient.refreshTokensIfNeeded();
        if (await credentials.hasValidAccessToken()) {
          _currentStatus = CloudSessionStatus.cloudReady;
          _lastCheckTime = DateTime.now();
          return _currentStatus;
        }
      }

      // Tenter une restauration forcée si on est dans la fenêtre de grâce serveur
      if (await credentials.isWithinServerAccessWindow()) {
        _currentStatus = CloudSessionStatus.deviceRestore;
        await _apiClient.forceRefreshTokens();
        if (await credentials.hasValidAccessToken()) {
          _currentStatus = CloudSessionStatus.cloudReady;
          _lastCheckTime = DateTime.now();
          return _currentStatus;
        }
      }

      // Si aucune tentative n'a pu restaurer le jeton, basculer silencieusement en PAUSE CLOUD
      _currentStatus = CloudSessionStatus.pauseCloud;
      return _currentStatus;
    } catch (_) {
      // En cas d'exception réseau ou d'échec 401 sur le refresh, basculer en PAUSE CLOUD
      // sans bloquer la caisse ni réclamer de PIN local.
      _currentStatus = CloudSessionStatus.pauseCloud;
      return _currentStatus;
    }
  }

  /// Réinitialise l'état pour forcer une nouvelle évaluation lors de la prochaine boucle.
  void invalidate() {
    _lastCheckTime = null;
    _currentStatus = CloudSessionStatus.pauseCloud;
  }
}
