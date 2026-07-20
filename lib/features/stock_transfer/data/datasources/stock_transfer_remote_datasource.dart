import 'package:dio/dio.dart';

import '../../../../../core/errors/exception_mapper.dart';
import '../../../../../core/network/api_client.dart';

class StockTransferRemoteDatasource {
  StockTransferRemoteDatasource(this._client);

  final ApiClient _client;

  Future<List<Map<String, dynamic>>> fetchOutgoing() async {
    final data = await _getData('/stock-transfers/outgoing');
    return _asListOfMaps(data);
  }

  Future<List<Map<String, dynamic>>> fetchIncoming() async {
    final data = await _getData('/stock-transfers/incoming');
    return _asListOfMaps(data);
  }

  Future<Map<String, dynamic>> fetchTransfer(int serverId) async {
    final data = await _getData('/stock-transfers/$serverId');
    return data is Map<String, dynamic> ? data : {};
  }

  Future<String> fetchNextReference() async {
    final data = await _getData('/stock-transfers/next-reference');
    if (data is String) return data;
    return data?.toString() ?? '';
  }

  Future<Map<String, dynamic>> createTransfer(Map<String, dynamic> body) async {
    final data = await _postData('/stock-transfers', body);
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> validateTransfer(int serverId) async {
    final data = await _postData('/stock-transfers/$serverId/validate', const {});
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> shipTransfer(
    int serverId,
    Map<String, dynamic> body,
  ) async {
    final data = await _postData('/stock-transfers/$serverId/ship', body);
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> receiveTransfer(
    int serverId,
    Map<String, dynamic> body,
  ) async {
    final data = await _postData('/stock-transfers/$serverId/receive', body);
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> approveTransfer(int serverId) async {
    final data = await _postData('/stock-transfers/$serverId/approve', const {});
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> submitTransfer(int serverId) async {
    final data = await _postData('/stock-transfers/$serverId/submit', const {});
    return data is Map<String, dynamic> ? data : {};
  }

  Future<List<Map<String, dynamic>>> fetchInTransit() async {
    final data = await _getData('/stock-transfers/in-transit');
    return _asListOfMaps(data);
  }

  Future<void> cancelTransfer(int serverId) async {
    await _postData('/stock-transfers/$serverId/cancel', const {});
  }

  Future<Map<String, dynamic>> closeTransfer(
    int serverId,
    Map<String, dynamic> body,
  ) async {
    final data = await _postData('/stock-transfers/$serverId/close', body);
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> resolveDiscrepancy(
    int serverId,
    Map<String, dynamic> body,
  ) async {
    final data =
        await _postData('/stock-transfers/$serverId/resolve-discrepancy', body);
    return data is Map<String, dynamic> ? data : {};
  }

  Future<dynamic> _getData(String path, {Map<String, String>? query}) async {
    try {
      final response = await _client.get(path, queryParameters: query);
      return _unwrap(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<dynamic> _postData(String path, Map<String, dynamic> body) async {
    try {
      final response = await _client.post(path, data: body);
      return _unwrap(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  dynamic _unwrap(dynamic payload) {
    if (payload is Map && payload.containsKey('data')) return payload['data'];
    return payload;
  }

  List<Map<String, dynamic>> _asListOfMaps(dynamic data) {
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().toList();
  }
}
