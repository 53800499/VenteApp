import '../../domain/entities/notification_entities.dart';
import '../models/notification_api_models.dart';

class NotificationMapper {
  static NotificationPreferences preferencesFromApi(
    NotificationPreferencesApiDto dto,
  ) {
    return NotificationPreferences(
      enableStockAlerts: dto.enableStockAlerts,
      enableDebtReminders: dto.enableDebtReminders,
      debtReminderDays: dto.debtReminderDays,
      enableDailySummary: dto.enableDailySummary,
      dailySummaryTime: dto.dailySummaryTime,
      enableBackupReminder: dto.enableBackupReminder,
      enableGoodDayAlert: dto.enableGoodDayAlert,
      defaultAlertThreshold: dto.defaultAlertThreshold,
      backupLastAt: dto.backupLastAt,
    );
  }

  static DebtReminderQuota quotaFromApi(DebtReminderQuotaApiDto dto) {
    return DebtReminderQuota(
      sent: dto.sent,
      max: dto.max,
      remaining: dto.remaining,
      dayKey: dto.dayKey,
    );
  }

  static NotificationFeed feedFromApi(NotificationFeedApiDto dto) {
    return NotificationFeed(
      preferences: preferencesFromApi(dto.preferences),
      debtReminderQuota: quotaFromApi(dto.debtReminderQuota),
      dailySummary: DailySummaryPreview(
        eligible: dto.dailySummary.eligible,
        scheduledTime: dto.dailySummary.scheduledTime,
        saleCount: dto.dailySummary.saleCount,
        totalRevenue: dto.dailySummary.totalRevenue,
        reason: dto.dailySummary.reason,
      ),
      syncConflicts: SyncConflictSummary(
        count: dto.syncConflicts.count,
        entities: dto.syncConflicts.entities
            .map((e) => SyncConflictEntity(table: e.table, id: e.id))
            .toList(),
      ),
      items: dto.items.map(_itemFromApi).toList(),
      generatedAt: dto.generatedAt,
    );
  }

  static NotificationItem _itemFromApi(NotificationItemApiDto dto) {
    return NotificationItem(
      code: dto.code,
      channel: dto.channel,
      title: dto.title,
      body: dto.body,
      deepLink: dto.deepLink,
      configurable: dto.configurable,
      alwaysOn: dto.alwaysOn,
      payload: dto.payload,
    );
  }

  static Map<String, dynamic> settingsToApi(UpdateNotificationSettingsInput input) {
    return {
      if (input.enableStockAlerts != null)
        'enableStockAlerts': input.enableStockAlerts,
      if (input.enableDebtReminders != null)
        'enableDebtReminders': input.enableDebtReminders,
      if (input.debtReminderDays != null)
        'debtReminderDays': input.debtReminderDays,
      if (input.enableDailySummary != null)
        'enableDailySummary': input.enableDailySummary,
      if (input.dailySummaryTime != null)
        'dailySummaryTime': input.dailySummaryTime,
      if (input.enableBackupReminder != null)
        'enableBackupReminder': input.enableBackupReminder,
      if (input.enableGoodDayAlert != null)
        'enableGoodDayAlert': input.enableGoodDayAlert,
    };
  }
}
