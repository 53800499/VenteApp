import 'dart:async';

import 'package:dio/dio.dart';

import '../auth/cloud_session_repair_service.dart';
import '../errors/exception_mapper.dart';
import '../errors/failures.dart';
import '../storage/auth_credentials_storage.dart';
import 'api_client.dart';
import 'network_info.dart';

/// Délais max pour les lectures hybrides (offline-first).
const remoteReadEnsureReadyTimeout = Duration(seconds: 8);
const remoteReadFetchTimeout = Duration(seconds: 10);

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

  Future<void> ensureReady({
    Duration timeout = remoteReadEnsureReadyTimeout,
  }) async {
    try {
      await _ensureReady().timeout(timeout);
    } on TimeoutException {
      throw const NetworkFailure(
        'Serveur trop lent ou injoignable. Données locales affichées.',
      );
    }
  }

  Future<void> _ensureReady() async {
    if (!await _networkInfo.isConnected) {
      throw const NetworkFailure(
        'Connexion internet requise. Vérifiez le réseau et l\'adresse du serveur (Plus → Connexion serveur).',
      );
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
      // Pendant la fenêtre de grâce, on continue de viser le serveur : on
      // retente le refresh même si l'expiration locale est dépassée.
      if (hasRefresh) {
        await _apiClient.refreshTokensIfNeeded();
      } else {
        await _apiClient.forceRefreshTokens();
      }
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
