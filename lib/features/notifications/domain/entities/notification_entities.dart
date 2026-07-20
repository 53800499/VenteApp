/// Module 9 — catalogue SFD §10.2 (N-01 → N-07).
enum NotificationCode {
  stockLow('N-01'),
  debtReminder('N-02'),
  dailySummary('N-03'),
  debtPaid('N-04'),
  backupReminder('N-05'),
  goodDay('N-06'),
  syncConflict('N-07'),
  procurementOverdue('N-08'),
  procurementInvoiceDue('N-09'),
  stockTransferIncoming('N-10');

  const NotificationCode(this.label);
  final String label;

  static NotificationCode? fromLabel(String code) {
    for (final value in NotificationCode.values) {
      if (value.label == code) return value;
    }
    return null;
  }
}

class NotificationPreferences {
  const NotificationPreferences({
    required this.enableStockAlerts,
    required this.enableDebtReminders,
    required this.debtReminderDays,
    required this.enableDailySummary,
    required this.dailySummaryTime,
    required this.enableBackupReminder,
    required this.enableGoodDayAlert,
    required this.defaultAlertThreshold,
    this.backupLastAt,
  });

  final bool enableStockAlerts;
  final bool enableDebtReminders;
  final int debtReminderDays;
  final bool enableDailySummary;
  final String dailySummaryTime;
  final bool enableBackupReminder;
  final bool enableGoodDayAlert;
  final int defaultAlertThreshold;
  final int? backupLastAt;

  NotificationPreferences copyWith({
    bool? enableStockAlerts,
    bool? enableDebtReminders,
    int? debtReminderDays,
    bool? enableDailySummary,
    String? dailySummaryTime,
    bool? enableBackupReminder,
    bool? enableGoodDayAlert,
    int? defaultAlertThreshold,
    int? backupLastAt,
  }) {
    return NotificationPreferences(
      enableStockAlerts: enableStockAlerts ?? this.enableStockAlerts,
      enableDebtReminders: enableDebtReminders ?? this.enableDebtReminders,
      debtReminderDays: debtReminderDays ?? this.debtReminderDays,
      enableDailySummary: enableDailySummary ?? this.enableDailySummary,
      dailySummaryTime: dailySummaryTime ?? this.dailySummaryTime,
      enableBackupReminder:
          enableBackupReminder ?? this.enableBackupReminder,
      enableGoodDayAlert: enableGoodDayAlert ?? this.enableGoodDayAlert,
      defaultAlertThreshold:
          defaultAlertThreshold ?? this.defaultAlertThreshold,
      backupLastAt: backupLastAt ?? this.backupLastAt,
    );
  }
}

class DebtReminderQuota {
  const DebtReminderQuota({
    required this.sent,
    required this.max,
    required this.remaining,
    required this.dayKey,
  });

  final int sent;
  final int max;
  final int remaining;
  final String dayKey;
}

class DailySummaryPreview {
  const DailySummaryPreview({
    required this.eligible,
    required this.scheduledTime,
    required this.saleCount,
    required this.totalRevenue,
    this.reason,
  });

  final bool eligible;
  final String scheduledTime;
  final int saleCount;
  final int totalRevenue;
  final String? reason;
}

class SyncConflictSummary {
  const SyncConflictSummary({
    required this.count,
    required this.entities,
  });

  final int count;
  final List<SyncConflictEntity> entities;
}

class SyncConflictEntity {
  const SyncConflictEntity({required this.table, required this.id});

  final String table;
  final int id;
}

class NotificationItem {
  const NotificationItem({
    required this.code,
    required this.channel,
    required this.title,
    required this.body,
    required this.deepLink,
    required this.configurable,
    required this.alwaysOn,
    required this.payload,
  });

  final String code;
  final String channel;
  final String title;
  final String body;
  final String deepLink;
  final bool configurable;
  final bool alwaysOn;
  final Map<String, dynamic> payload;

  String get dedupeKey {
    if (code == NotificationCode.debtReminder.label) {
      return '${payload['customerId'] ?? payload['debtId']}';
    }
    if (code == NotificationCode.syncConflict.label) {
      return '${payload['count'] ?? entitiesCount}';
    }
    return code;
  }

  int get entitiesCount => payload['count'] as int? ?? 0;
}

class NotificationFeed {
  const NotificationFeed({
    required this.preferences,
    required this.debtReminderQuota,
    required this.dailySummary,
    required this.syncConflicts,
    required this.items,
    required this.generatedAt,
  });

  final NotificationPreferences preferences;
  final DebtReminderQuota debtReminderQuota;
  final DailySummaryPreview dailySummary;
  final SyncConflictSummary syncConflicts;
  final List<NotificationItem> items;
  final int generatedAt;
}

class UpdateNotificationSettingsInput {
  const UpdateNotificationSettingsInput({
    this.enableStockAlerts,
    this.enableDebtReminders,
    this.debtReminderDays,
    this.enableDailySummary,
    this.dailySummaryTime,
    this.enableBackupReminder,
    this.enableGoodDayAlert,
  });

  final bool? enableStockAlerts;
  final bool? enableDebtReminders;
  final int? debtReminderDays;
  final bool? enableDailySummary;
  final String? dailySummaryTime;
  final bool? enableBackupReminder;
  final bool? enableGoodDayAlert;
}

const maxDebtRemindersPerDay = 3;
const backupReminderAgeMs = 7 * 24 * 60 * 60 * 1000;
