import '../entities/notification_entities.dart';
import '../repositories/notification_repository.dart';

class GetNotificationPreferences {
  const GetNotificationPreferences(this._repository);

  final NotificationRepository _repository;

  Future<NotificationPreferences> call({required int shopId}) {
    return _repository.getPreferences(shopId: shopId);
  }
}

class UpdateNotificationPreferences {
  const UpdateNotificationPreferences(this._repository);

  final NotificationRepository _repository;

  Future<NotificationPreferences> call({
    required int shopId,
    required UpdateNotificationSettingsInput input,
  }) {
    return _repository.updatePreferences(shopId: shopId, input: input);
  }
}

class GetPendingNotifications {
  const GetPendingNotifications(this._repository);

  final NotificationRepository _repository;

  Future<NotificationFeed> call({required int shopId}) {
    return _repository.getPendingFeed(shopId: shopId);
  }
}

class AckDebtReminderNotifications {
  const AckDebtReminderNotifications(this._repository);

  final NotificationRepository _repository;

  Future<DebtReminderQuota> call({
    required int shopId,
    required int count,
  }) {
    return _repository.ackDebtReminders(shopId: shopId, count: count);
  }
}
