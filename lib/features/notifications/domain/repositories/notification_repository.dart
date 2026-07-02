import '../entities/notification_entities.dart';

abstract class NotificationRepository {
  Future<NotificationPreferences> getPreferences({required int shopId});

  Future<NotificationPreferences> updatePreferences({
    required int shopId,
    required UpdateNotificationSettingsInput input,
  });

  Future<NotificationFeed> getPendingFeed({required int shopId});

  Future<DebtReminderQuota> ackDebtReminders({
    required int shopId,
    required int count,
  });
}
