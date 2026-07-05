import '../../../../shared/enums/permission.dart';
import '../../../rbac/domain/entities/rbac_entities.dart';

class ShopUser {
  const ShopUser({
    required this.id,
    required this.name,
    required this.roleCode,
    required this.roleLabel,
    required this.isActive,
    required this.biometricEnabled,
    this.lastLoginAt,
    required this.permissions,
  });

  final int id;
  final String name;
  final String roleCode;
  final String roleLabel;
  final bool isActive;
  final bool biometricEnabled;
  final int? lastLoginAt;
  final Set<Permission> permissions;

  bool get isOwner => roleCode == 'owner';
}

class CreateShopUserInput {
  const CreateShopUserInput({
    required this.name,
    required this.phone,
    required this.pin,
    required this.roleCode,
  });

  final String name;
  final String phone;
  final String pin;
  final String roleCode;
}

class UserAssignment {
  const UserAssignment({
    required this.id,
    required this.name,
    required this.shopId,
    required this.shopName,
    required this.roleCode,
    required this.roleLabel,
    required this.isActive,
    required this.permissions,
    this.overrides = const [],
  });

  final int id;
  final String name;
  final int shopId;
  final String shopName;
  final String roleCode;
  final String roleLabel;
  final bool isActive;
  final Set<Permission> permissions;
  final List<UserPermissionOverride> overrides;
}

class AssignableRole {
  const AssignableRole({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;
}
