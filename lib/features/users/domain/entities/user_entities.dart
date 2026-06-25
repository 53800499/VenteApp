import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';

class ShopUser {
  const ShopUser({
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
  final UserRole role;
  final String roleLabel;
  final bool isActive;
  final bool biometricEnabled;
  final int? lastLoginAt;
  final Set<Permission> permissions;
}

class CreateShopUserInput {
  const CreateShopUserInput({
    required this.name,
    required this.pin,
    required this.role,
  });

  final String name;
  final String pin;
  final UserRole role;
}

class UserAssignment {
  const UserAssignment({
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
  final UserRole role;
  final String roleLabel;
  final bool isActive;
  final Set<Permission> permissions;
}
