import 'package:dio/dio.dart';

import '../../../../../core/errors/exception_mapper.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
import '../../../domain/entities/audit_entities.dart';
import '../../mappers/audit_mapper.dart';
import '../../models/audit_api_models.dart';

class AuditRemoteDatasource {
  AuditRemoteDatasource(this._client, this._mapper);

  final ApiClient _client;
  final AuditMapper _mapper;

  Future<AuditLogListApiDto> listLogs(AuditListQuery query) async {
    final data = await _getData('/audit', query: _mapper.queryToApi(query));
    return AuditLogListApiDto.fromJson(data);
  }

  Future<AuditLogDetailApiDto> getDetail(int id) async {
    final data = await _getData('/audit/$id');
    return AuditLogDetailApiDto.fromJson(data);
  }

  Future<AuditFilterOptionsApiDto> getFilterOptions() async {
    final data = await _getData('/audit/filters');
    return AuditFilterOptionsApiDto.fromJson(data);
  }

  Future<AuditExportApiDto> exportLogs(AuditListQuery query) async {
    final params = _mapper.queryToApi(query);
    params['format'] = 'json';
    final data = await _getData('/audit/export', query: params);
    return AuditExportApiDto.fromJson(data);
  }

  Future<AuditEntityHistoryApiDto> getEntityHistory({
    required String entityTable,
    required int entityId,
  }) async {
    final data = await _getData('/audit/entities/$entityTable/$entityId');
    return AuditEntityHistoryApiDto.fromJson(data);
  }

  Future<Map<String, dynamic>> _getData(
    String path, {
    Map<String, String>? query,
  }) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        path,
        queryParameters: query,
      );
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
