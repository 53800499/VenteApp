import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';

enum PermissionOverrideEffect { grant, deny }

enum RolePermissionEffect { allow, deny }

class RolePermissionGrant {
  const RolePermissionGrant({
    required this.permissionCode,
    required this.effect,
  });

  final String permissionCode;
  final RolePermissionEffect effect;
}

class RoleCatalogItem {
  const RoleCatalogItem({
    required this.code,
    required this.label,
    this.description,
    required this.scope,
    this.shopId,
    required this.isSystem,
    required this.priority,
    required this.parentRoles,
    required this.permissions,
  });

  final String code;
  final String label;
  final String? description;
  final String scope;
  final int? shopId;
  final bool isSystem;
  final int priority;
  final List<String> parentRoles;
  final List<RolePermissionGrant> permissions;
}

class PermissionCatalogItem {
  const PermissionCatalogItem({
    required this.code,
    required this.module,
    required this.action,
    required this.label,
    this.description,
  });

  final String code;
  final String module;
  final String action;
  final String label;
  final String? description;
}

class PermissionsCatalog {
  const PermissionsCatalog({
    required this.modules,
    required this.permissions,
  });

  final List<PermissionModule> modules;
  final List<PermissionCatalogItem> permissions;
}

class PermissionModule {
  const PermissionModule({
    required this.code,
    required this.label,
    this.description,
  });

  final String code;
  final String label;
  final String? description;
}

class MyPermissions {
  const MyPermissions({
    required this.userId,
    required this.shopId,
    required this.role,
    required this.roleLabel,
    required this.permissions,
  });

  final int userId;
  final int shopId;
  final UserRole role;
  final String roleLabel;
  final Set<Permission> permissions;
}

class UserPermissionOverride {
  const UserPermissionOverride({
    required this.permissionCode,
    required this.effect,
    this.reason,
    this.expiresAt,
  });

  final String permissionCode;
  final PermissionOverrideEffect effect;
  final String? reason;
  final int? expiresAt;
}

class UserEffectivePermissions {
  const UserEffectivePermissions({
    required this.userId,
    required this.role,
    required this.roleLabel,
    required this.shopId,
    required this.permissions,
  });

  final int userId;
  final UserRole role;
  final String roleLabel;
  final int shopId;
  final Set<Permission> permissions;
}

class ReplaceOverridesResult {
  const ReplaceOverridesResult({
    required this.userId,
    required this.overrides,
    required this.permissions,
  });

  final int userId;
  final List<UserPermissionOverride> overrides;
  final Set<Permission> permissions;
}

class CreateShopRoleInput {
  const CreateShopRoleInput({
    required this.slug,
    required this.label,
    this.description,
    this.parentRoleCode,
    required this.permissions,
  });

  final String slug;
  final String label;
  final String? description;
  final String? parentRoleCode;
  final List<RolePermissionGrant> permissions;
}

class UpdateShopRoleInput {
  const UpdateShopRoleInput({
    this.label,
    this.description,
    this.permissions,
  });

  final String? label;
  final String? description;
  final List<RolePermissionGrant>? permissions;
}
