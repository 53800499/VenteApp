import 'package:dio/dio.dart';

import '../../../../../core/errors/exception_mapper.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';

import '../../models/inventory_api_models.dart';



class InventoryRemoteDatasource {

  InventoryRemoteDatasource(this._client);



  final ApiClient _client;



  Future<List<CategoryApiDto>> listCategories({bool activeOnly = false}) async {

    final data = await _getData(

      '/categories',

      query: activeOnly ? {'activeOnly': 'true'} : null,

    );

    return _mapList(data, CategoryApiDto.fromJson);

  }



  Future<CategoryApiDto> createCategory({

    required String name,

    String? description,

    int sortOrder = 0,

  }) async {

    final data = await _postData('/categories', {

      'name': name,

      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),

      if (sortOrder > 0) 'sortOrder': sortOrder,

    });

    return CategoryApiDto.fromJson(data);

  }



  Future<CategoryApiDto> updateCategory(

    int id, {

    String? name,

    String? description,

    bool? isActive,

    int? sortOrder,

  }) async {

    final body = <String, dynamic>{};

    if (name != null) body['name'] = name;

    if (description != null) body['description'] = description.trim().isEmpty ? null : description.trim();

    if (isActive != null) body['isActive'] = isActive;

    if (sortOrder != null) body['sortOrder'] = sortOrder;

    final data = await _patchData('/categories/$id', body);

    return CategoryApiDto.fromJson(data);

  }



  Future<List<ProductApiDto>> listProducts({
    bool includeArchived = false,
  }) async {
    final data = await _getData(
      '/products',
      query: {
        if (includeArchived) 'includeArchived': 'true',
      },
    );

    return _mapList(data, ProductApiDto.fromJson);

  }



  Future<ProductApiDto> createProduct(Map<String, dynamic> body) async {

    final data = await _postData('/products', body);

    return ProductApiDto.fromJson(data);

  }



  Future<ProductApiDto> updateProduct(

    int id,

    Map<String, dynamic> body,

  ) async {

    final data = await _patchData('/products/$id', body);

    return ProductApiDto.fromJson(data);

  }



  Future<void> archiveProduct(int id) async {

    await _patchData('/products/$id/archive', {});

  }



  Future<void> adjustStock(int productId, Map<String, dynamic> body) async {

    await _postData('/products/$productId/stock-adjustments', body);

  }



  List<T> _mapList<T>(

    Map<String, dynamic> data,

    T Function(Map<String, dynamic>) mapper,

  ) {

    final items = data['items'] ?? data['products'] ?? data['categories'] ?? data;

    if (items is List) {

      return items.whereType<Map<String, dynamic>>().map(mapper).toList();

    }

    return [];

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


