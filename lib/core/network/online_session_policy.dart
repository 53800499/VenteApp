import 'dart:async';

import '../errors/failures.dart';

/// Déconnexion automatique uniquement quand la session en ligne n'est plus valide.
///
/// Une [NetworkFailure] (coupure réseau, serveur injoignable) ne doit jamais
/// déconnecter l'utilisateur — les modules offline-first continuent en local.
class OnlineSessionPolicy {
  OnlineSessionPolicy();

  void Function()? onSessionInvalidated;

  Timer? _invalidateTimer;
  bool _invalidationScheduled = false;

  /// Session à fermer : auth expirée ou grâce offline épuisée.
  static bool requiresLogout(Object error) {
    return error is UnauthorizedFailure ||
        error is OfflineGraceExpiredFailure;
  }

  /// Erreur réseau / serveur injoignable — pas une invalidation de session.
  static bool isNetworkUnavailable(Object error) {
    return error is NetworkFailure;
  }

  /// Erreurs à afficher à l'utilisateur (hors déconnexion silencieuse).
  static bool shouldPresentToUser(Object error) {
    if (error is Failure) {
      return !requiresLogout(error);
    }
    return true;
  }

  /// Lecture : retomber sur le cache local (Drift) si le serveur est absent.
  static bool shouldFallbackToLocal(Object error) {
    return isNetworkUnavailable(error);
  }

  void invalidate() {
    if (_invalidationScheduled || _invalidateTimer != null) return;
    _invalidateTimer = Timer(const Duration(milliseconds: 1500), () {
      _invalidateTimer = null;
      if (_invalidationScheduled) return;
      _invalidationScheduled = true;
      onSessionInvalidated?.call();
    });
  }

  void handleFailure(Object error) {
    if (isNetworkUnavailable(error)) return;
    if (requiresLogout(error)) {
      invalidate();
    }
  }

  void reset() {
    _invalidateTimer?.cancel();
    _invalidateTimer = null;
    _invalidationScheduled = false;
  }
}