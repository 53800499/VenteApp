import 'package:flutter/material.dart';

import '../network/network_info.dart';
import '../storage/auth_credentials_storage.dart';

/// Gère l'expiration du refresh token sans verrouiller l'application.
class CloudSessionCoordinator {
  CloudSessionCoordinator({
    required AuthCredentialsStorage credentials,
    required NetworkInfo networkInfo,
  })  : _credentials = credentials,
        _networkInfo = networkInfo;

  final AuthCredentialsStorage _credentials;
  final NetworkInfo _networkInfo;

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

  /// Refresh token rejeté alors que le réseau est disponible.
  Future<void> handleInvalidRefreshToken() async {
    if (!await _networkInfo.isConnected) {
      // Hors ligne : continuer silencieusement en local.
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
    }
  }
}
