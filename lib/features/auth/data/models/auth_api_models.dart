import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';

class LoginSuccessData {
  const LoginSuccessData({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
    required this.user,
    required this.shop,
    required this.autoLockMinutes,
    required this.expiresAt,
    this.message,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int accessExpiresAt;
  final int refreshExpiresAt;
  final AuthUserData user;
  final AuthShopData shop;
  final int autoLockMinutes;
  final int expiresAt;
  final String? message;

  factory LoginSuccessData.fromJson(Map<String, dynamic> json) {
    return LoginSuccessData(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      accessExpiresAt: json['accessExpiresAt'] as int,
      refreshExpiresAt: json['refreshExpiresAt'] as int,
      user: AuthUserData.fromJson(json['user'] as Map<String, dynamic>),
      shop: AuthShopData.fromJson(json['shop'] as Map<String, dynamic>),
      autoLockMinutes: json['autoLockMinutes'] as int? ?? 5,
      expiresAt: json['expiresAt'] as int,
      message: json['message'] as String?,
    );
  }
}

class TokenRefreshData {
  const TokenRefreshData({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.accessExpiresAt,
    required this.refreshExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final int accessExpiresAt;
  final int refreshExpiresAt;

  factory TokenRefreshData.fromJson(Map<String, dynamic> json) {
    return TokenRefreshData(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      accessExpiresAt: json['accessExpiresAt'] as int,
      refreshExpiresAt: json['refreshExpiresAt'] as int,
    );
  }
}

class AuthUserData {
  const AuthUserData({
    required this.id,
    required this.name,
    required this.role,
    required this.roleLabel,
    required this.shopId,
    required this.biometricEnabled,
    required this.lastLoginAt,
    required this.permissions,
  });

  final int id;
  final String name;
  final String role;
  final String roleLabel;
  final int shopId;
  final bool biometricEnabled;
  final int? lastLoginAt;
  final List<String> permissions;

  factory AuthUserData.fromJson(Map<String, dynamic> json) {
    return AuthUserData(
      id: json['id'] as int,
      name: json['name'] as String,
      role: json['role'] as String,
      roleLabel: json['roleLabel'] as String? ?? '',
      shopId: json['shopId'] as int,
      biometricEnabled: json['biometricEnabled'] as bool? ?? false,
      lastLoginAt: json['lastLoginAt'] as int?,
      permissions: parsePermissionsList(json['permissions']),
    );
  }
}

class AuthShopData {
  const AuthShopData({required this.id, required this.name});

  final int id;
  final String name;

  factory AuthShopData.fromJson(Map<String, dynamic> json) {
    return AuthShopData(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class SetupOwnerData {
  const SetupOwnerData({
    required this.shopId,
    required this.userId,
    required this.recoveryToken,
    required this.message,
  });

  final int shopId;
  final int userId;
  final String recoveryToken;
  final String message;

  factory SetupOwnerData.fromJson(Map<String, dynamic> json) {
    return SetupOwnerData(
      shopId: json['shopId'] as int,
      userId: json['userId'] as int,
      recoveryToken: json['recoveryToken'] as String,
      message: json['message'] as String,
    );
  }
}

class LockScreenDataDto {
  const LockScreenDataDto({
    required this.shopId,
    required this.shopName,
    required this.shopLogoPath,
    required this.users,
  });

  final int shopId;
  final String shopName;
  final String? shopLogoPath;
  final List<LockScreenUserDto> users;

  factory LockScreenDataDto.fromJson(Map<String, dynamic> json) {
    return LockScreenDataDto(
      shopId: json['shopId'] as int,
      shopName: json['shopName'] as String,
      shopLogoPath: json['shopLogoPath'] as String?,
      users: (json['users'] as List<dynamic>)
          .map((e) => LockScreenUserDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OwnedShopItemDto {
  const OwnedShopItemDto({
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

  factory OwnedShopItemDto.fromJson(Map<String, dynamic> json) {
    return OwnedShopItemDto(
      id: json['id'] as int,
      name: json['name'] as String,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      isDefault: json['isDefault'] as bool? ?? false,
      isCurrent: json['isCurrent'] as bool? ?? false,
    );
  }
}

class OwnedShopListDto {
  const OwnedShopListDto({
    required this.activeShopId,
    required this.shops,
  });

  final int activeShopId;
  final List<OwnedShopItemDto> shops;

  factory OwnedShopListDto.fromJson(Map<String, dynamic> json) {
    return OwnedShopListDto(
      activeShopId: json['activeShopId'] as int,
      shops: (json['shops'] as List<dynamic>)
          .map((e) => OwnedShopItemDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class SwitchShopDataDto {
  const SwitchShopDataDto({
    required this.activeShopId,
    required this.shop,
  });

  final int activeShopId;
  final SwitchShopTargetDto shop;

  factory SwitchShopDataDto.fromJson(Map<String, dynamic> json) {
    return SwitchShopDataDto(
      activeShopId: json['activeShopId'] as int,
      shop: SwitchShopTargetDto.fromJson(
        json['shop'] as Map<String, dynamic>,
      ),
    );
  }
}

class SwitchShopTargetDto {
  const SwitchShopTargetDto({required this.id, required this.name});

  final int id;
  final String name;

  factory SwitchShopTargetDto.fromJson(Map<String, dynamic> json) {
    return SwitchShopTargetDto(
      id: json['id'] as int,
      name: json['name'] as String,
    );
  }
}

class LockScreenUserDto {
  const LockScreenUserDto({
    required this.id,
    required this.name,
    required this.role,
    required this.biometricEnabled,
  });

  final int id;
  final String name;
  final String role;
  final bool biometricEnabled;

  factory LockScreenUserDto.fromJson(Map<String, dynamic> json) {
    return LockScreenUserDto(
      id: json['id'] as int,
      name: json['name'] as String,
      role: json['role'] as String,
      biometricEnabled: json['biometricEnabled'] as bool? ?? false,
    );
  }
}

List<String> parsePermissionsList(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).where((c) => c.isNotEmpty).toList();
}

Set<Permission> permissionsFromApi(
  Iterable<String> codes, {
  UserRole? role,
}) {
  final codeSet = codes.map((c) => c.toString()).toSet();
  final fromApi =
      Permission.values.where((p) => codeSet.contains(p.code)).toSet();
  if (role == null) return fromApi;

  final baseline = permissionsForRole(role);
  if (fromApi.isEmpty) return baseline;
  if (role == UserRole.owner) return {...fromApi, ...baseline};
  return fromApi;
}

Set<Permission> resolveSessionPermissions({
  required Iterable<String> apiCodes,
  required UserRole role,
}) =>
    permissionsFromApi(apiCodes, role: role);

UserRole roleFromApi(String code) => UserRole.fromCode(code);
