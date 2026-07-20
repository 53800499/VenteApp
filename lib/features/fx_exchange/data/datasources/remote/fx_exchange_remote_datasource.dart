import 'package:dio/dio.dart';

import '../../../../../core/errors/exception_mapper.dart';
import '../../../../../core/network/api_client.dart';
import '../../models/fx_exchange_api_models.dart';

class FxExchangeRemoteDatasource {
  FxExchangeRemoteDatasource(this._client);

  final ApiClient _client;

  Future<FxModuleStatusDto> fetchStatus() async {
    final data = await _get('/fx-exchange/status');
    return FxModuleStatusDto.fromJson(data);
  }

  Future<FxModuleStatusDto> toggleModule(bool enabled) async {
    final data = await _post(
      '/fx-exchange/toggle',
      ToggleFxModuleRequest(enabled: enabled).toJson(),
    );
    return FxModuleStatusDto.fromJson(data);
  }

  Future<Map<String, dynamic>> fetchCurrencies() async {
    return _get('/fx-exchange/currencies');
  }

  Future<List<FxRateSnapshotDto>> fetchRates() async {
    final data = await _getList('/fx-exchange/rates');
    return data
        .map((e) => FxRateSnapshotDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<FxRateSnapshotDto>> fetchRateHistory({
    String? quoteCurrency,
    int limit = 100,
  }) async {
    final data = await _getList('/fx-exchange/rates/history', {
      if (quoteCurrency != null) 'quoteCurrency': quoteCurrency,
      'limit': '$limit',
    });
    return data
        .map((e) => FxRateSnapshotDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FxRateSnapshotDto> createRate(CreateFxRateRequest body) async {
    final data = await _post('/fx-exchange/rates', body.toJson());
    return FxRateSnapshotDto.fromJson(data);
  }

  Future<List<FxSessionDto>> fetchSessions() async {
    final data = await _getList('/fx-exchange/sessions');
    return data
        .map((e) => FxSessionDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FxOpenSessionStateDto> fetchOpenSession() async {
    final data = await _get('/fx-exchange/sessions/open');
    return FxOpenSessionStateDto.fromJson(data);
  }

  Future<FxSessionDto> openSession(OpenFxSessionRequest body) async {
    final data = await _post('/fx-exchange/sessions/open', body.toJson());
    return FxSessionDto.fromJson(data);
  }

  Future<FxSessionDto> closeSession(
    int sessionId,
    CloseFxSessionRequest body,
  ) async {
    final data = await _post(
      '/fx-exchange/sessions/$sessionId/close',
      body.toJson(),
    );
    return FxSessionDto.fromJson(data);
  }

  Future<FxOperationPreviewDto> previewOperation(
    PreviewFxOperationRequest body,
  ) async {
    final data = await _post('/fx-exchange/operations/preview', body.toJson());
    return FxOperationPreviewDto.fromJson(data);
  }

  Future<FxOperationDto> createOperation(
    int sessionId,
    CreateFxOperationRequest body,
  ) async {
    final data = await _post(
      '/fx-exchange/sessions/$sessionId/operations',
      body.toJson(),
    );
    return FxOperationDto.fromJson(data);
  }

  Future<List<FxOperationDto>> fetchOperations({
    int? sessionId,
    int limit = 200,
  }) async {
    final data = await _getList('/fx-exchange/operations', {
      if (sessionId != null) 'sessionId': '$sessionId',
      'limit': '$limit',
    });
    return data
        .map((e) => FxOperationDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FxMovementDto> createMovement(
    int sessionId,
    CreateFxMovementRequest body,
  ) async {
    final data = await _post(
      '/fx-exchange/sessions/$sessionId/movements',
      body.toJson(),
    );
    return FxMovementDto.fromJson(data);
  }

  Future<List<FxMovementDto>> fetchMovements({
    int? sessionId,
    int limit = 200,
  }) async {
    final data = await _getList('/fx-exchange/movements', {
      if (sessionId != null) 'sessionId': '$sessionId',
      'limit': '$limit',
    });
    return data
        .map((e) => FxMovementDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> fetchDailyReport(int sessionId) async {
    return _get('/fx-exchange/reports/daily/$sessionId');
  }

  Future<Map<String, dynamic>> _get(String path) async {
    try {
      final response = await _client.get<dynamic>(path);
      return _unwrapMap(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<List<dynamic>> _getList(
    String path, [
    Map<String, String>? query,
  ]) async {
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
      final response = await _client.post<dynamic>(path, data: body);
      return _unwrapMap(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Map<String, dynamic> _unwrapMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic>) return inner;
      return data;
    }
    throw StateError('Réponse API invalide');
  }

  List<dynamic> _unwrapList(dynamic data) {
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is List<dynamic>) return inner;
    }
    if (data is List<dynamic>) return data;
    throw StateError('Réponse API invalide');
  }
}
