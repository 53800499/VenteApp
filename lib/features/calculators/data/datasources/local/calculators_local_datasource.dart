import 'dart:convert';
import 'package:drift/drift.dart';
import '../../../../../core/database/app_database.dart' as db;
import '../../../../../core/utils/time.dart';

class CalculatorsLocalDatasource {
  CalculatorsLocalDatasource(this._db);

  final db.AppDatabase _db;

  Future<db.TenantModule?> getModuleStatus(int shopId, String moduleCode) async {
    return await (_db.select(_db.tenantModules)
          ..where((t) => t.shopId.equals(shopId) & t.moduleCode.equals(moduleCode))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> saveModuleStatus(int shopId, String moduleCode, bool enabled) async {
    final timestamp = nowMs();
    final existing = await getModuleStatus(shopId, moduleCode);

    if (existing != null) {
      await (_db.update(_db.tenantModules)
            ..where((t) => t.id.equals(existing.id)))
          .write(
        db.TenantModulesCompanion(
          enabled: Value(enabled),
        ),
      );
    } else {
      await _db.into(_db.tenantModules).insert(
            db.TenantModulesCompanion.insert(
              shopId: shopId,
              moduleCode: moduleCode,
              enabled: Value(enabled),
              createdAt: timestamp,
            ),
          );
    }
  }

  Future<List<db.CalculatorProductDataData>> getProductConfigs(int shopId) async {
    return await (_db.select(_db.calculatorProductData)
          ..where((c) => c.shopId.equals(shopId)))
        .get();
  }

  Future<db.CalculatorProductDataData?> getProductConfig(int shopId, int productId) async {
    return await (_db.select(_db.calculatorProductData)
          ..where((c) => c.shopId.equals(shopId) & c.productId.equals(productId))
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> saveProductConfig(db.CalculatorProductDataCompanion companion) async {
    final shopId = companion.shopId.value;
    final productId = companion.productId.value;

    final existing = await getProductConfig(shopId, productId);
    if (existing != null) {
      await (_db.update(_db.calculatorProductData)
            ..where((c) => c.id.equals(existing.id)))
          .write(companion.copyWith(
            version: Value(existing.version + 1),
            syncStatus: const Value('pending'),
          ));
    } else {
      await _db.into(_db.calculatorProductData).insert(
            companion.copyWith(
              version: const Value(1),
              syncStatus: const Value('pending'),
            ),
          );
    }
  }

  Future<List<db.CalculatorHistoryData>> getHistory(int shopId) async {
    return await (_db.select(_db.calculatorHistory)
          ..where((c) => c.shopId.equals(shopId))
          ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
        .get();
  }

  Future<db.CalculatorHistoryData> insertHistory(db.CalculatorHistoryCompanion companion) async {
    final id = await _db.into(_db.calculatorHistory).insert(companion);
    return await (_db.select(_db.calculatorHistory)..where((c) => c.id.equals(id))).getSingle();
  }

  Future<void> upsertFromRemoteProductConfig(db.CalculatorProductDataCompanion companion) async {
    final shopId = companion.shopId.value;
    final productId = companion.productId.value;

    final existing = await getProductConfig(shopId, productId);
    if (existing != null) {
      await (_db.update(_db.calculatorProductData)
            ..where((c) => c.id.equals(existing.id)))
          .write(companion.copyWith(
            syncStatus: const Value('synced'),
          ));
    } else {
      await _db.into(_db.calculatorProductData).insert(
            companion.copyWith(
              syncStatus: const Value('synced'),
            ),
          );
    }
  }

  Future<void> upsertFromRemoteHistory(db.CalculatorHistoryCompanion companion) async {
    final serverId = companion.serverId.value;
    if (serverId == null) return;

    final existing = await (_db.select(_db.calculatorHistory)
          ..where((c) => c.serverId.equals(serverId))
          ..limit(1))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.calculatorHistory)
            ..where((c) => c.id.equals(existing.id)))
          .write(companion.copyWith(
            syncStatus: const Value('synced'),
          ));
    } else {
      await _db.into(_db.calculatorHistory).insert(
            companion.copyWith(
              syncStatus: const Value('synced'),
            ),
          );
    }
  }

  Future<void> updateServerSyncProductConfig(int id, String serverId) async {
    await (_db.update(_db.calculatorProductData)
          ..where((c) => c.id.equals(id)))
        .write(
      db.CalculatorProductDataCompanion(
        serverId: Value(serverId),
        syncedAt: Value(nowMs()),
        syncStatus: const Value('synced'),
      ),
    );
  }

  Future<void> updateServerSyncHistory(int id, String serverId) async {
    await (_db.update(_db.calculatorHistory)
          ..where((c) => c.id.equals(id)))
        .write(
      db.CalculatorHistoryCompanion(
        serverId: Value(serverId),
        syncedAt: Value(nowMs()),
        syncStatus: const Value('synced'),
      ),
    );
  }
}
