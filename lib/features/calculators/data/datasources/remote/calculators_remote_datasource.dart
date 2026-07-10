import 'package:dio/dio.dart';
import '../../../../../core/errors/exception_mapper.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';

class CalculatorsRemoteDatasource {
  CalculatorsRemoteDatasource(this._client);

  final ApiClient _client;

  Future<bool> fetchModuleStatus() async {
    final response = await _getData('/calculators/status');
    if (response is Map<String, dynamic> && response.containsKey('enabled')) {
      return response['enabled'] as bool;
    }
    return false;
  }

  Future<void> toggleModule(bool enabled) async {
    await _postData('/calculators/toggle', {'enabled': enabled});
  }

  Future<List<Map<String, dynamic>>> fetchProductConfigs() async {
    final data = await _getData('/calculator-products');
    return _asListOfMaps(data);
  }

  Future<Map<String, dynamic>> saveProductConfig({
    required int productId,
    required String calculatorType,
    required Map<String, dynamic> metadata,
  }) async {
    final data = await _postData('/calculator-products', {
      'productId': productId,
      'calculatorType': calculatorType,
      'metadata': metadata,
    });
    return data is Map<String, dynamic> ? data : {};
  }

  Future<List<Map<String, dynamic>>> fetchHistory() async {
    final data = await _getData('/calculator-history');
    return _asListOfMaps(data);
  }

  Future<Map<String, dynamic>> createHistoryEntry({
    required String calculatorType,
    required Map<String, dynamic> input,
    required Map<String, dynamic> result,
    bool? isFavorite,
    String? label,
  }) async {
    final data = await _postData('/calculator-history', {
      'calculatorType': calculatorType,
      'input': input,
      'result': result,
      if (isFavorite != null) 'isFavorite': isFavorite,
      if (label != null) 'label': label,
    });
    return data is Map<String, dynamic> ? data : {};
  }

  // --- Helper Methods ---

  Future<dynamic> _getData(
    String path, {
    Map<String, String>? query,
  }) async {
    try {
      final response = await _client.get<dynamic>(path, queryParameters: query);
      return _unwrap(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<dynamic> _postData(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.post<dynamic>(path, data: body);
      return _unwrap(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  dynamic _unwrap(dynamic payload) {
    if (payload == null) {
      throw const NetworkFailure('Réponse serveur vide.');
    }
    if (payload is Map<String, dynamic>) {
      if (payload['success'] == true && payload['data'] != null) {
        return payload['data'];
      }
      if (payload.containsKey('data')) return payload['data'];
      return payload;
    }
    return payload;
  }

  List<Map<String, dynamic>> _asListOfMaps(dynamic data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }
}
