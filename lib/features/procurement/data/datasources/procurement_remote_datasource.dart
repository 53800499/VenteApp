import 'package:dio/dio.dart';

import '../../../../../core/errors/exception_mapper.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';

class ProcurementRemoteDatasource {
  ProcurementRemoteDatasource(this._client);

  final ApiClient _client;

  Future<List<Map<String, dynamic>>> fetchSuppliers() async {
    final data = await _getData('/purchases/suppliers');
    return _asListOfMaps(data);
  }

  Future<Map<String, dynamic>> createSupplier(Map<String, dynamic> body) async {
    final data = await _postData('/purchases/suppliers', body);
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> updateSupplier(
    int serverId,
    Map<String, dynamic> body,
  ) async {
    final data = await _patchData('/purchases/suppliers/$serverId', body);
    return data is Map<String, dynamic> ? data : {};
  }

  Future<List<Map<String, dynamic>>> fetchPurchaseOrders({
    int? supplierId,
    String? status,
    int? from,
    int? to,
  }) async {
    final data = await _getData(
      '/purchases/orders',
      query: {
        if (supplierId != null) 'supplierId': '$supplierId',
        if (status != null) 'status': status,
        if (from != null) 'from': '$from',
        if (to != null) 'to': '$to',
      },
    );
    return _asListOfMaps(data);
  }

  Future<Map<String, dynamic>> fetchPurchaseOrder(int serverId) async {
    final data = await _getData('/purchases/orders/$serverId');
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> createPurchaseOrder(Map<String, dynamic> body) async {
    final data = await _postData('/purchases/orders', body);
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> updatePurchaseOrder(
    int serverId,
    Map<String, dynamic> body,
  ) async {
    final data = await _patchData('/purchases/orders/$serverId', body);
    return data is Map<String, dynamic> ? data : {};
  }

  Future<void> validatePurchaseOrder(int serverId) async {
    await _postData('/purchases/orders/$serverId/validate', const {});
  }

  Future<void> sendPurchaseOrder(int serverId) async {
    await _postData('/purchases/orders/$serverId/send', const {});
  }

  Future<void> cancelPurchaseOrder(int serverId, String? reason) async {
    await _postData(
      '/purchases/orders/$serverId/cancel',
      {if (reason != null) 'reason': reason},
    );
  }

  Future<Map<String, dynamic>> receiveItems(
    int serverId,
    Map<String, dynamic> body,
  ) async {
    final data = await _postData('/purchases/orders/$serverId/receive', body);
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> createDirectGoodsReceipt(
    Map<String, dynamic> body,
  ) async {
    final data = await _postData('/purchases/goods-receipts', body);
    return data is Map<String, dynamic> ? data : {};
  }

  Future<List<Map<String, dynamic>>> fetchDirectGoodsReceipts() async {
    final data = await _getData('/purchases/goods-receipts');
    return _asListOfMaps(data);
  }

  Future<List<Map<String, dynamic>>> fetchInvoices({int? supplierId}) async {
    final data = await _getData(
      '/purchases/invoices',
      query: {
        if (supplierId != null) 'supplierId': '$supplierId',
      },
    );
    return _asListOfMaps(data);
  }

  Future<Map<String, dynamic>> fetchInvoice(int serverId) async {
    final data = await _getData('/purchases/invoices/$serverId');
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> createInvoice(Map<String, dynamic> body) async {
    final data = await _postData('/purchases/invoices', body);
    return data is Map<String, dynamic> ? data : {};
  }

  Future<Map<String, dynamic>> recordPayment(
    int serverInvoiceId,
    Map<String, dynamic> body,
  ) async {
    final data = await _postData('/purchases/invoices/$serverInvoiceId/payments', body);
    return data is Map<String, dynamic> ? data : {};
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
