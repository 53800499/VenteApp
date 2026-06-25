import 'package:dio/dio.dart';

import '../../../../../core/errors/exception_mapper.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
import '../../models/shop_api_models.dart';

class ShopRemoteDatasource {
  ShopRemoteDatasource(this._client);

  final ApiClient _client;

  Future<ShopListDataDto> listShops() async {
    final data = await _getData('/shops');
    return ShopListDataDto.fromJson(data);
  }

  Future<ShopDetailDto> getShop(int id) async {
    final data = await _getData('/shops/$id');
    return ShopDetailDto.fromJson(data);
  }

  Future<ShopDetailDto> createShop({
    required String name,
    String? address,
    String? phone,
  }) async {
    final data = await _postData(
      '/shops',
      {
        'name': name,
        if (address != null && address.isNotEmpty) 'address': address,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      },
    );
    return ShopDetailDto.fromJson(data);
  }

  Future<ShopDetailDto> updateShop(
    int id, {
    String? name,
    String? address,
    String? phone,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (address != null) body['address'] = address;
    if (phone != null) body['phone'] = phone;

    final data = await _patchData('/shops/$id', body);
    return ShopDetailDto.fromJson(data);
  }

  Future<void> deactivateShop(int id, {String? reason}) async {
    await _patchData(
      '/shops/$id/deactivate',
      {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  Future<void> setDefaultShop(int id) async {
    await _postData('/shops/$id/set-default', {});
  }

  Future<Map<String, dynamic>> _getData(String path) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(path);
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
