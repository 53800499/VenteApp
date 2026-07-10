import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/cloud_session_repair_service.dart';
import '../constants/api_config.dart';
import '../errors/exception_mapper.dart';
import '../errors/failures.dart';
import '../security/production_message_policy.dart';
import '../storage/auth_credentials_storage.dart';
import 'api_client.dart';
import 'network_info.dart';

/// Délais max pour les lectures hybrides (offline-first).
const remoteReadEnsureReadyTimeout = Duration(seconds: 75);
const remoteReadFetchTimeout = Duration(seconds: 60);

/// Vérifie que les appels API protégés peuvent être effectués.
class RemoteApiGuard {
  RemoteApiGuard({
    required NetworkInfo networkInfo,
    required AuthCredentialsStorage credentials,
    required ApiClient apiClient,
    CloudSessionRepairService? cloudSessionRepair,
  })  : _networkInfo = networkInfo,
        _credentials = credentials,
        _apiClient = apiClient,
        _cloudSessionRepair = cloudSessionRepair;

  final NetworkInfo _networkInfo;
  final AuthCredentialsStorage _credentials;
  final ApiClient _apiClient;
  final CloudSessionRepairService? _cloudSessionRepair;

  Future<void>? _readyInFlight;

  Future<void> ensureReady({
    Duration timeout = remoteReadEnsureReadyTimeout,
  }) async {
    final inFlight = _readyInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    final future = _ensureReadyWithTimeout(timeout);
    _readyInFlight = future;
    try {
      await future;
    } finally {
      if (identical(_readyInFlight, future)) {
        _readyInFlight = null;
      }
    }
  }

  Future<void> _ensureReadyWithTimeout(Duration timeout) async {
    try {
      await _ensureReady().timeout(timeout);
    } on TimeoutException {
      throw const NetworkFailure(
        'Le service met trop de temps à répondre. Données locales affichées — '
        'saisissez votre PIN via la bannière cloud pour rétablir la synchronisation.',
      );
    }
  }

  Future<void> _ensureReady() async {
    if (!await _networkInfo.isConnected) {
      throw NetworkFailure(ProductionMessagePolicy.internetRequiredMessage());
    }
    if (!await _credentials.hasCredentials()) {
      throw const CloudReconnectRequiredFailure();
    }

    if (await _credentials.hasValidAccessToken()) return;

    final repair = _cloudSessionRepair;
    if (repair != null) {
      try {
        final outcome = await repair.repair(attemptRefresh: true);
        if (outcome == CloudRepairOutcome.alreadyValid ||
            outcome == CloudRepairOutcome.refreshed ||
            outcome == CloudRepairOutcome.pinLogin) {
          return;
        }
        throw const CloudReconnectRequiredFailure();
      } on DioException catch (error) {
        final withinWindow = await _credentials.isWithinServerAccessWindow();
        throw await _mapRefreshFailure(error, withinWindow: withinWindow);
      }
    }

    final withinWindow = await _credentials.isWithinServerAccessWindow();
    final hasRefresh = await _credentials.hasValidRefreshToken();

    // Fenêtre fermée ET refresh expiré : la session est réellement terminée.
    if (!hasRefresh && !withinWindow) {
      throw const CloudReconnectRequiredFailure();
    }

    try {
      if (hasRefresh) {
        await _apiClient
            .refreshTokensIfNeeded()
            .timeout(ApiConfig.cloudRefreshAttemptTimeout);
      } else {
        await _apiClient
            .forceRefreshTokens()
            .timeout(ApiConfig.cloudRefreshAttemptTimeout);
      }
    } on TimeoutException {
      throw const CloudReconnectRequiredFailure();
    } on DioException catch (error) {
      throw await _mapRefreshFailure(error, withinWindow: withinWindow);
    }
  }

  Future<Failure> _mapRefreshFailure(
    DioException error, {
    required bool withinWindow,
  }) async {
    final failure = mapDioException(error);
    // Dans la fenêtre (ou refresh encore valide), un échec est transitoire :
    // on garde le local pour cet appel et on retentera le serveur au suivant,
    // sans déclencher de déconnexion.
    if (failure is UnauthorizedFailure &&
        (withinWindow || await _credentials.hasValidRefreshToken())) {
      return const CloudReconnectRequiredFailure();
    }
    if (failure is UnauthorizedFailure) {
      return const CloudReconnectRequiredFailure();
    }
    return failure;
  }
}
