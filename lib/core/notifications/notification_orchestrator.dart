import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/benin_day_range.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/utils/time.dart';
import '../../features/notifications/domain/entities/notification_entities.dart';
import '../../features/notifications/domain/usecases/notification_usecases.dart';
import 'local_notification_service.dart';
import 'notification_deep_link_handler.dart';

/// Orchestre l'affichage local des notifications (Module 9).
class NotificationOrchestrator {
  NotificationOrchestrator({
    required GetPendingNotifications getPending,
    required AckDebtReminderNotifications ackDebtReminders,
    required LocalNotificationService localNotifications,
    required NotificationDeepLinkHandler deepLinks,
    required SharedPreferences preferences,
  })  : _getPending = getPending,
        _ackDebtReminders = ackDebtReminders,
        _local = localNotifications,
        _deepLinks = deepLinks,
        _prefs = preferences;

  final GetPendingNotifications _getPending;
  final AckDebtReminderNotifications _ackDebtReminders;
  final LocalNotificationService _local;
  final NotificationDeepLinkHandler _deepLinks;
  final SharedPreferences _prefs;

  int? _activeShopId;

  Future<void> initialize() async {
    await _local.initialize(
      onTap: (link) => _deepLinks.store(link),
    );
  }

  void bindShop(int? shopId) {
    _activeShopId = shopId;
  }

  Future<void> processPending({int? shopId}) async {
    final id = shopId ?? _activeShopId;
    if (id == null || !_local.isAvailable) return;

    final feed = await _getPending(shopId: id);
    final dayKey = feed.debtReminderQuota.dayKey;
    var debtShown = 0;

    for (final item in feed.items) {
      if (_wasShownToday(id, dayKey, item)) continue;

      if (item.code == NotificationCode.debtReminder.label) {
        if (debtShown >= feed.debtReminderQuota.remaining) continue;
        debtShown++;
      }

      await _local.showItem(item);
      await _markShown(id, dayKey, item);
    }

    if (debtShown > 0) {
      await _ackDebtReminders(shopId: id, count: debtShown);
    }

    await _maybeShowDailySummary(id, feed);
  }

  Future<void> showDebtPaid({
    required int shopId,
    required String customerName,
    required int amount,
    int? customerId,
  }) async {
    if (!_local.isAvailable) return;

    final item = NotificationItem(
      code: NotificationCode.debtPaid.label,
      channel: 'debt',
      title: 'Dette soldée',
      body: '$customerName a remboursé ${formatFcfa(amount)}.',
      deepLink: customerId != null ? '/customers/$customerId' : '/customers',
      configurable: false,
      alwaysOn: false,
      payload: {'customerId': customerId, 'amount': amount},
    );

    await _local.showItem(
      item,
      notificationId: NotificationIds.debtPaidBase + (customerId ?? 0),
    );
  }

  NotificationDeepLinkHandler get deepLinks => _deepLinks;

  Future<void> _maybeShowDailySummary(int shopId, NotificationFeed feed) async {
    final summary = feed.dailySummary;
    if (!summary.eligible) {
      await _local.cancelDailySummary();
      return;
    }

    final dayKey = beninDayKey();
    final key = 'notif_n03_${shopId}_$dayKey';
    if (_prefs.getBool(key) == true) return;

    final parts = summary.scheduledTime.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;

    final now = DateTime.now();
    final scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (now.isBefore(scheduled)) return;

    final item = NotificationItem(
      code: NotificationCode.dailySummary.label,
      channel: 'summary',
      title: 'Résumé du jour',
      body:
          '${summary.saleCount} vente(s) · ${formatFcfa(summary.totalRevenue)} de CA.',
      deepLink: '/reports?period=today',
      configurable: true,
      alwaysOn: false,
      payload: {
        'saleCount': summary.saleCount,
        'totalRevenue': summary.totalRevenue,
      },
    );

    await _local.showItem(item, notificationId: NotificationIds.dailySummary);
    await _prefs.setBool(key, true);
  }

  bool _wasShownToday(int shopId, String dayKey, NotificationItem item) {
    if (item.alwaysOn &&
        item.code == NotificationCode.syncConflict.label) {
      final lastCount =
          _prefs.getInt(_syncConflictKey(shopId, dayKey)) ?? -1;
      final current = item.payload['count'] as int? ?? 0;
      return lastCount == current;
    }

    return _prefs.getBool(_shownKey(shopId, dayKey, item)) ?? false;
  }

  Future<void> _markShown(int shopId, String dayKey, NotificationItem item) async {
    if (item.code == NotificationCode.syncConflict.label) {
      final count = item.payload['count'] as int? ?? 0;
      await _prefs.setInt(_syncConflictKey(shopId, dayKey), count);
      return;
    }
    await _prefs.setBool(_shownKey(shopId, dayKey, item), true);
  }

  String _shownKey(int shopId, String dayKey, NotificationItem item) {
    return 'notif_${item.code}_${item.dedupeKey}_${shopId}_$dayKey';
  }

  String _syncConflictKey(int shopId, String dayKey) =>
      'notif_n07_count_${shopId}_$dayKey';
}
