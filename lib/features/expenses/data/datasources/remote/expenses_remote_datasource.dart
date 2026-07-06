import 'package:dio/dio.dart';

import '../../../../../core/errors/exception_mapper.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';

class ExpensesRemoteDatasource {
  ExpensesRemoteDatasource(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> fetchSummary() async {
    final data = await _getData('/expenses/summary');
    return data is Map<String, dynamic> ? data : {};
  }

  Future<List<Map<String, dynamic>>> fetchExpenses({
    int? from,
    int? to,
    int? categoryId,
  }) async {
    final data = await _getData(
      '/expenses',
      query: {
        if (from != null) 'from': '$from',
        if (to != null) 'to': '$to',
        if (categoryId != null) 'categoryId': '$categoryId',
      },
    );
    return _asListOfMaps(data);
  }

  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> body) async {
    final data = await _postData('/expenses', body);
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> updateExpense(
    int serverId,
    Map<String, dynamic> body,
  ) async {
    final data = await _patchData('/expenses/$serverId', body);
    return data is Map<String, dynamic> ? data : {};
  }

  Future<void> deleteExpense(int serverId) async {
    await _deleteData('/expenses/$serverId');
  }

  Future<Map<String, dynamic>> fetchExpense(int serverId) async {
    final data = await _getData('/expenses/$serverId');
    return data is Map<String, dynamic> ? data : {};
  }

  Future<List<Map<String, dynamic>>> fetchExpenseHistory(int serverId) async {
    final data = await _getData('/expenses/$serverId/history');
    return _asListOfMaps(data);
  }

  Future<void> upsertCategoryBudget(int serverCategoryId, int monthlyAmount) async {
    await _putData(
      '/expenses/categories/$serverCategoryId/budget',
      {'monthlyAmount': monthlyAmount},
    );
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final data = await _getData('/expenses/categories');
    return _asListOfMaps(data);
  }

  List<Map<String, dynamic>> _asListOfMaps(dynamic data) {
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  Future<dynamic> _getData(
    String path, {
    Map<String, String>? query,
  }) async {
    try {
      final response = await _client.get<dynamic>(
        path,
        queryParameters: query,
      );
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

  Future<dynamic> _patchData(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.patch<dynamic>(path, data: body);
      return _unwrap(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<void> _deleteData(String path) async {
    try {
      await _client.delete<dynamic>(path);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<dynamic> _putData(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.put<dynamic>(path, data: body);
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
}
