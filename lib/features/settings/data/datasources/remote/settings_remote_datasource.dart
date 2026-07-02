import 'package:dio/dio.dart';

import '../../../../../core/errors/exception_mapper.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
import '../../models/settings_api_models.dart';

class SettingsRemoteDatasource {
  SettingsRemoteDatasource(this._client);

  final ApiClient _client;

  Future<ShopConfigurationApiDto> fetchConfiguration() async {
    final data = await _getData('/settings');
    return ShopConfigurationApiDto.fromJson(data);
  }

  Future<ShopConfigurationApiDto> updateConfiguration(
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.patch<Map<String, dynamic>>(
        '/settings',
        data: body,
      );
      final data = _unwrap(response.data);
      return ShopConfigurationApiDto.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<RecordBackupResponseApiDto> recordBackup(
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/settings/backup',
        data: body,
      );
      final data = _unwrap(response.data);
      return RecordBackupResponseApiDto.fromJson(data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<SyncSettingsApiDto> updateSyncSettings(
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.patch<Map<String, dynamic>>(
        '/settings/sync',
        data: body,
      );
      final data = _unwrap(response.data);
      return SyncSettingsApiDto.fromJson(
        data['sync'] as Map<String, dynamic>,
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
