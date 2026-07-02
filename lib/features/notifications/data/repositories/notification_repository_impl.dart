import '../../../../core/network/remote_api_runner.dart';
import '../../../../core/utils/benin_day_range.dart';
import '../../domain/entities/notification_entities.dart';
import '../../domain/repositories/notification_repository.dart';
import '../../domain/services/notification_feed_builder.dart';
import '../datasources/local/notifications_local_datasource.dart';
import '../datasources/remote/notifications_remote_datasource.dart';
import '../mappers/notification_mapper.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  NotificationRepositoryImpl({
    required NotificationsLocalDatasource local,
    required NotificationsRemoteDatasource remote,
    required RemoteApiRunner apiRunner,
    required NotificationFeedBuilder feedBuilder,
  })  : _local = local,
        _remote = remote,
        _apiRunner = apiRunner,
        _feedBuilder = feedBuilder;

  final NotificationsLocalDatasource _local;
  final NotificationsRemoteDatasource _remote;
  final RemoteApiRunner _apiRunner;
  final NotificationFeedBuilder _feedBuilder;

  static const _writeOfflineMessage =
      'Modification impossible hors ligne. Réessayez à la reconnexion.';

  @override
  Future<NotificationPreferences> getPreferences({required int shopId}) async {
    return _apiRunner.runOnlinePreferredRead(
      remote: () async {
        final remote = await _remote.fetchSettings();
        return NotificationMapper.preferencesFromApi(remote);
      },
      localFallback: () => _local.loadPreferences(shopId),
    );
  }

  @override
  Future<NotificationPreferences> updatePreferences({
    required int shopId,
    required UpdateNotificationSettingsInput input,
  }) async {
    return _apiRunner.runOnlineRequiredWrite(
      offlineMessage: _writeOfflineMessage,
      remote: () async {
        final remote = await _remote.updateSettings(
          NotificationMapper.settingsToApi(input),
        );
        await _local.updatePreferences(shopId: shopId, input: input);
        return NotificationMapper.preferencesFromApi(remote);
      },
    );
  }

  @override
  Future<NotificationFeed> getPendingFeed({required int shopId}) async {
    return _apiRunner.runOnlinePreferredRead(
      remote: () async {
        final remote = await _remote.fetchPending();
        return NotificationMapper.feedFromApi(remote);
      },
      localFallback: () => _feedBuilder.build(shopId: shopId),
    );
  }

  @override
  Future<DebtReminderQuota> ackDebtReminders({
    required int shopId,
    required int count,
  }) async {
    return _apiRunner.runOnlinePreferredRead(
      remote: () async {
        final remote = await _remote.ackDebtReminders(count);
        return NotificationMapper.quotaFromApi(remote);
      },
      localFallback: () async {
        final dayKey = beninDayKey();
        return _local.incrementDebtRemindersSent(
          shopId: shopId,
          dayKey: dayKey,
          count: count,
        );
      },
    );
  }
}
