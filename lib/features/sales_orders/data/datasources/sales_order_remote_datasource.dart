import '../../../../core/network/api_client.dart';
import '../../../../core/utils/time.dart';

/// Client API commandes clients (sync / push / pull).
class SalesOrderRemoteDatasource {
  SalesOrderRemoteDatasource(this._api);

  final ApiClient _api;

  dynamic _unwrap(dynamic payload) {
    if (payload == null) return null;
    if (payload is Map<String, dynamic>) {
      if (payload['success'] == true && payload.containsKey('data')) {
        return payload['data'];
      }
      return payload;
    }
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      if (map['success'] == true && map.containsKey('data')) {
        return map['data'];
      }
      return map;
    }
    return payload;
  }

  Future<Map<String, dynamic>> createOrder(
    Map<String, dynamic> body,
  ) async {
    final response = await _api.post('/sales-orders', data: body);
    final data = _unwrap(response.data);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> confirmOrder(
    String serverId, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _api.post(
      '/sales-orders/$serverId/confirm',
      data: body ?? {},
    );
    final data = _unwrap(response.data);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> prepareOrder(
    String serverId, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _api.post(
      '/sales-orders/$serverId/prepare',
      data: body ?? {},
    );
    final data = _unwrap(response.data);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> deliver(
    String serverId,
    Map<String, dynamic> body,
  ) async {
    final response =
        await _api.post('/sales-orders/$serverId/deliver', data: body);
    final data = _unwrap(response.data);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
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
    final data = _unwrap(response.data);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> closeOrder(
    String serverId, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _api.post(
      '/sales-orders/$serverId/close',
      data: body ?? {},
    );
    final data = _unwrap(response.data);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<Map<String, dynamic>> getOrder(String serverId) async {
    final response = await _api.get('/sales-orders/$serverId');
    final data = _unwrap(response.data);
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
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
    final data = _unwrap(response.data);
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
