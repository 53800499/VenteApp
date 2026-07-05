import '../entities/rbac_entities.dart';
import '../repositories/rbac_repository.dart';

class ListRoles {
  const ListRoles(this._repository);

  final RbacRepository _repository;

  Future<List<RoleCatalogItem>> call() => _repository.listRoles();
}

class GetRoleDetail {
  const GetRoleDetail(this._repository);

  final RbacRepository _repository;

  Future<RoleCatalogItem> call(String code) => _repository.getRole(code);
}

class GetPermissionsCatalog {
  const GetPermissionsCatalog(this._repository);

  final RbacRepository _repository;

  Future<PermissionsCatalog> call() => _repository.getPermissionsCatalog();
}

class GetMyPermissions {
  const GetMyPermissions(this._repository);

  final RbacRepository _repository;

  Future<MyPermissions> call() => _repository.getMyPermissions();
}

class GetUserEffectivePermissions {
  const GetUserEffectivePermissions(this._repository);

  final RbacRepository _repository;

  Future<UserEffectivePermissions> call(int userId) =>
      _repository.getUserPermissions(userId);
}

class ListUserPermissionOverrides {
  const ListUserPermissionOverrides(this._repository);

  final RbacRepository _repository;

  Future<List<UserPermissionOverride>> call(int userId) =>
      _repository.listUserOverrides(userId);
}

class ReplaceUserPermissionOverrides {
  const ReplaceUserPermissionOverrides(this._repository);

  final RbacRepository _repository;

  Future<ReplaceOverridesResult> call({
    required int userId,
    required List<UserPermissionOverride> overrides,
    String? reason,
  }) =>
      _repository.replaceUserOverrides(
        userId: userId,
        overrides: overrides,
        reason: reason,
      );
}

class CreateShopRole {
  const CreateShopRole(this._repository);

  final RbacRepository _repository;

  Future<RoleCatalogItem> call(CreateShopRoleInput input) =>
      _repository.createShopRole(input);
}

class UpdateShopRole {
  const UpdateShopRole(this._repository);

  final RbacRepository _repository;

  Future<RoleCatalogItem> call(String code, UpdateShopRoleInput input) =>
      _repository.updateShopRole(code, input);
}

class DeleteShopRole {
  const DeleteShopRole(this._repository);

  final RbacRepository _repository;

  Future<void> call(String code) => _repository.deleteShopRole(code);
}

class SetRolePermissions {
  const SetRolePermissions(this._repository);

  final RbacRepository _repository;

  Future<RoleCatalogItem> call(
    String code,
    List<RolePermissionGrant> permissions,
  ) =>
      _repository.setRolePermissions(code, permissions);
}
