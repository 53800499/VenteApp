import 'package:dio/dio.dart';

import '../../../../../core/errors/exception_mapper.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
import '../../models/user_api_models.dart';

class UserRemoteDatasource {
  UserRemoteDatasource(this._client);

  final ApiClient _client;

  Future<List<ShopUserItemDto>> listShopUsers() async {
    final data = await _getListData('/users');
    return data
        .map((e) => ShopUserItemDto.fromJson(e))
        .toList();
  }

  Future<UserAssignmentDto> getUserAssignment(int userId) async {
    final data = await _getData('/users/$userId/assignment');
    return UserAssignmentDto.fromJson(data);
  }

  Future<CreateShopUserResponseDto> createShopUser({
    required String name,
    required String phone,
    required String pin,
    required String roleCode,
  }) async {
    final data = await _postData(
      '/users',
      {
        'name': name,
        'phone': phone,
        'pin': pin,
        'role': roleCode,
      },
    );
    return CreateShopUserResponseDto.fromJson(data);
  }

  Future<ChangeUserRoleResponseDto> changeUserRole({
    required int userId,
    required String roleCode,
    String? reason,
  }) async {
    final data = await _patchData(
      '/users/$userId/role',
      {
        'role': roleCode,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return ChangeUserRoleResponseDto.fromJson(data);
  }

  Future<void> deactivateUser(int userId, {String? reason}) async {
    await _patchData(
      '/users/$userId/deactivate',
      {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
  }

  Future<void> assignUserShop({
    required int userId,
    required int shopId,
    String? reason,
  }) async {
    await _patchData(
      '/users/$userId/shop',
      {
        'shopId': shopId,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  Future<Map<String, dynamic>> _getData(String path) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(path);
      return _unwrapMap(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<List<Map<String, dynamic>>> _getListData(String path) async {
    try {
      final response = await _client.get<dynamic>(path);
      return _unwrapList(response.data);
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
      return _unwrapMap(response.data);
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
      return _unwrapMap(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Map<String, dynamic> _unwrapMap(Map<String, dynamic>? payload) {
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

  List<Map<String, dynamic>> _unwrapList(dynamic payload) {
    if (payload == null) {
      throw const NetworkFailure('Réponse serveur vide.');
    }
    if (payload is Map<String, dynamic>) {
      final data = payload['data'];
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      }
    }
    if (payload is List) {
      return payload.cast<Map<String, dynamic>>();
    }
    throw const NetworkFailure('Format de liste invalide.');
  }
}
