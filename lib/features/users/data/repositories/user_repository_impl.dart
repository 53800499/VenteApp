import '../../../../core/errors/failures.dart';
import '../../../../core/utils/phone_util.dart';
import '../../../../core/network/remote_api_guard.dart';
import '../../../../core/network/network_info.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../domain/entities/user_entities.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/remote/user_remote_datasource.dart';
import '../models/user_api_models.dart';

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl({
    required UserRemoteDatasource remote,
    RemoteApiGuard? apiGuard,
    NetworkInfo? networkInfo,
  })  : _remote = remote,
        _apiGuard = apiGuard,
        _networkInfo = networkInfo ?? const NetworkInfo.alwaysOffline();

  final UserRemoteDatasource _remote;
  final RemoteApiGuard? _apiGuard;
  final NetworkInfo _networkInfo;

  @override
  Future<List<ShopUser>> listShopUsers() async {
    await _ensureOnline();
    final items = await _remote.listShopUsers();
    return items.map(_mapUser).toList();
  }

  @override
  Future<UserAssignment> getUserAssignment(int userId) async {
    await _ensureOnline();
    final dto = await _remote.getUserAssignment(userId);
    return UserAssignment(
      id: dto.id,
      name: dto.name,
      shopId: dto.shopId,
      shopName: dto.shopName,
      role: roleFromCode(dto.role),
      roleLabel: dto.roleLabel,
      isActive: dto.isActive,
      permissions: permissionsFromCodes(dto.permissions),
    );
  }

  @override
  Future<ShopUser> createShopUser(CreateShopUserInput input) async {
    await _ensureOnline();
    if (input.role == UserRole.owner) {
      throw const ValidationFailure(
        'Seuls les rôles vendeur et lecteur peuvent être créés.',
      );
    }
    final dto = await _remote.createShopUser(
      name: input.name,
      phone: normalizePhone(input.phone),
      pin: input.pin,
      role: input.role,
    );
    return ShopUser(
      id: dto.id,
      name: dto.name,
      role: roleFromCode(dto.role),
      roleLabel: roleFromCode(dto.role).label,
      isActive: true,
      biometricEnabled: false,
      permissions: permissionsForRole(roleFromCode(dto.role)),
    );
  }

  @override
  Future<ShopUser> changeUserRole({
    required int userId,
    required UserRole role,
    String? reason,
  }) async {
    await _ensureOnline();
    final dto = await _remote.changeUserRole(
      userId: userId,
      role: role,
      reason: reason,
    );
    return ShopUser(
      id: dto.id,
      name: dto.name,
      role: roleFromCode(dto.role),
      roleLabel: dto.roleLabel,
      isActive: true,
      biometricEnabled: false,
      permissions: permissionsFromCodes(dto.permissions),
    );
  }

  @override
  Future<void> deactivateUser(int userId, {String? reason}) async {
    await _ensureOnline();
    await _remote.deactivateUser(userId, reason: reason);
  }

  @override
  Future<void> assignUserShop({
    required int userId,
    required int shopId,
    String? reason,
  }) async {
    await _ensureOnline();
    await _remote.assignUserShop(
      userId: userId,
      shopId: shopId,
      reason: reason,
    );
  }

  ShopUser _mapUser(ShopUserItemDto dto) {
    return ShopUser(
      id: dto.id,
      name: dto.name,
      role: roleFromCode(dto.role),
      roleLabel: dto.roleLabel,
      isActive: dto.isActive,
      biometricEnabled: dto.biometricEnabled,
      lastLoginAt: dto.lastLoginAt,
      permissions: permissionsFromCodes(dto.permissions),
    );
  }

  Future<void> _ensureOnline() async {
    final guard = _apiGuard;
    if (guard != null) {
      await guard.ensureReady();
      return;
    }
    if (!await _networkInfo.isConnected) {
      throw const NetworkFailure(
        'Connexion internet requise pour gérer les utilisateurs.',
      );
    }
  }
}
