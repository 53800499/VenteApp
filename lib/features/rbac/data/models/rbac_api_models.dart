import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../domain/entities/rbac_entities.dart';

class RolePermissionGrantDto {
  const RolePermissionGrantDto({
    required this.permissionCode,
    required this.effect,
  });

  final String permissionCode;
  final String effect;

  factory RolePermissionGrantDto.fromJson(Map<String, dynamic> json) {
    return RolePermissionGrantDto(
      permissionCode: json['permissionCode'] as String,
      effect: json['effect'] as String? ?? 'allow',
    );
  }

  RolePermissionGrant toEntity() {
    return RolePermissionGrant(
      permissionCode: permissionCode,
      effect: effect == 'deny'
          ? RolePermissionEffect.deny
          : RolePermissionEffect.allow,
    );
  }
}

class RoleCatalogItemDto {
  const RoleCatalogItemDto({
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
  final List<RolePermissionGrantDto> permissions;

  factory RoleCatalogItemDto.fromJson(Map<String, dynamic> json) {
    return RoleCatalogItemDto(
      code: json['code'] as String,
      label: json['label'] as String,
      description: json['description'] as String?,
      scope: json['scope'] as String? ?? 'system',
      shopId: json['shopId'] as int?,
      isSystem: json['isSystem'] as bool? ?? true,
      priority: json['priority'] as int? ?? 0,
      parentRoles: (json['parentRoles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => RolePermissionGrantDto.fromJson(
                    e as Map<String, dynamic>,
                  ))
              .toList() ??
          const [],
    );
  }

  RoleCatalogItem toEntity() {
    return RoleCatalogItem(
      code: code,
      label: label,
      description: description,
      scope: scope,
      shopId: shopId,
      isSystem: isSystem,
      priority: priority,
      parentRoles: parentRoles,
      permissions: permissions.map((p) => p.toEntity()).toList(),
    );
  }
}

class PermissionCatalogItemDto {
  const PermissionCatalogItemDto({
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

  factory PermissionCatalogItemDto.fromJson(Map<String, dynamic> json) {
    return PermissionCatalogItemDto(
      code: json['code'] as String,
      module: json['module'] as String,
      action: json['action'] as String,
      label: json['label'] as String,
      description: json['description'] as String?,
    );
  }

  PermissionCatalogItem toEntity() => PermissionCatalogItem(
        code: code,
        module: module,
        action: action,
        label: label,
        description: description,
      );
}

class PermissionsCatalogDto {
  const PermissionsCatalogDto({
    required this.modules,
    required this.permissions,
  });

  final List<PermissionModuleDto> modules;
  final List<PermissionCatalogItemDto> permissions;

  factory PermissionsCatalogDto.fromJson(Map<String, dynamic> json) {
    return PermissionsCatalogDto(
      modules: (json['modules'] as List<dynamic>?)
              ?.map(
                (e) => PermissionModuleDto.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map(
                (e) =>
                    PermissionCatalogItemDto.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
    );
  }

  PermissionsCatalog toEntity() => PermissionsCatalog(
        modules: modules.map((m) => m.toEntity()).toList(),
        permissions: permissions.map((p) => p.toEntity()).toList(),
      );
}

class PermissionModuleDto {
  const PermissionModuleDto({
    required this.code,
    required this.label,
    this.description,
  });

  final String code;
  final String label;
  final String? description;

  factory PermissionModuleDto.fromJson(Map<String, dynamic> json) {
    return PermissionModuleDto(
      code: json['code'] as String,
      label: json['label'] as String,
      description: json['description'] as String?,
    );
  }

  PermissionModule toEntity() => PermissionModule(
        code: code,
        label: label,
        description: description,
      );
}

class MyPermissionsDto {
  const MyPermissionsDto({
    required this.userId,
    required this.shopId,
    required this.role,
    required this.roleLabel,
    required this.permissions,
  });

  final int userId;
  final int shopId;
  final String role;
  final String roleLabel;
  final List<String> permissions;

  factory MyPermissionsDto.fromJson(Map<String, dynamic> json) {
    return MyPermissionsDto(
      userId: json['userId'] as int,
      shopId: json['shopId'] as int,
      role: json['role'] as String,
      roleLabel: json['roleLabel'] as String? ?? json['role'] as String,
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  MyPermissions toEntity() => MyPermissions(
        userId: userId,
        shopId: shopId,
        role: UserRole.fromCode(role),
        roleLabel: roleLabel,
        permissions: permissionsFromCodes(permissions),
      );
}

class UserPermissionOverrideDto {
  const UserPermissionOverrideDto({
    required this.permissionCode,
    required this.effect,
    this.reason,
    this.expiresAt,
  });

  final String permissionCode;
  final String effect;
  final String? reason;
  final int? expiresAt;

  factory UserPermissionOverrideDto.fromJson(Map<String, dynamic> json) {
    return UserPermissionOverrideDto(
      permissionCode: json['permissionCode'] as String,
      effect: json['effect'] as String? ?? 'grant',
      reason: json['reason'] as String?,
      expiresAt: json['expiresAt'] as int?,
    );
  }

  UserPermissionOverride toEntity() => UserPermissionOverride(
        permissionCode: permissionCode,
        effect: effect == 'deny'
            ? PermissionOverrideEffect.deny
            : PermissionOverrideEffect.grant,
        reason: reason,
        expiresAt: expiresAt,
      );
}

class UserEffectivePermissionsDto {
  const UserEffectivePermissionsDto({
    required this.userId,
    required this.role,
    required this.roleLabel,
    required this.shopId,
    required this.permissions,
  });

  final int userId;
  final String role;
  final String roleLabel;
  final int shopId;
  final List<String> permissions;

  factory UserEffectivePermissionsDto.fromJson(Map<String, dynamic> json) {
    return UserEffectivePermissionsDto(
      userId: json['userId'] as int,
      role: json['role'] as String,
      roleLabel: json['roleLabel'] as String? ?? json['role'] as String,
      shopId: json['shopId'] as int,
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  UserEffectivePermissions toEntity() => UserEffectivePermissions(
        userId: userId,
        role: UserRole.fromCode(role),
        roleLabel: roleLabel,
        shopId: shopId,
        permissions: permissionsFromCodes(permissions),
      );
}

class ReplaceOverridesResultDto {
  const ReplaceOverridesResultDto({
    required this.userId,
    required this.overrides,
    required this.permissions,
  });

  final int userId;
  final List<UserPermissionOverrideDto> overrides;
  final List<String> permissions;

  factory ReplaceOverridesResultDto.fromJson(Map<String, dynamic> json) {
    return ReplaceOverridesResultDto(
      userId: json['userId'] as int,
      overrides: (json['overrides'] as List<dynamic>?)
              ?.map(
                (e) => UserPermissionOverrideDto.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          const [],
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  ReplaceOverridesResult toEntity() => ReplaceOverridesResult(
        userId: userId,
        overrides: overrides.map((o) => o.toEntity()).toList(),
        permissions: permissionsFromCodes(permissions),
      );
}

Set<Permission> permissionsFromCodes(Iterable<String> codes) {
  final codeSet = codes.toSet();
  return Permission.values.where((p) => codeSet.contains(p.code)).toSet();
}
