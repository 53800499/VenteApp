import '../../../rbac/data/models/rbac_api_models.dart';
import '../../../../shared/enums/user_role.dart';

export '../../../rbac/data/models/rbac_api_models.dart' show permissionsFromCodes;

class ShopUserItemDto {
  const ShopUserItemDto({
    required this.id,
    required this.name,
    required this.role,
    required this.roleLabel,
    required this.isActive,
    required this.biometricEnabled,
    this.lastLoginAt,
    required this.permissions,
  });

  final int id;
  final String name;
  final String role;
  final String roleLabel;
  final bool isActive;
  final bool biometricEnabled;
  final int? lastLoginAt;
  final List<String> permissions;

  factory ShopUserItemDto.fromJson(Map<String, dynamic> json) {
    return ShopUserItemDto(
      id: json['id'] as int,
      name: json['name'] as String,
      role: json['role'] as String,
      roleLabel: json['roleLabel'] as String? ?? json['role'] as String,
      isActive: json['isActive'] as bool? ?? true,
      biometricEnabled: json['biometricEnabled'] as bool? ?? false,
      lastLoginAt: json['lastLoginAt'] as int?,
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class CreateShopUserResponseDto {
  const CreateShopUserResponseDto({
    required this.id,
    required this.name,
    required this.role,
    required this.shopId,
  });

  final int id;
  final String name;
  final String role;
  final int shopId;

  factory CreateShopUserResponseDto.fromJson(Map<String, dynamic> json) {
    return CreateShopUserResponseDto(
      id: json['id'] as int,
      name: json['name'] as String,
      role: json['role'] as String,
      shopId: json['shopId'] as int,
    );
  }
}

class ChangeUserRoleResponseDto {
  const ChangeUserRoleResponseDto({
    required this.id,
    required this.name,
    required this.role,
    required this.roleLabel,
    required this.permissions,
  });

  final int id;
  final String name;
  final String role;
  final String roleLabel;
  final List<String> permissions;

  factory ChangeUserRoleResponseDto.fromJson(Map<String, dynamic> json) {
    return ChangeUserRoleResponseDto(
      id: json['id'] as int,
      name: json['name'] as String,
      role: json['role'] as String,
      roleLabel: json['roleLabel'] as String? ?? json['role'] as String,
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class UserAssignmentDto {
  const UserAssignmentDto({
    required this.id,
    required this.name,
    required this.shopId,
    required this.shopName,
    required this.role,
    required this.roleLabel,
    required this.isActive,
    required this.permissions,
    required this.overrides,
  });

  final int id;
  final String name;
  final int shopId;
  final String shopName;
  final String role;
  final String roleLabel;
  final bool isActive;
  final List<String> permissions;
  final List<UserPermissionOverrideDto> overrides;

  factory UserAssignmentDto.fromJson(Map<String, dynamic> json) {
    return UserAssignmentDto(
      id: json['id'] as int,
      name: json['name'] as String,
      shopId: json['shopId'] as int,
      shopName: json['shopName'] as String,
      role: json['role'] as String,
      roleLabel: json['roleLabel'] as String? ?? json['role'] as String,
      isActive: json['isActive'] as bool? ?? true,
      permissions: (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      overrides: (json['overrides'] as List<dynamic>?)
              ?.map(
                (e) => UserPermissionOverrideDto.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          const [],
    );
  }
}

UserRole roleFromCode(String code) => UserRole.fromCode(code);

class UserShopAccessEntryDto {
  const UserShopAccessEntryDto({
    required this.shopId,
    required this.shopName,
    this.accessRole,
    required this.effectiveRole,
    required this.effectiveRoleLabel,
  });

  final int shopId;
  final String shopName;
  final String? accessRole;
  final String effectiveRole;
  final String effectiveRoleLabel;

  factory UserShopAccessEntryDto.fromJson(Map<String, dynamic> json) {
    return UserShopAccessEntryDto(
      shopId: json['shopId'] as int,
      shopName: json['shopName'] as String,
      accessRole: json['accessRole'] as String?,
      effectiveRole: json['effectiveRole'] as String,
      effectiveRoleLabel:
          json['effectiveRoleLabel'] as String? ?? json['effectiveRole'] as String,
    );
  }
}

class UserShopAccessDto {
  const UserShopAccessDto({
    required this.userId,
    required this.membershipId,
    required this.role,
    required this.roleLabel,
    required this.shops,
  });

  final int userId;
  final int membershipId;
  final String role;
  final String roleLabel;
  final List<UserShopAccessEntryDto> shops;

  factory UserShopAccessDto.fromJson(Map<String, dynamic> json) {
    return UserShopAccessDto(
      userId: json['userId'] as int,
      membershipId: json['membershipId'] as int,
      role: json['role'] as String,
      roleLabel: json['roleLabel'] as String? ?? json['role'] as String,
      shops: (json['shops'] as List<dynamic>?)
              ?.map(
                (e) => UserShopAccessEntryDto.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList() ??
          const [],
    );
  }
}

class ShopAccessGrantInputDto {
  const ShopAccessGrantInputDto({
    required this.shopId,
    this.accessRole,
  });

  final int shopId;
  final String? accessRole;

  Map<String, dynamic> toJson() => {
        'shopId': shopId,
        if (accessRole != null) 'accessRole': accessRole,
      };
}
