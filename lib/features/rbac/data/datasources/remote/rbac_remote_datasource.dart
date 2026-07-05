import 'package:dio/dio.dart';

import '../../../../../core/errors/exception_mapper.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
import '../../models/rbac_api_models.dart';

class RbacRemoteDatasource {
  RbacRemoteDatasource(this._client);

  final ApiClient _client;

  Future<List<RoleCatalogItemDto>> listRoles() async {
    final data = await _getList('/rbac/roles');
    return data.map(RoleCatalogItemDto.fromJson).toList();
  }

  Future<RoleCatalogItemDto> getRole(String code) async {
    final data = await _getMap('/rbac/roles/$code');
    return RoleCatalogItemDto.fromJson(data);
  }

  Future<PermissionsCatalogDto> getPermissionsCatalog() async {
    final data = await _getMap('/rbac/permissions');
    return PermissionsCatalogDto.fromJson(data);
  }

  Future<MyPermissionsDto> getMyPermissions() async {
    final data = await _getMap('/rbac/me');
    return MyPermissionsDto.fromJson(data);
  }

  Future<bool> checkPermission(String permissionCode) async {
    final data = await _getMap('/rbac/check/$permissionCode');
    return data['granted'] as bool? ?? false;
  }

  Future<UserEffectivePermissionsDto> getUserPermissions(int userId) async {
    final data = await _getMap('/rbac/users/$userId/permissions');
    return UserEffectivePermissionsDto.fromJson(data);
  }

  Future<List<UserPermissionOverrideDto>> listUserOverrides(int userId) async {
    final data = await _getList('/rbac/users/$userId/overrides');
    return data.map(UserPermissionOverrideDto.fromJson).toList();
  }

  Future<ReplaceOverridesResultDto> replaceUserOverrides({
    required int userId,
    required List<UserPermissionOverrideDto> overrides,
    String? reason,
  }) async {
    final data = await _putMap(
      '/rbac/users/$userId/permissions',
      {
        'overrides': [
          for (final o in overrides)
            {
              'permissionCode': o.permissionCode,
              'effect': o.effect,
              if (o.reason != null && o.reason!.isNotEmpty) 'reason': o.reason,
              if (o.expiresAt != null) 'expiresAt': o.expiresAt,
            },
        ],
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return ReplaceOverridesResultDto.fromJson(data);
  }

  Future<RoleCatalogItemDto> createShopRole(Map<String, dynamic> body) async {
    final data = await _postMap('/rbac/roles', body);
    return RoleCatalogItemDto.fromJson(data);
  }

  Future<RoleCatalogItemDto> updateShopRole(
    String code,
    Map<String, dynamic> body,
  ) async {
    final data = await _patchMap('/rbac/roles/$code', body);
    return RoleCatalogItemDto.fromJson(data);
  }

  Future<void> deleteShopRole(String code) async {
    await _delete('/rbac/roles/$code');
  }

  Future<RoleCatalogItemDto> setRolePermissions(
    String code,
    List<Map<String, dynamic>> permissions,
  ) async {
    final data = await _putMap(
      '/rbac/roles/$code/permissions',
      {'permissions': permissions},
    );
    return RoleCatalogItemDto.fromJson(data);
  }

  Future<Map<String, dynamic>> _postMap(
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

  Future<Map<String, dynamic>> _patchMap(
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

  Future<void> _delete(String path) async {
    try {
      await _client.delete<void>(path);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> _getMap(String path) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(path);
      return _unwrapMap(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<List<Map<String, dynamic>>> _getList(String path) async {
    try {
      final response = await _client.get<dynamic>(path);
      return _unwrapList(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> _putMap(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response =
          await _client.put<Map<String, dynamic>>(path, data: body);
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
