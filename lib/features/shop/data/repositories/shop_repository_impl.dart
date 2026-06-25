import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/network/remote_api_guard.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../../core/utils/time.dart';
import '../../domain/entities/shop_entities.dart';
import '../../domain/repositories/shop_repository.dart';
import '../datasources/remote/shop_remote_datasource.dart';
import '../models/shop_api_models.dart';

class ShopRepositoryImpl implements ShopRepository {
  ShopRepositoryImpl({
    required ShopRemoteDatasource remote,
    required AppDatabase database,
    RemoteApiGuard? apiGuard,
    NetworkInfo? networkInfo,
  })  : _remote = remote,
        _db = database,
        _apiGuard = apiGuard,
        _networkInfo = networkInfo ?? const NetworkInfo.alwaysOffline();

  final ShopRemoteDatasource _remote;
  final AppDatabase _db;
  final RemoteApiGuard? _apiGuard;
  final NetworkInfo _networkInfo;

  @override
  Future<ShopListResult> listShops() async {
    await _ensureOnline();
    final dto = await _remote.listShops();
    await _syncShopsLocally(dto.shops);
    return _mapList(dto);
  }

  @override
  Future<ManagedShop> getShop(int id) async {
    await _ensureOnline();
    final dto = await _remote.getShop(id);
    await _upsertShopLocally(dto);
    return _mapDetail(dto, isCurrent: false);
  }

  @override
  Future<ManagedShop> createShop(CreateShopInput input) async {
    await _ensureOnline();
    final dto = await _remote.createShop(
      name: input.name,
      address: input.address,
      phone: input.phone,
    );
    await _upsertShopLocally(dto);
    return _mapDetail(dto, isCurrent: false);
  }

  @override
  Future<ManagedShop> updateShop(int id, UpdateShopInput input) async {
    await _ensureOnline();
    final dto = await _remote.updateShop(
      id,
      name: input.name,
      address: input.address,
      phone: input.phone,
    );
    await _upsertShopLocally(dto);
    return _mapDetail(dto, isCurrent: false);
  }

  @override
  Future<void> deactivateShop(int id, {String? reason}) async {
    await _ensureOnline();
    await _remote.deactivateShop(id, reason: reason);
    final localId = await _resolveLocalShopId(id);
    await (_db.update(_db.shops)..where((s) => s.id.equals(localId))).write(
      ShopsCompanion(
        isActive: const Value(false),
        syncedAt: Value(nowMs()),
      ),
    );
  }

  @override
  Future<void> setDefaultShop(int id) async {
    await _ensureOnline();
    await _remote.setDefaultShop(id);
    await _db.update(_db.shops).write(
      const ShopsCompanion(isDefault: Value(false)),
    );
    final localId = await _resolveLocalShopId(id);
    await (_db.update(_db.shops)..where((s) => s.id.equals(localId))).write(
      ShopsCompanion(
        isDefault: const Value(true),
        syncedAt: Value(nowMs()),
      ),
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
        'Connexion internet requise pour gérer les boutiques.',
      );
    }
  }

  ShopListResult _mapList(ShopListDataDto dto) {
    return ShopListResult(
      activeShopId: dto.activeShopId,
      shops: dto.shops.map(_mapListItem).toList(),
    );
  }

  ManagedShop _mapListItem(ShopItemDto dto) {
    return ManagedShop(
      id: dto.id,
      name: dto.name,
      address: dto.address,
      phone: dto.phone,
      isActive: dto.isActive,
      isDefault: dto.isDefault,
      isCurrent: dto.isCurrent,
      createdAt: dto.createdAt,
    );
  }

  ManagedShop _mapDetail(ShopDetailDto dto, {required bool isCurrent}) {
    return ManagedShop(
      id: dto.id,
      name: dto.name,
      address: dto.address,
      phone: dto.phone,
      isActive: dto.isActive,
      isDefault: dto.isDefault,
      isCurrent: isCurrent,
      createdAt: dto.createdAt,
    );
  }

  Future<void> _syncShopsLocally(List<ShopItemDto> shops) async {
    for (final shop in shops) {
      await _upsertShopLocally(
        ShopDetailDto(
          id: shop.id,
          name: shop.name,
          address: shop.address,
          phone: shop.phone,
          isActive: shop.isActive,
          isDefault: shop.isDefault,
          createdAt: shop.createdAt,
        ),
      );
    }
  }

  Future<void> _upsertShopLocally(ShopDetailDto dto) async {
    final existing = await (_db.select(_db.shops)
          ..where((s) => s.serverId.equals('${dto.id}')))
        .getSingleOrNull();

    final timestamp = nowMs();
    if (existing == null) {
      await _db.into(_db.shops).insert(
            ShopsCompanion.insert(
              name: Value(dto.name),
              address: Value(dto.address),
              phone: Value(dto.phone),
              isActive: Value(dto.isActive),
              isDefault: Value(dto.isDefault),
              createdAt: dto.createdAt ?? timestamp,
              serverId: Value('${dto.id}'),
              syncedAt: Value(timestamp),
            ),
          );
      return;
    }

    await (_db.update(_db.shops)..where((s) => s.id.equals(existing.id))).write(
      ShopsCompanion(
        name: Value(dto.name),
        address: Value(dto.address),
        phone: Value(dto.phone),
        isActive: Value(dto.isActive),
        isDefault: Value(dto.isDefault),
        syncedAt: Value(timestamp),
      ),
    );
  }

  Future<int> _resolveLocalShopId(int serverShopId) async {
    final byServer = await (_db.select(_db.shops)
          ..where((s) => s.serverId.equals('$serverShopId')))
        .getSingleOrNull();
    if (byServer != null) return byServer.id;

    final byId = await (_db.select(_db.shops)
          ..where((s) => s.id.equals(serverShopId)))
        .getSingleOrNull();
    if (byId != null) return byId.id;

    throw NotFoundFailure('Boutique locale introuvable (id $serverShopId).');
  }
}
