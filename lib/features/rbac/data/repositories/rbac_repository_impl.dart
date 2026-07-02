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
}
