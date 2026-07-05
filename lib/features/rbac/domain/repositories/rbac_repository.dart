import '../../domain/entities/rbac_entities.dart';

abstract class RbacRepository {
  Future<List<RoleCatalogItem>> listRoles();

  Future<RoleCatalogItem> getRole(String code);

  Future<PermissionsCatalog> getPermissionsCatalog();

  Future<MyPermissions> getMyPermissions();

  Future<UserEffectivePermissions> getUserPermissions(int userId);

  Future<List<UserPermissionOverride>> listUserOverrides(int userId);

  Future<ReplaceOverridesResult> replaceUserOverrides({
    required int userId,
    required List<UserPermissionOverride> overrides,
    String? reason,
  });

  Future<RoleCatalogItem> createShopRole(CreateShopRoleInput input);

  Future<RoleCatalogItem> updateShopRole(
    String code,
    UpdateShopRoleInput input,
  );

  Future<void> deleteShopRole(String code);

  Future<RoleCatalogItem> setRolePermissions(
    String code,
    List<RolePermissionGrant> permissions,
  );
}
