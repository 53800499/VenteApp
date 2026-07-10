import '../errors/failures.dart';
import '../security/production_message_policy.dart';
import 'api_module_category.dart';
import 'network_info.dart';
import 'online_session_policy.dart';
import 'remote_api_guard.dart';

/// Point d'entrée unique pour les appels API selon la catégorie du module.
class RemoteApiRunner {
  RemoteApiRunner({
    required RemoteApiGuard apiGuard,
    required OnlineSessionPolicy sessionPolicy,
    required NetworkInfo networkInfo,
  })  : _apiGuard = apiGuard,
        _sessionPolicy = sessionPolicy,
        _networkInfo = networkInfo;

  final RemoteApiGuard _apiGuard;
  final OnlineSessionPolicy _sessionPolicy;
  final NetworkInfo _networkInfo;

  /// Serveur préféré — lecture : tente le remote, sinon [localFallback].
  ///
  /// Une absence de JWT (première connexion post-install) ne doit pas
  /// déconnecter : on affiche le cache local.
  Future<T> runOnlinePreferredRead<T>({
    required Future<T> Function() remote,
    required Future<T> Function() localFallback,
  }) async {
    try {
      await _apiGuard.ensureReady();
      return await remote();
    } catch (error) {
      try {
        return await localFallback();
      } catch (_) {
        if (OnlineSessionPolicy.requiresLogout(error)) {
          _sessionPolicy.handleFailure(error);
        }
        if (error is Failure) rethrow;
        throw NetworkFailure('$error');
      }
    }
  }

  /// Serveur obligatoire — écriture admin (équipe, boutiques, etc.).
  Future<T> runOnlineRequiredWrite<T>({
    required Future<T> Function() remote,
    String? offlineMessage,
  }) async {
    final message =
        offlineMessage ?? ProductionMessagePolicy.onlineActionRequiredMessage();
    if (!await _networkInfo.isConnected) {
      throw NetworkFailure(message);
    }
    try {
      await _apiGuard.ensureReady();
      return await remote();
    } catch (error) {
      if (OnlineSessionPolicy.requiresLogout(error)) {
        _sessionPolicy.handleFailure(error);
      }
      rethrow;
    }
  }

  /// Offline-first — tente le remote si possible, sinon exécute [onOffline].
  Future<T> runOfflineCapable<T>({
    required Future<T> Function() remote,
    required Future<T> Function() onOffline,
    ApiModuleCategory category = ApiModuleCategory.offlineFirst,
  }) async {
    assert(category != ApiModuleCategory.onlinePreferred);
    try {
      await _apiGuard.ensureReady();
      return await remote();
    } catch (error) {
      if (OnlineSessionPolicy.isNetworkUnavailable(error) ||
          OnlineSessionPolicy.requiresLogout(error) ||
          (error is Failure && !OnlineSessionPolicy.requiresLogout(error))) {
        return onOffline();
      }
      _sessionPolicy.handleFailure(error);
      if (error is Failure) rethrow;
      return onOffline();
    }
  }

  /// Hybride — enrichissement serveur optionnel après lecture locale.
  Future<void> tryRemoteRefresh({
    required Future<void> Function() remote,
  }) async {
    try {
      await _apiGuard.ensureReady();
      await remote();
    } catch (_) {
      // Silencieux : les données locales restent affichées, pas de déconnexion.
    }
  }
}
