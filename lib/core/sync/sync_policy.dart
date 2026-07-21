import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'app_release_tier.dart';
import 'cloud_sync_enabler.dart';
import 'sync_pull_entity.dart';

/// Résout le comportement de sync selon V1 / V2 / V3 (SFD §13, BDD §3).
class SyncPolicy {
  SyncPolicy(
    this._db,
    this._cloudSyncEnabler,
  );

  final AppDatabase _db;
  final CloudSyncEnabler _cloudSyncEnabler;

  Future<SyncContext> resolve({required int shopId}) async {
    await _cloudSyncEnabler.activateForShop(shopId);

    final settings = await (_db.select(_db.settings)
          ..where((s) => s.shopId.equals(shopId)))
        .getSingleOrNull();

    final cloudSyncEnabled = settings?.cloudSyncEnabled ?? true;
    final activeShops = await (_db.select(_db.shops)
          ..where((s) => s.isActive.equals(true)))
        .get();

    final tier = activeShops.length > 1
        ? AppReleaseTier.v3
        : cloudSyncEnabled
            ? AppReleaseTier.v2
            : AppReleaseTier.v1;

    return SyncContext(
      tier: tier,
      shopId: shopId,
      cloudSyncEnabled: cloudSyncEnabled,
      activeShopCount: activeShops.length,
    );
  }

  Future<bool> shouldRunCloudSync({required int shopId}) async {
    final context = await resolve(shopId: shopId);
    return context.shouldRunCloudPull;
  }

  /// Indique si un pull navigation doit être lancé (stale time ou [force]).
  Future<bool> shouldPullEntity({
    required int shopId,
    required String entity,
    bool force = false,
  }) async {
    if (force) return true;

    final context = await resolve(shopId: shopId);
    if (!context.shouldRunCloudPull) return false;

    final row = await (_db.select(_db.syncEntityCache)
          ..where(
            (c) => c.shopId.equals(shopId) & c.entity.equals(entity),
          ))
        .getSingleOrNull();
    if (row == null) return true;

    final stale = SyncPullEntity.staleTimeFor(entity);
    final lastSynced = DateTime.fromMillisecondsSinceEpoch(row.lastSyncedAt);
    return DateTime.now().difference(lastSynced) >= stale;
  }

  /// Horodatage du dernier pull réussi pour [entity], ou null si jamais.
  Future<int?> entityLastSyncedAt({
    required int shopId,
    required String entity,
  }) async {
    final row = await (_db.select(_db.syncEntityCache)
          ..where(
            (c) => c.shopId.equals(shopId) & c.entity.equals(entity),
          ))
        .getSingleOrNull();
    return row?.lastSyncedAt;
  }

  /// Curseur delta : lastSync - marge (réseau / horloges), pour ne pas rater
  /// des updates frontière.
  Future<int?> entityUpdatedAfterCursor({
    required int shopId,
    required String entity,
    Duration skew = const Duration(minutes: 2),
  }) async {
    final last = await entityLastSyncedAt(shopId: shopId, entity: entity);
    if (last == null) return null;
    return last - skew.inMilliseconds;
  }

  Future<void> markEntitySynced({
    required int shopId,
    required String entity,
  }) async {
    await _db.into(_db.syncEntityCache).insertOnConflictUpdate(
          SyncEntityCacheCompanion.insert(
            shopId: shopId,
            entity: entity,
            lastSyncedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
  }

  /// Invalide le cache pull après une écriture locale (file sync_queue).
  Future<void> invalidateEntitiesForWrite({
    required int shopId,
    required String entityTable,
    int? recordId,
  }) async {
    final entities = SyncPullEntity.invalidatedByWrite(
      entityTable,
      recordId: recordId,
    );
    if (entities.isEmpty) return;

    await (_db.delete(_db.syncEntityCache)
          ..where(
            (c) => c.shopId.equals(shopId) & c.entity.isIn(entities),
          ))
        .go();
  }
}

class SyncContext {
  const SyncContext({
    required this.tier,
    required this.shopId,
    required this.cloudSyncEnabled,
    required this.activeShopCount,
  });

  final AppReleaseTier tier;
  final int shopId;
  final bool cloudSyncEnabled;
  final int activeShopCount;

  /// Pull/push cloud : V2/V3 uniquement, et seulement si activé dans les paramètres.
  bool get shouldRunCloudPull => tier.supportsCloudSync && cloudSyncEnabled;

  /// V1 : écriture locale seule. V2/V3 : file d'attente en plus (couche 2).
  bool get shouldUseSyncQueue => tier.supportsSyncQueue && cloudSyncEnabled;
}
