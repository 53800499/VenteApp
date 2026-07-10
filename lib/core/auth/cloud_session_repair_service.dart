import 'dart:async';

import 'package:dio/dio.dart';

import 'package:flutter/foundation.dart';

import '../constants/api_config.dart';
import '../network/api_client.dart';
import '../network/network_info.dart';
import '../storage/auth_credentials_storage.dart';
import 'recent_pin_proof.dart';

/// Résultat d'une tentative de réparation de session cloud.
enum CloudRepairOutcome {
  /// Jeton d'accès encore valide — aucune action nécessaire.
  alreadyValid,

  /// Refresh JWT réussi.
  refreshed,

  /// Nouveaux JWT obtenus via login serveur par PIN.
  pinLogin,

  /// Refresh impossible et aucun PIN récent — attendre le prochain déverrouillage.
  awaitingPinUnlock,

  /// PIN récent fourni mais réparation impossible (refresh + login PIN échoués).
  failed,

  /// Hors ligne — réparation reportée.
  offline,
}

typedef PinLoginRepairCallback = Future<bool> Function(RecentPinCredential proof);

/// Répare la session cloud : refresh → login PIN (si preuve récente) → attente.
///
/// WhatsApp reste le mécanisme de récupération ultime, pas le renouvellement normal.
class CloudSessionRepairService {
  CloudSessionRepairService({
    required AuthCredentialsStorage credentials,
    required ApiClient apiClient,
    required NetworkInfo networkInfo,
    required RecentPinProof recentPinProof,
  })  : _credentials = credentials,
        _apiClient = apiClient,
        _networkInfo = networkInfo,
        _recentPinProof = recentPinProof;

  static const awaitingPinUnlockMessage =
      'Votre session en ligne a expiré. Connectez-vous à Internet pour '
      'poursuivre la synchronisation, ou saisissez votre code PIN.';

  final AuthCredentialsStorage _credentials;
  final ApiClient _apiClient;
  final NetworkInfo _networkInfo;
  final RecentPinProof _recentPinProof;

  PinLoginRepairCallback? onPinLoginRepair;
  Future<void> Function()? onSessionRestored;
  void Function()? onAwaitingPinUnlock;
  Future<void> Function()? onRepairExhausted;

  bool _awaitingPinUnlock = false;

  bool get isAwaitingPinUnlock => _awaitingPinUnlock;

  /// Notifie la UI quand l'état « en attente de déverrouillage PIN » change.
  final ValueNotifier<bool> awaitingPinUnlockNotifier = ValueNotifier(false);

  /// Notifie la UI quand la réparation/reconnexion de session est en cours.
  final ValueNotifier<bool> repairInProgressNotifier = ValueNotifier(false);

  Future<CloudRepairOutcome>? _inFlightRepair;

  void registerPinLoginRepair(PinLoginRepairCallback callback) {
    onPinLoginRepair = callback;
  }

  /// Refresh rejeté (401 sur `/auth/refresh`) — vérifie d'abord si un refresh
  /// concurrent a déjà rétabli l'accès, puis PIN si preuve récente.
  Future<CloudRepairOutcome> onRefreshTokenRejected() async {
    return _runSerialized(() async {
      if (await _credentials.hasValidAccessToken()) {
        _clearAwaiting();
        return CloudRepairOutcome.alreadyValid;
      }
      return repair(attemptRefresh: false);
    });
  }

  /// Réparation complète après déverrouillage PIN (refresh puis login PIN).
  Future<CloudRepairOutcome> repairAfterPinUnlock() {
    return _runSerialized(() => repair(attemptRefresh: true));
  }

  Future<CloudRepairOutcome> repair({required bool attemptRefresh}) async {
    if (!await _networkInfo.isConnected) {
      return CloudRepairOutcome.offline;
    }

    if (await _credentials.hasValidAccessToken()) {
      _clearAwaiting();
      return CloudRepairOutcome.alreadyValid;
    }

    if (attemptRefresh) {
      final refreshed = await _tryRefresh();
      if (refreshed) {
        _clearAwaiting();
        await onSessionRestored?.call();
        return CloudRepairOutcome.refreshed;
      }
    }

    final proof = _recentPinProof.current;
    if (proof != null) {
      final repaired = await _tryPinLogin(proof);
      if (repaired) {
        _clearAwaiting();
        await onSessionRestored?.call();
        return CloudRepairOutcome.pinLogin;
      }
      return CloudRepairOutcome.failed;
    }

    _markAwaiting();
    return CloudRepairOutcome.awaitingPinUnlock;
  }

  Future<bool> _tryRefresh() async {
    if (await _credentials.hasValidAccessToken()) return true;

    final hasRefreshLocal = await _credentials.hasValidRefreshToken();
    final withinWindow = await _credentials.isWithinServerAccessWindow();
    final storedRefresh = await _credentials.getRefreshToken();
    final hasStoredRefresh =
        storedRefresh != null && storedRefresh.isNotEmpty;

    if (!hasRefreshLocal && !withinWindow && !hasStoredRefresh) return false;

    try {
      if (hasRefreshLocal) {
        await _apiClient.refreshTokensIfNeeded();
      } else if (hasStoredRefresh) {
        await _apiClient.forceRefreshTokens();
      } else {
        return false;
      }
      return await _credentials.hasValidAccessToken();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        return false;
      }
      rethrow;
    }
  }

  /// Réparation manuelle (bannière) : enregistre le PIN puis tente refresh/login.
  Future<CloudRepairOutcome> repairWithPin({
    required String pin,
    required int serverShopId,
    required int localShopId,
    int? serverUserId,
  }) {
    _recentPinProof.record(
      pin: pin,
      serverShopId: serverShopId,
      localShopId: localShopId,
      serverUserId: serverUserId,
    );
    return repairAfterPinUnlock();
  }

  Future<bool> _tryPinLogin(RecentPinCredential proof) async {
    final repair = onPinLoginRepair;
    if (repair == null) return false;
    try {
      return await repair(proof).timeout(ApiConfig.recentPinRepairTimeout);
    } on Object {
      return false;
    }
  }

  Future<CloudRepairOutcome> _runSerialized(
    Future<CloudRepairOutcome> Function() action,
  ) async {
    final inFlight = _inFlightRepair;
    if (inFlight != null) return inFlight;

    repairInProgressNotifier.value = true;
    final future = action();
    _inFlightRepair = future;
    try {
      return await future;
    } finally {
      if (identical(_inFlightRepair, future)) {
        _inFlightRepair = null;
      }
      repairInProgressNotifier.value = false;
    }
  }

  void _markAwaiting() {
    if (_awaitingPinUnlock) return;
    _awaitingPinUnlock = true;
    awaitingPinUnlockNotifier.value = true;
    onAwaitingPinUnlock?.call();
  }

  void _clearAwaiting() {
    if (!_awaitingPinUnlock) return;
    _awaitingPinUnlock = false;
    awaitingPinUnlockNotifier.value = false;
  }

  void clearAwaitingState() => _clearAwaiting();
}
