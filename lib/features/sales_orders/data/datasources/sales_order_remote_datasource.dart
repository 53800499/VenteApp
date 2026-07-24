import '../../../../core/network/api_client.dart';
import '../../../../core/utils/time.dart';

/// Client API commandes clients (sync / push / pull).
class SalesOrderRemoteDatasource {
  SalesOrderRemoteDatasource(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> createOrder(
    Map<String, dynamic> body,
  ) async {
    final response = await _api.post('/sales-orders', data: body);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> confirmOrder(
    String serverId, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _api.post(
      '/sales-orders/$serverId/confirm',
      data: body ?? {},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> prepareOrder(
    String serverId, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _api.post(
      '/sales-orders/$serverId/prepare',
      data: body ?? {},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> deliver(
    String serverId,
    Map<String, dynamic> body,
  ) async {
    final response =
        await _api.post('/sales-orders/$serverId/deliver', data: body);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> cancelOrder(
    String serverId, {
    String? reason,
    Map<String, dynamic>? body,
  }) async {
    final response = await _api.post(
      '/sales-orders/$serverId/cancel',
      data: {
        'reason': reason,
        'at': nowMs(),
        ...?body,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> closeOrder(
    String serverId, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _api.post(
      '/sales-orders/$serverId/close',
      data: body ?? {},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getOrder(String serverId) async {
    final response = await _api.get('/sales-orders/$serverId');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> listOrders({
    int? updatedAfter,
  }) async {
    final response = await _api.get(
      '/sales-orders',
      queryParameters: {
        if (updatedAfter != null) 'updatedAfter': '$updatedAfter',
      },
    );
    final data = response.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return const [];
  }
}
