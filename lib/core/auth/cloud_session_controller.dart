import 'dart:async';

import 'package:flutter/foundation.dart';

import '../storage/auth_credentials_storage.dart';
import '../utils/time.dart';
import 'cloud_session_status.dart';

/// Source unique et réactive de l'état de session cloud (politique 3 niveaux).
///
/// Recalcule le niveau à partir du dernier contact serveur réussi, à intervalle
/// régulier et sur demande (après login, refresh, ou cycle de synchro abouti).
/// Ne bloque jamais le cœur métier : il expose seulement l'état pour la UI et
/// les gardes d'opérations « à confiance serveur ».
class CloudSessionController {
  CloudSessionController({
    required AuthCredentialsStorage credentials,
    Duration tick = const Duration(minutes: 1),
  })  : _credentials = credentials,
        _tick = tick;

  final AuthCredentialsStorage _credentials;
  final Duration _tick;

  final ValueNotifier<CloudSessionStatus> notifier =
      ValueNotifier<CloudSessionStatus>(const CloudSessionStatus.initial());

  Timer? _ticker;
  bool _startupNoticeShown = false;

  CloudSessionStatus get status => notifier.value;

  bool get allowsTrustedServerOperations =>
      status.allowsTrustedServerOperations;

  /// Avis de démarrage à présenter une seule fois par session applicative.
  bool get shouldShowStartupNotice =>
      !_startupNoticeShown && status.needsStartupNotice;

  void markStartupNoticeShown() => _startupNoticeShown = true;

  /// Démarre le rafraîchissement périodique (idempotent).
  void start() {
    _ticker ??= Timer.periodic(_tick, (_) => unawaited(refresh()));
    unawaited(refresh());
  }

  /// Enregistre un contact serveur réussi puis recalcule l'état.
  Future<void> recordContact() async {
    await _credentials.recordServerContact();
    await refresh();
  }

  /// Recalcule le niveau courant depuis le stockage sécurisé.
  Future<void> refresh() async {
    final now = nowMs();

    // Sans identifiants cloud, aucune session à valider : pas de dégradation.
    if (!await _credentials.hasCredentials()) {
      _set(CloudSessionStatus(
        level: CloudSessionLevel.online,
        lastServerContactAt: null,
        evaluatedAtMs: now,
      ));
      return;
    }

    final serverReachableNow = await _credentials.hasValidAccessToken() ||
        await _credentials.isWithinServerAccessWindow();
    final lastContact = await _credentials.getLastServerContactAt();

    final level = resolveCloudSessionLevel(
      serverReachableNow: serverReachableNow,
      lastServerContactAt: lastContact,
      nowMs: now,
    );

    _set(CloudSessionStatus(
      level: level,
      lastServerContactAt: lastContact,
      evaluatedAtMs: now,
    ));
  }

  void _set(CloudSessionStatus next) {
    // `==` ignore l'horodatage d'évaluation : ValueNotifier ne rebâtit l'UI que
    // lorsque le niveau (ou le dernier contact) change réellement.
    notifier.value = next;
  }

  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    notifier.dispose();
  }
}
