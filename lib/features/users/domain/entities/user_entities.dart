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

class ShopAccessGrant {
  const ShopAccessGrant({
    required this.shopId,
    this.accessRole,
  });

  final int shopId;
  final String? accessRole;
}

class UserShopAccessEntry {
  const UserShopAccessEntry({
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
}

class UserShopAccess {
  const UserShopAccess({
    required this.userId,
    required this.membershipId,
    required this.roleCode,
    required this.roleLabel,
    required this.shops,
  });

  final int userId;
  final int membershipId;
  final String roleCode;
  final String roleLabel;
  final List<UserShopAccessEntry> shops;
}
