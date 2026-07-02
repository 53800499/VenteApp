import 'package:drift/drift.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/network/remote_api_runner.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/time.dart';
import '../../domain/entities/shop_entities.dart';
import '../../domain/repositories/shop_repository.dart';
import '../datasources/remote/shop_remote_datasource.dart';
import '../models/shop_api_models.dart';

class ShopRepositoryImpl implements ShopRepository {
  ShopRepositoryImpl({
    required ShopRemoteDatasource remote,
    required AppDatabase database,
    required RemoteApiRunner apiRunner,
  })  : _remote = remote,
        _db = database,
        _apiRunner = apiRunner;

  final ShopRemoteDatasource _remote;
  final AppDatabase _db;
  final RemoteApiRunner _apiRunner;

  static const _writeOfflineMessage =
      'Connexion serveur requise pour gérer les boutiques. '
      'Vérifiez le réseau (Plus → Connexion serveur).';

  @override
  Future<ShopListResult> listShops() async {
    return _apiRunner.runOnlinePreferredRead(
      remote: () async {
        final dto = await _remote.listShops();
        await _syncShopsLocally(dto.shops);
        return _mapList(dto);
      },
      localFallback: _listShopsLocally,
    );
  }

  @override
  Future<ManagedShop> getShop(int id) async {
    return _apiRunner.runOnlineRequiredWrite(
      offlineMessage: _writeOfflineMessage,
      remote: () async {
        final dto = await _remote.getShop(id);
        await _upsertShopLocally(dto);
        return _mapDetail(dto, isCurrent: false);
      },
    );
  }

  @override
  Future<ManagedShop> createShop(CreateShopInput input) async {
    return _apiRunner.runOnlineRequiredWrite(
      offlineMessage: _writeOfflineMessage,
      remote: () async {
        final dto = await _remote.createShop(
          name: input.name,
          address: input.address,
          phone: input.phone,
        );
        await _upsertShopLocally(dto);
        return _mapDetail(dto, isCurrent: false);
      },
    );
  }

  @override
  Future<ManagedShop> updateShop(int id, UpdateShopInput input) async {
    return _apiRunner.runOnlineRequiredWrite(
      offlineMessage: _writeOfflineMessage,
      remote: () async {
        final dto = await _remote.updateShop(
          id,
          name: input.name,
          address: input.address,
          phone: input.phone,
        );
        await _upsertShopLocally(dto);
        return _mapDetail(dto, isCurrent: false);
      },
    );
  }

  @override
  Future<void> deactivateShop(int id, {String? reason}) async {
    await _apiRunner.runOnlineRequiredWrite(
      offlineMessage: _writeOfflineMessage,
      remote: () async {
        await _remote.deactivateShop(id, reason: reason);
        final localId = await _resolveLocalShopId(id);
        await (_db.update(_db.shops)..where((s) => s.id.equals(localId))).write(
          ShopsCompanion(
            isActive: const Value(false),
            syncedAt: Value(nowMs()),
          ),
        );
      },
    );
  }

  @override
  Future<void> setDefaultShop(int id) async {
    await _apiRunner.runOnlineRequiredWrite(
      offlineMessage: _writeOfflineMessage,
      remote: () async {
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
      },
    );
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

  Future<ShopListResult> _listShopsLocally() async {
    final rows = await (_db.select(_db.shops)
          ..orderBy([(s) => OrderingTerm.desc(s.isDefault)]))
        .get();

    if (rows.isEmpty) {
      return const ShopListResult(activeShopId: 0, shops: []);
    }

    final shops = rows.map((row) {
      final serverId = int.tryParse(row.serverId ?? '') ?? row.id;
      return ManagedShop(
        id: serverId,
        name: row.name,
        address: row.address,
        phone: row.phone,
        isActive: row.isActive,
        isDefault: row.isDefault,
        isCurrent: row.isDefault,
        createdAt: row.createdAt,
      );
    }).toList();

    final activeId = shops.firstWhere((s) => s.isDefault, orElse: () => shops.first).id;
    return ShopListResult(activeShopId: activeId, shops: shops);
  }
}
