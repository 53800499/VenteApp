class NotificationPreferencesApiDto {
  NotificationPreferencesApiDto({
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

  factory NotificationPreferencesApiDto.fromJson(Map<String, dynamic> json) {
    return NotificationPreferencesApiDto(
      enableStockAlerts: json['enableStockAlerts'] as bool? ?? true,
      enableDebtReminders: json['enableDebtReminders'] as bool? ?? true,
      debtReminderDays: (json['debtReminderDays'] as num?)?.toInt() ?? 7,
      enableDailySummary: json['enableDailySummary'] as bool? ?? true,
      dailySummaryTime: json['dailySummaryTime'] as String? ?? '20:00',
      enableBackupReminder: json['enableBackupReminder'] as bool? ?? true,
      enableGoodDayAlert: json['enableGoodDayAlert'] as bool? ?? true,
      defaultAlertThreshold:
          (json['defaultAlertThreshold'] as num?)?.toInt() ?? 5,
      backupLastAt: (json['backupLastAt'] as num?)?.toInt(),
    );
  }

  final bool enableStockAlerts;
  final bool enableDebtReminders;
  final int debtReminderDays;
  final bool enableDailySummary;
  final String dailySummaryTime;
  final bool enableBackupReminder;
  final bool enableGoodDayAlert;
  final int defaultAlertThreshold;
  final int? backupLastAt;
}

class DebtReminderQuotaApiDto {
  DebtReminderQuotaApiDto({
    required this.sent,
    required this.max,
    required this.remaining,
    required this.dayKey,
  });

  factory DebtReminderQuotaApiDto.fromJson(Map<String, dynamic> json) {
    return DebtReminderQuotaApiDto(
      sent: (json['sent'] as num).toInt(),
      max: (json['max'] as num).toInt(),
      remaining: (json['remaining'] as num).toInt(),
      dayKey: json['dayKey'] as String,
    );
  }

  final int sent;
  final int max;
  final int remaining;
  final String dayKey;
}

class NotificationFeedApiDto {
  NotificationFeedApiDto({
    required this.preferences,
    required this.debtReminderQuota,
    required this.dailySummary,
    required this.syncConflicts,
    required this.items,
    required this.generatedAt,
  });

  factory NotificationFeedApiDto.fromJson(Map<String, dynamic> json) {
    return NotificationFeedApiDto(
      preferences: NotificationPreferencesApiDto.fromJson(
        json['preferences'] as Map<String, dynamic>,
      ),
      debtReminderQuota: DebtReminderQuotaApiDto.fromJson(
        json['debtReminderQuota'] as Map<String, dynamic>,
      ),
      dailySummary: DailySummaryPreviewApiDto.fromJson(
        json['dailySummary'] as Map<String, dynamic>,
      ),
      syncConflicts: SyncConflictSummaryApiDto.fromJson(
        json['syncConflicts'] as Map<String, dynamic>,
      ),
      items: (json['items'] as List<dynamic>? ?? [])
          .map(
            (e) => NotificationItemApiDto.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      generatedAt: (json['generatedAt'] as num).toInt(),
    );
  }

  final NotificationPreferencesApiDto preferences;
  final DebtReminderQuotaApiDto debtReminderQuota;
  final DailySummaryPreviewApiDto dailySummary;
  final SyncConflictSummaryApiDto syncConflicts;
  final List<NotificationItemApiDto> items;
  final int generatedAt;
}

class DailySummaryPreviewApiDto {
  DailySummaryPreviewApiDto({
    required this.eligible,
    required this.scheduledTime,
    required this.saleCount,
    required this.totalRevenue,
    this.reason,
  });

  factory DailySummaryPreviewApiDto.fromJson(Map<String, dynamic> json) {
    return DailySummaryPreviewApiDto(
      eligible: json['eligible'] as bool? ?? false,
      scheduledTime: json['scheduledTime'] as String? ?? '20:00',
      saleCount: (json['saleCount'] as num?)?.toInt() ?? 0,
      totalRevenue: (json['totalRevenue'] as num?)?.toInt() ?? 0,
      reason: json['reason'] as String?,
    );
  }

  final bool eligible;
  final String scheduledTime;
  final int saleCount;
  final int totalRevenue;
  final String? reason;
}

class SyncConflictSummaryApiDto {
  SyncConflictSummaryApiDto({
    required this.count,
    required this.entities,
  });

  factory SyncConflictSummaryApiDto.fromJson(Map<String, dynamic> json) {
    return SyncConflictSummaryApiDto(
      count: (json['count'] as num?)?.toInt() ?? 0,
      entities: (json['entities'] as List<dynamic>? ?? [])
          .map(
            (e) => SyncConflictEntityApiDto.fromJson(
              e as Map<String, dynamic>,
            ),
          )
          .toList(),
    );
  }

  final int count;
  final List<SyncConflictEntityApiDto> entities;
}

class SyncConflictEntityApiDto {
  SyncConflictEntityApiDto({required this.table, required this.id});

  factory SyncConflictEntityApiDto.fromJson(Map<String, dynamic> json) {
    return SyncConflictEntityApiDto(
      table: json['table'] as String,
      id: (json['id'] as num).toInt(),
    );
  }

  final String table;
  final int id;
}

class NotificationItemApiDto {
  NotificationItemApiDto({
    required this.code,
    required this.channel,
    required this.title,
    required this.body,
    required this.deepLink,
    required this.configurable,
    required this.alwaysOn,
    required this.payload,
  });

  factory NotificationItemApiDto.fromJson(Map<String, dynamic> json) {
    return NotificationItemApiDto(
      code: json['code'] as String,
      channel: json['channel'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      deepLink: json['deepLink'] as String,
      configurable: json['configurable'] as bool? ?? true,
      alwaysOn: json['alwaysOn'] as bool? ?? false,
      payload: Map<String, dynamic>.from(
        json['payload'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  final String code;
  final String channel;
  final String title;
  final String body;
  final String deepLink;
  final bool configurable;
  final bool alwaysOn;
  final Map<String, dynamic> payload;
}
