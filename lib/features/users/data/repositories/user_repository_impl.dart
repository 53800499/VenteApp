import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/remote_api_runner.dart';
import '../../../../core/security/production_message_policy.dart';
import '../../../../core/utils/phone_util.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../domain/entities/user_entities.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/remote/user_remote_datasource.dart';
import '../models/user_api_models.dart';

class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl({
    required UserRemoteDatasource remote,
    required AppDatabase database,
    required RemoteApiRunner apiRunner,
  })  : _remote = remote,
        _db = database,
        _apiRunner = apiRunner;

  final UserRemoteDatasource _remote;
  final AppDatabase _db;
  final RemoteApiRunner _apiRunner;

  String get _writeOfflineMessage =>
      ProductionMessagePolicy.onlineWriteRequiredMessage('gérer l\'équipe');

  @override
  Future<List<ShopUser>> listShopUsers({required int localShopId}) async {
    return _apiRunner.runOnlinePreferredRead(
      remote: () async {
        final items = await _remote.listShopUsers();
        return items.map(_mapUser).toList();
      },
      localFallback: () => _listUsersLocally(localShopId),
    );
  }

  @override
  Future<UserAssignment> getUserAssignment(int userId) async {
    return _apiRunner.runOnlinePreferredRead(
      remote: () async {
        final dto = await _remote.getUserAssignment(userId);
        return UserAssignment(
          id: dto.id,
          name: dto.name,
          shopId: dto.shopId,
          shopName: dto.shopName,
          roleCode: dto.role,
          roleLabel: dto.roleLabel,
          isActive: dto.isActive,
          permissions: permissionsFromCodes(dto.permissions),
          overrides: dto.overrides.map((o) => o.toEntity()).toList(),
        );
      },
      localFallback: () => throw NetworkFailure(_writeOfflineMessage),
    );
  }

  @override
  Future<ShopUser> createShopUser(CreateShopUserInput input) async {
    if (input.roleCode == UserRole.owner.code) {
      throw const ValidationFailure(
        'Le rôle patron ne peut pas être attribué.',
      );
    }
    return _apiRunner.runOnlineRequiredWrite(
      offlineMessage: _writeOfflineMessage,
      remote: () async {
        final dto = await _remote.createShopUser(
          name: input.name,
          phone: normalizePhone(input.phone),
          pin: input.pin,
          roleCode: input.roleCode,
        );
        return ShopUser(
          id: dto.id,
          name: dto.name,
          roleCode: dto.role,
          roleLabel: dto.role,
          isActive: true,
          biometricEnabled: false,
          permissions: const {},
        );
      },
    );
  }

  @override
  Future<ShopUser> changeUserRole({
    required int userId,
    required String roleCode,
    String? reason,
  }) async {
    return _apiRunner.runOnlineRequiredWrite(
      offlineMessage: _writeOfflineMessage,
      remote: () async {
        final dto = await _remote.changeUserRole(
          userId: userId,
          roleCode: roleCode,
          reason: reason,
        );
        return ShopUser(
          id: dto.id,
          name: dto.name,
          roleCode: dto.role,
          roleLabel: dto.roleLabel,
          isActive: true,
          biometricEnabled: false,
          permissions: permissionsFromCodes(dto.permissions),
        );
      },
    );
  }

  @override
  Future<void> deactivateUser(int userId, {String? reason}) async {
    await _apiRunner.runOnlineRequiredWrite(
      offlineMessage: _writeOfflineMessage,
      remote: () => _remote.deactivateUser(userId, reason: reason),
    );
  }

  @override
  Future<void> assignUserShop({
    required int userId,
    required int shopId,
    String? reason,
  }) async {
    await _apiRunner.runOnlineRequiredWrite(
      offlineMessage: _writeOfflineMessage,
      remote: () => _remote.assignUserShop(
        userId: userId,
        shopId: shopId,
        reason: reason,
      ),
    );
  }

  ShopUser _mapUser(ShopUserItemDto dto) {
    return ShopUser(
      id: dto.id,
      name: dto.name,
      roleCode: dto.role,
      roleLabel: dto.roleLabel,
      isActive: dto.isActive,
      biometricEnabled: dto.biometricEnabled,
      lastLoginAt: dto.lastLoginAt,
      permissions: permissionsFromCodes(dto.permissions),
    );
  }

  Future<List<ShopUser>> _listUsersLocally(int shopId) async {
    final rows = await (_db.select(_db.users)
          ..where((u) => u.shopId.equals(shopId))
          ..orderBy([(u) => OrderingTerm.asc(u.name)]))
        .get();

    return rows.map((row) {
      final roleCode = row.role;
      final systemRole = UserRole.values
          .where((r) => r.code == roleCode)
          .cast<UserRole?>()
          .firstOrNull;
      return ShopUser(
        id: int.tryParse(row.serverId ?? '') ?? row.id,
        name: row.name,
        roleCode: roleCode,
        roleLabel: systemRole?.label ?? roleCode,
        isActive: row.isActive,
        biometricEnabled: row.biometricEnabled,
        lastLoginAt: row.lastLoginAt,
        permissions: systemRole != null
            ? permissionsForRole(systemRole)
            : const {},
      );
    }).toList();
  }
}
