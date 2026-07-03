import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.role,
    required this.roleLabel,
    required this.shopId,
    required this.biometricEnabled,
    required this.lastLoginAt,
    required this.permissions,
    this.serverUserId,
  });

  final int id;
  final String name;
  final UserRole role;
  final String roleLabel;
  final int shopId;
  final bool biometricEnabled;
  final int? lastLoginAt;
  final Set<Permission> permissions;
  /// ID utilisateur côté serveur (API). Fallback sur [id] si absent.
  final int? serverUserId;

  int get apiUserId => serverUserId ?? id;
}

class AuthShop {
  const AuthShop({
    required this.id,
    required this.name,
    this.serverShopId,
  });

  final int id;
  final String name;
  /// ID boutique côté serveur (API). Fallback sur [id] si absent.
  final int? serverShopId;

  int get apiShopId => serverShopId ?? id;
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.expiresAt,
    required this.user,
    required this.shop,
    required this.autoLockMinutes,
  });

  final String token;
  final int expiresAt;
  final AuthUser user;
  final AuthShop shop;
  final int autoLockMinutes;
}

class LockScreenUser {
  const LockScreenUser({
    required this.id,
    required this.name,
    required this.role,
    required this.biometricEnabled,
  });

  final int id;
  final String name;
  final UserRole role;
  final bool biometricEnabled;
}

class LockScreenData {
  const LockScreenData({
    required this.shopId,
    required this.shopName,
    required this.shopLogoPath,
    required this.users,
  });

  final int shopId;
  final String shopName;
  final String? shopLogoPath;
  final List<LockScreenUser> users;
}

class SetupOwnerResult {
  const SetupOwnerResult({
    required this.shopId,
    required this.userId,
    required this.recoveryToken,
    required this.message,
  });

  final int shopId;
  final int userId;
  final String recoveryToken;
  final String message;
}

class OwnedShop {
  const OwnedShop({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    required this.isActive,
    required this.isDefault,
    required this.isCurrent,
  });

  final int id;
  final String name;
  final String? address;
  final String? phone;
  final bool isActive;
  final bool isDefault;
  final bool isCurrent;
}

class OwnedShopList {
  const OwnedShopList({
    required this.activeShopId,
    required this.shops,
  });

  final int activeShopId;
  final List<OwnedShop> shops;

  List<OwnedShop> get activeShops =>
      shops.where((shop) => shop.isActive).toList();
}

/// Accès boutique après vérification WhatsApp (tous rôles).
class AuthMembership {
  const AuthMembership({
    required this.userId,
    required this.shopId,
    required this.shopName,
    required this.role,
    required this.roleLabel,
    required this.isDefault,
  });

  final int userId;
  final int shopId;
  final String shopName;
  final UserRole role;
  final String roleLabel;
  final bool isDefault;
}

class WhatsappOtpRequestResult {
  const WhatsappOtpRequestResult({
    required this.maskedPhone,
    required this.expiresInSeconds,
    required this.message,
  });

  final String maskedPhone;
  final int expiresInSeconds;
  final String message;
}

class WhatsappOtpVerifyResult {
  const WhatsappOtpVerifyResult({
    required this.verificationToken,
    required this.memberships,
  });

  final String verificationToken;
  final List<AuthMembership> memberships;
}

class DeviceSession {
  const DeviceSession({
    required this.id,
    required this.userId,
    required this.userName,
    required this.deviceId,
    this.deviceLabel,
    required this.lastSeenAt,
    required this.sessionExpiresAt,
    required this.refreshExpiresAt,
    required this.isCurrent,
  });

  final String id;
  final int userId;
  final String userName;
  final String deviceId;
  final String? deviceLabel;
  final int lastSeenAt;
  final int sessionExpiresAt;
  final int refreshExpiresAt;
  final bool isCurrent;

  String get displayName =>
      deviceLabel?.trim().isNotEmpty == true ? deviceLabel!.trim() : deviceId;
}
