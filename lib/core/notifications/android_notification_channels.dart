import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Canaux Android — RG-NOTIF-02.
abstract final class AndroidNotificationChannels {
  static const stock = AndroidNotificationChannel(
    'venteapp_stock',
    'Alertes stock',
    description: 'Produits en stock faible',
    importance: Importance.defaultImportance,
  );

  static const debt = AndroidNotificationChannel(
    'venteapp_debt',
    'Rappels dettes',
    description: 'Dettes clients en retard',
    importance: Importance.high,
  );

  static const summary = AndroidNotificationChannel(
    'venteapp_summary',
    'Résumés',
    description: 'Résumé journalier et records',
    importance: Importance.defaultImportance,
  );

  static const system = AndroidNotificationChannel(
    'venteapp_system',
    'Système',
    description: 'Sauvegarde et maintenance',
    importance: Importance.low,
  );

  static const sync = AndroidNotificationChannel(
    'venteapp_sync',
    'Synchronisation',
    description: 'Conflits de synchronisation (toujours actif)',
    importance: Importance.high,
  );

  static const all = [stock, debt, summary, system, sync];

  static String channelIdFor(String channel) => switch (channel) {
        'stock' => stock.id,
        'debt' => debt.id,
        'summary' => summary.id,
        'system' => system.id,
        'sync' => sync.id,
        _ => system.id,
      };
}
