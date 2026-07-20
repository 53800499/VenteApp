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

/// Portée d'un accès après vérification WhatsApp.
enum MembershipScopeType {
  shop,
  organization,
}

/// Accès (identité) après vérification WhatsApp.
class AuthMembership {
  const AuthMembership({
    required this.userId,
    required this.shopId,
    required this.shopName,
    required this.role,
    required this.roleLabel,
    required this.isDefault,
    this.scopeType = MembershipScopeType.shop,
    this.organizationName,
    this.shopCount,
    this.accessibleShopIds = const [],
  });

  final int userId;
  /// Boutique d'entrée côté serveur (login initial).
  final int shopId;
  final String shopName;
  final UserRole role;
  final String roleLabel;
  final bool isDefault;
  final MembershipScopeType scopeType;
  final String? organizationName;
  final int? shopCount;
  final List<int> accessibleShopIds;

  String get displayName =>
      scopeType == MembershipScopeType.organization
          ? (organizationName ?? shopName)
          : shopName;

  String get subtitle {
    if (scopeType == MembershipScopeType.organization &&
        (shopCount ?? 0) > 1) {
      return '$roleLabel · $shopCount boutiques';
    }
    return roleLabel;
  }

  bool coversServerShop(int serverShopId) {
    if (shopId == serverShopId) return true;
    return accessibleShopIds.contains(serverShopId);
  }
}

class AccessibleShopSummary {
  const AccessibleShopSummary({
    required this.id,
    required this.name,
    required this.isCurrent,
    required this.isDefault,
    this.accessRole,
    this.roleLabel,
  });

  final int id;
  final String name;
  final bool isCurrent;
  final bool isDefault;
  final String? accessRole;
  final String? roleLabel;
}

/// Contexte identité persisté (Organization → Membership → ShopAccess).
class AuthIdentityContext {
  const AuthIdentityContext({
    required this.membershipId,
    this.identityId,
    required this.organizationId,
    required this.organizationName,
    required this.role,
    required this.roleLabel,
    required this.effectiveRole,
    required this.effectiveRoleLabel,
    required this.activeShopId,
    required this.activeShopName,
    required this.accessibleShops,
  });

  final int membershipId;
  final int? identityId;
  final int organizationId;
  final String organizationName;
  final String role;
  final String roleLabel;
  final String effectiveRole;
  final String effectiveRoleLabel;
  final int activeShopId;
  final String activeShopName;
  final List<AccessibleShopSummary> accessibleShops;

  int get accessibleShopCount => accessibleShops.length;

  Map<String, dynamic> toJson() => {
        'membershipId': membershipId,
        'identityId': identityId,
        'organizationId': organizationId,
        'organizationName': organizationName,
        'role': role,
        'roleLabel': roleLabel,
        'effectiveRole': effectiveRole,
        'effectiveRoleLabel': effectiveRoleLabel,
        'activeShopId': activeShopId,
        'activeShopName': activeShopName,
        'accessibleShops': accessibleShops
            .map(
              (shop) => {
                'id': shop.id,
                'name': shop.name,
                'isCurrent': shop.isCurrent,
                'isDefault': shop.isDefault,
                'accessRole': shop.accessRole,
                'roleLabel': shop.roleLabel,
              },
            )
            .toList(),
      };

  factory AuthIdentityContext.fromJson(Map<String, dynamic> json) {
    return AuthIdentityContext(
      membershipId: json['membershipId'] as int? ?? 0,
      identityId: json['identityId'] as int?,
      organizationId: json['organizationId'] as int? ?? 0,
      organizationName: json['organizationName'] as String? ?? '',
      role: json['role'] as String? ?? 'owner',
      roleLabel: json['roleLabel'] as String? ?? '',
      effectiveRole: json['effectiveRole'] as String? ?? json['role'] as String? ?? 'owner',
      effectiveRoleLabel:
          json['effectiveRoleLabel'] as String? ?? json['roleLabel'] as String? ?? '',
      activeShopId: json['activeShopId'] as int? ?? 0,
      activeShopName: json['activeShopName'] as String? ?? '',
      accessibleShops: (json['accessibleShops'] as List<dynamic>? ?? [])
          .map(
            (entry) => AccessibleShopSummary(
              id: entry['id'] as int,
              name: entry['name'] as String,
              isCurrent: entry['isCurrent'] as bool? ?? false,
              isDefault: entry['isDefault'] as bool? ?? false,
              accessRole: entry['accessRole'] as String?,
              roleLabel: entry['roleLabel'] as String?,
            ),
          )
          .toList(),
    );
  }
}

class WhatsappOtpRequestResult {
  const WhatsappOtpRequestResult({
    required this.maskedPhone,
    required this.expiresInSeconds,
    required this.message,
    this.deliveryChannel = 'whatsapp',
    this.deliveryWarning,
    this.devCode,
  });

  final String maskedPhone;
  final int expiresInSeconds;
  final String message;
  final String deliveryChannel;
  final String? deliveryWarning;
  final String? devCode;

  bool get sentViaWhatsapp => deliveryChannel == 'whatsapp';
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
