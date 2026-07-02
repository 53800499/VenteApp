import 'package:dio/dio.dart';

import '../../../../../core/errors/exception_mapper.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
import '../../models/notification_api_models.dart';

class NotificationsRemoteDatasource {
  NotificationsRemoteDatasource(this._client);

  final ApiClient _client;

  Future<NotificationPreferencesApiDto> fetchSettings() async {
    final data = await _getData('/notifications/settings');
    return NotificationPreferencesApiDto.fromJson(data);
  }

  Future<NotificationPreferencesApiDto> updateSettings(
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.patch<Map<String, dynamic>>(
        '/notifications/settings',
        data: body,
      );
      final data = _unwrap(response.data);
      return NotificationPreferencesApiDto.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<NotificationFeedApiDto> fetchPending() async {
    final data = await _getData('/notifications/pending');
    return NotificationFeedApiDto.fromJson(data);
  }

  Future<DebtReminderQuotaApiDto> ackDebtReminders(int count) async {
    if (count < 1) {
      throw const ValidationFailure('Aucun rappel à confirmer.');
    }
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/notifications/ack',
        data: {'type': 'debt_reminder', 'count': count},
      );
      final data = _unwrap(response.data);
      return DebtReminderQuotaApiDto.fromJson(
        data['debtReminderQuota'] as Map<String, dynamic>,
      );
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> _getData(String path) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(path);
      return _unwrap(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic>? payload) {
    if (payload == null) {
      throw const NetworkFailure('Réponse serveur vide.');
    }
    if (payload['success'] == true && payload['data'] is Map<String, dynamic>) {
      return payload['data'] as Map<String, dynamic>;
    }
    if (payload['data'] is Map<String, dynamic>) {
      return payload['data'] as Map<String, dynamic>;
    }
    return payload;
  }
}
