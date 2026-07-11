import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/di/injection_container.dart';
import 'local_notification_service.dart';

/// Affiche une explication en français avant la demande système.
class NotificationPermissionPrompter {
  NotificationPermissionPrompter({
    LocalNotificationService? localNotifications,
    SharedPreferences? preferences,
  })  : _local = localNotifications ?? sl<LocalNotificationService>(),
        _preferences = preferences;

  final LocalNotificationService _local;
  final SharedPreferences? _preferences;

  static const _promptedKey = 'notification_permission_prompted_v1';

  Future<void> maybePrompt(BuildContext context) async {
    if (!context.mounted || !_local.isAvailable) return;
    if (!await _local.needsPermissionRequest()) return;
    if (!context.mounted) return;

    final prefs = _preferences ?? await SharedPreferences.getInstance();
    if (!context.mounted) return;
    if (prefs.getBool(_promptedKey) == true) {
      await _local.requestSystemPermission();
      return;
    }

    final allow = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Autoriser les notifications'),
        content: const Text(
          'ARIKE peut vous alerter pour le stock faible, les rappels '
          'de dettes et le résumé du jour — même sans connexion internet.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Plus tard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Autoriser'),
          ),
        ],
      ),
    );

    await prefs.setBool(_promptedKey, true);
    if (allow == true && context.mounted) {
      await _local.requestSystemPermission();
    }
  }
}
