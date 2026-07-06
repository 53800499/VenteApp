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

  GlobalKey<NavigatorState>? _navigatorKey;
  VoidCallback? _onReconnectRequested;
  bool _dialogVisible = false;

  void bind({
    required GlobalKey<NavigatorState> navigatorKey,
    required VoidCallback onReconnectRequested,
  }) {
    _navigatorKey = navigatorKey;
    _onReconnectRequested = onReconnectRequested;
  }

  /// Session cloud rétablie (login ou refresh réussi).
  void markCloudSessionValid() {
    _prefs.remove(_invalidSinceKey);
  }

  /// Refresh token rejeté alors que le réseau est disponible.
  Future<void> handleInvalidRefreshToken() async {
    if (!await _networkInfo.isConnected) {
      // Hors ligne : continuer silencieusement en local.
      return;
    }

    final now = nowMs();
    final invalidSince = _prefs.getInt(_invalidSinceKey);
    if (invalidSince == null) {
      await _prefs.setInt(_invalidSinceKey, now);
      return;
    }

    final elapsedMs = now - invalidSince;
    if (elapsedMs < ApiConfig.serverAccessibleGraceMs) {
      // Période de grâce : travail local sans interruption.
      return;
    }

    await _credentials.clear();

    final context = _navigatorKey?.currentContext;
    if (context == null || !context.mounted || _dialogVisible) return;

    _dialogVisible = true;
    try {
      final reconnect = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Session cloud expirée'),
          content: const Text(
            'Votre session cloud a expiré ou a été révoquée.\n\n'
            'Vous pouvez continuer à travailler hors ligne ou vous reconnecter '
            'avec WhatsApp pour resynchroniser.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuer hors ligne'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Reconnecter'),
            ),
          ],
        ),
      );

      if (reconnect == true) {
        _onReconnectRequested?.call();
      }
    } finally {
      _dialogVisible = false;
      markCloudSessionValid();
    }
  }
}
