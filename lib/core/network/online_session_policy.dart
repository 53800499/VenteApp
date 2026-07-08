import 'dart:async';

import '../errors/failures.dart';

/// Politique session cloud — le JWT ne déclenche jamais le verrouillage PIN.
class OnlineSessionPolicy {
  OnlineSessionPolicy();

  /// Ne plus déconnecter ni verrouiller automatiquement l'application.
  void Function()? onCloudSessionExpired;

  Timer? _notifyTimer;
  bool _notifyScheduled = false;

  /// Le JWT / refresh expiré n'est plus une déconnexion locale.
  static bool requiresLogout(Object error) => false;

  /// Erreur réseau / serveur injoignable — pas une invalidation de session.
  static bool isNetworkUnavailable(Object error) {
    return error is NetworkFailure;
  }

  /// Erreurs à afficher à l'utilisateur.
  static bool shouldPresentToUser(Object error) {
    if (error is Failure) {
      return error is! UnauthorizedFailure;
    }
    return true;
  }

  /// Lecture : retomber sur le cache local (Drift) si le serveur est absent.
  static bool shouldFallbackToLocal(Object error) {
    return isNetworkUnavailable(error) ||
        error is CloudReconnectRequiredFailure ||
        error is UnauthorizedFailure ||
        error is OfflineGraceExpiredFailure;
  }

  void notifyCloudSessionExpired() {
    if (_notifyScheduled || _notifyTimer != null) return;
    _notifyTimer = Timer(const Duration(milliseconds: 800), () {
      _notifyTimer = null;
      if (_notifyScheduled) return;
      _notifyScheduled = true;
      onCloudSessionExpired?.call();
    });
  }

  void handleFailure(Object error) {
    if (isNetworkUnavailable(error)) return;
    if (error is CloudReconnectRequiredFailure) return;
    if (error is UnauthorizedFailure || error is OfflineGraceExpiredFailure) {
      notifyCloudSessionExpired();
    }
  }

  void reset() {
    _notifyTimer?.cancel();
    _notifyTimer = null;
    _notifyScheduled = false;
  }
}
