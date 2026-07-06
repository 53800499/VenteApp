import 'package:dio/dio.dart';

import '../../../../../core/errors/exception_mapper.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
import '../../models/cash_session_api_models.dart';

class CashSessionsRemoteDatasource {
  CashSessionsRemoteDatasource(this._client);

  final ApiClient _client;

  Future<List<CashSessionApiDto>> fetchSessions({int limit = 50}) async {
    final data = await _getList('/cash-sessions', {'limit': '$limit'});
    return data
        .map((e) => CashSessionApiDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CashSessionApiDto> openSession(OpenCashSessionApiRequest body) async {
    final data = await _post('/cash-sessions/open', body.toJson());
    return CashSessionApiDto.fromJson(data);
  }

  Future<CashSessionApiDto> closeSession(
    int sessionId,
    CloseCashSessionApiRequest body,
  ) async {
    final data = await _post('/cash-sessions/$sessionId/close', body.toJson());
    return CashSessionApiDto.fromJson(data);
  }

  Future<CashSessionApiDto> createSession(CashSessionApiDto body) async {
    final data = await _post('/cash-sessions', body.toJson());
    return CashSessionApiDto.fromJson(data);
  }

  Future<CashSessionApiDto> updateSession(
    int serverId,
    CashSessionApiDto body,
  ) async {
    final data = await _patch('/cash-sessions/$serverId', body.toJson());
    return CashSessionApiDto.fromJson(data);
  }

  Future<List<CashMovementApiDto>> fetchMovements({int limit = 200}) async {
    final data = await _getList('/cash-movements', {'limit': '$limit'});
    return data
        .map((e) => CashMovementApiDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CashMovementApiDto> createMovement(
    int sessionServerId,
    CreateCashMovementApiRequest body,
  ) async {
    final data = await _post(
      '/cash-sessions/$sessionServerId/movements',
      body.toJson(),
    );
    return CashMovementApiDto.fromJson(data);
  }

  Future<List<dynamic>> _getList(String path, Map<String, String> query) async {
    try {
      final response = await _client.get<dynamic>(
        path,
        queryParameters: query,
      );
      return _unwrapList(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(path, data: body);
      return _unwrap(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> _patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response =
          await _client.patch<Map<String, dynamic>>(path, data: body);
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

  List<dynamic> _unwrapList(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      if (payload['success'] == true && payload['data'] is List) {
        return payload['data'] as List;
      }
      if (payload['data'] is List) return payload['data'] as List;
    }
    if (payload is List) return payload;
    return const [];
  }
}
