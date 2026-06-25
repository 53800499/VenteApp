import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';

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
  });

  final int id;
  final String name;
  final int shopId;
  final String shopName;
  final String role;
  final String roleLabel;
  final bool isActive;
  final List<String> permissions;

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
    );
  }
}

Set<Permission> permissionsFromCodes(Iterable<String> codes) {
  final codeSet = codes.toSet();
  return Permission.values.where((p) => codeSet.contains(p.code)).toSet();
}

UserRole roleFromCode(String code) => UserRole.fromCode(code);
