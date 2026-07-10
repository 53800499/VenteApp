import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/api_config.dart';
import '../network/network_info.dart';
import '../storage/auth_credentials_storage.dart';
import '../utils/time.dart';

/// Gère l'expiration du refresh token sans verrouiller l'application.
class CloudSessionCoordinator {
  CloudSessionCoordinator({
    required AuthCredentialsStorage credentials,
    required NetworkInfo networkInfo,
    required SharedPreferences prefs,
  })  : _credentials = credentials,
        _networkInfo = networkInfo,
        _prefs = prefs;

  static const _invalidSinceKey = 'cloud_session_invalid_since_ms';

  final AuthCredentialsStorage _credentials;
  final NetworkInfo _networkInfo;
  final SharedPreferences _prefs;

  void bind({
    required GlobalKey<NavigatorState> navigatorKey,
    required VoidCallback onReconnectRequested,
  }) {
    // Pas d'affichage de boîte de dialogue requis, donc pas d'action nécessaire.
  }

  /// Session cloud rétablie (login ou refresh réussi) : réouvre la fenêtre et
  /// enregistre le contact serveur (réinitialise la politique 3 niveaux).
  void markCloudSessionValid() {
    _prefs.remove(_invalidSinceKey);
    unawaited(_credentials.renewServerAccessWindow());
    unawaited(_credentials.recordServerContact());
  }

  /// Refresh token rejeté alors que le réseau est disponible.
  ///
  /// Par défaut n'affiche pas WhatsApp : la réparation par PIN au prochain
  /// déverrouillage est préférée. [offerWhatsAppReconnect] force le dialogue
  /// (échec après PIN récent ou action utilisateur explicite).
  Future<void> handleInvalidRefreshToken({
    bool offerWhatsAppReconnect = false,
    bool skipGrace = false,
  }) async {
    if (!await _networkInfo.isConnected) {
      // Hors ligne : continuer silencieusement en local.
      return;
    }

    // Fenêtre glissante ouverte à la connexion et renouvelée à chaque contact
    // serveur réussi : tant qu'elle est ouverte, on continue de viser le
    // serveur en permanence sans proposer de reconnexion.
    if (await _credentials.isWithinServerAccessWindow()) {
      return;
    }

    // Fenêtre fermée : plancher de grâce depuis le premier échec avant dialogue.
    final now = nowMs();
    final invalidSince = _prefs.getInt(_invalidSinceKey);
    if (invalidSince == null) {
      await _prefs.setInt(_invalidSinceKey, now);
      if (!offerWhatsAppReconnect) return;
    }

    final elapsedMs = invalidSince == null ? 0 : now - invalidSince;
    if (!offerWhatsAppReconnect && elapsedMs < ApiConfig.serverAccessibleGraceMs) {
      // Période de grâce : travail local sans interruption ni dialogue.
      return;
    }

    if (!offerWhatsAppReconnect) {
      // Pas de PIN récent : message discret via bannière, pas de WhatsApp.
      return;
    }

    if (!skipGrace && elapsedMs < ApiConfig.serverAccessibleGraceMs) {
      return;
    }

    await _credentials.clear();
  }
}
