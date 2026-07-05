import '../../../../core/errors/failures.dart';
import '../../../../core/network/remote_api_runner.dart';
import '../../domain/entities/rbac_entities.dart';
import '../../domain/repositories/rbac_repository.dart';
import '../datasources/remote/rbac_remote_datasource.dart';
import '../models/rbac_api_models.dart';

class RbacRepositoryImpl implements RbacRepository {
  RbacRepositoryImpl({
    required RbacRemoteDatasource remote,
    required RemoteApiRunner apiRunner,
  })  : _remote = remote,
        _apiRunner = apiRunner;

  final RbacRemoteDatasource _remote;
  final RemoteApiRunner _apiRunner;

  static const _offlineMessage =
      'Connexion serveur requise pour consulter les rôles et permissions.';

  @override
  Future<List<RoleCatalogItem>> listRoles() {
    return _apiRunner.runOnlinePreferredRead(
      remote: () async {
        final items = await _remote.listRoles();
        return items.map((dto) => dto.toEntity()).toList();
      },
      localFallback: () => throw const NetworkFailure(_offlineMessage),
    );
  }

  @override
  Future<RoleCatalogItem> getRole(String code) {
    return _apiRunner.runOnlineRequiredWrite(
      offlineMessage: _offlineMessage,
      remote: () async => (await _remote.getRole(code)).toEntity(),
    );
  }

  @override
  Future<PermissionsCatalog> getPermissionsCatalog() {
    return _apiRunner.runOnlinePreferredRead(
      remote: () async => (await _remote.getPermissionsCatalog()).toEntity(),
      localFallback: () => throw const NetworkFailure(_offlineMessage),
    );
  }

  @override
  Future<MyPermissions> getMyPermissions() {
    return _apiRunner.runOnlineRequiredWrite(
      offlineMessage: _offlineMessage,
      remote: () async => (await _remote.getMyPermissions()).toEntity(),
    );
  }

  @override
  Future<UserEffectivePermissions> getUserPermissions(int userId) {
    return _apiRunner.runOnlinePreferredRead(
      remote: () async =>
          (await _remote.getUserPermissions(userId)).toEntity(),
      localFallback: () => throw const NetworkFailure(_offlineMessage),
    );
  }

  @override
  Future<List<UserPermissionOverride>> listUserOverrides(int userId) {
    return _apiRunner.runOnlinePreferredRead(
      remote: () async {
        final items = await _remote.listUserOverrides(userId);
        return items.map((dto) => dto.toEntity()).toList();
      },
      localFallback: () => throw const NetworkFailure(_offlineMessage),
    );
  }

  @override
  Future<ReplaceOverridesResult> replaceUserOverrides({
    required int userId,
    required List<UserPermissionOverride> overrides,
    String? reason,
  }) {
    return _apiRunner.runOnlineRequiredWrite(
      offlineMessage: _offlineMessage,
      remote: () async {
        final dtos = overrides
            .map(
              (o) => UserPermissionOverrideDto(
                permissionCode: o.permissionCode,
                effect: o.effect == PermissionOverrideEffect.deny
                    ? 'deny'
                    : 'grant',
                reason: o.reason,
                expiresAt: o.expiresAt,
              ),
            )
            .toList();
        return (await _remote.replaceUserOverrides(
          userId: userId,
          overrides: dtos,
          reason: reason,
        ))
            .toEntity();
      },
    );
  }

  @override
  Future<RoleCatalogItem> createShopRole(CreateShopRoleInput input) {
    return _apiRunner.runOnlineRequiredWrite(
      offlineMessage: _offlineMessage,
      remote: () async {
        final dto = await _remote.createShopRole({
          'slug': input.slug.trim(),
          'label': input.label.trim(),
          if (input.description != null && input.description!.trim().isNotEmpty)
            'description': input.description!.trim(),
          if (input.parentRoleCode != null &&
              input.parentRoleCode!.trim().isNotEmpty)
            'parentRoleCode': input.parentRoleCode!.trim(),
          'permissions': [
            for (final grant in input.permissions)
              {
                'permissionCode': grant.permissionCode,
                'effect': grant.effect == RolePermissionEffect.deny
                    ? 'deny'
                    : 'allow',
              },
          ],
        });
        return dto.toEntity();
      },
    );
  }

  @override
  Future<RoleCatalogItem> updateShopRole(
    String code,
    UpdateShopRoleInput input,
  ) {
    return _apiRunner.runOnlineRequiredWrite(
      offlineMessage: _offlineMessage,
      remote: () async {
        final body = <String, dynamic>{};
        if (input.label != null) body['label'] = input.label!.trim();
        if (input.description != null) {
          body['description'] = input.description!.trim().isEmpty
              ? null
              : input.description!.trim();
        }
        if (input.permissions != null) {
          body['permissions'] = [
            for (final grant in input.permissions!)
              {
                'permissionCode': grant.permissionCode,
                'effect': grant.effect == RolePermissionEffect.deny
                    ? 'deny'
                    : 'allow',
              },
          ];
        }
        final dto = await _remote.updateShopRole(code, body);
        return dto.toEntity();
      },
    );
  }

  @override
  Future<void> deleteShopRole(String code) {
    return _apiRunner.runOnlineRequiredWrite(
      offlineMessage: _offlineMessage,
      remote: () => _remote.deleteShopRole(code),
    );
  }

  @override
  Future<RoleCatalogItem> setRolePermissions(
    String code,
    List<RolePermissionGrant> permissions,
  ) {
    return _apiRunner.runOnlineRequiredWrite(
      offlineMessage: _offlineMessage,
      remote: () async {
        final dto = await _remote.setRolePermissions(
          code,
          [
            for (final grant in permissions)
              {
                'permissionCode': grant.permissionCode,
                'effect': grant.effect == RolePermissionEffect.deny
                    ? 'deny'
                    : 'allow',
              },
          ],
        );
        return dto.toEntity();
      },
    );
  }
}
