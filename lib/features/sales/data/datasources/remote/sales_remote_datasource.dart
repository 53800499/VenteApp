import 'package:dio/dio.dart';

import '../../../../../core/errors/exception_mapper.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
import '../../models/sale_api_models.dart';

class SalesRemoteDatasource {
  SalesRemoteDatasource(this._client);

  final ApiClient _client;

  Future<List<SaleListItemApiDto>> listSales() async {
    final data = await _getData('/sales');
    final items = data['items'] ?? data['sales'] ?? data;
    if (items is List) {
      return items
          .whereType<Map<String, dynamic>>()
          .map(SaleListItemApiDto.fromJson)
          .toList();
    }
    return [];
  }

  Future<SaleApiDto> createStandardSale(CreateStandardSaleApiRequest request) async {
    final data = await _postData('/sales', request.toJson());
    return SaleApiDto.fromJson(data);
  }

  Future<SaleApiDto> createQuickSale(Map<String, dynamic> body) async {
    final data = await _postData('/sales/quick', body);
    return SaleApiDto.fromJson(data);
  }

  Future<void> cancelSale(int saleId, {required String reason}) async {
    await _patchData('/sales/$saleId/cancel', {'reason': reason});
  }

  Future<Map<String, dynamic>> _patchData(
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

  Future<Map<String, dynamic>> _postData(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response =
          await _client.post<Map<String, dynamic>>(path, data: body);
      return _unwrap(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
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
    if (payload['success'] == true && payload['data'] is List) {
      return {'items': payload['data']};
    }
    if (payload['data'] is Map<String, dynamic>) {
      return payload['data'] as Map<String, dynamic>;
    }
    if (payload['data'] is List) {
      return {'items': payload['data']};
    }
    return payload;
  }
}
