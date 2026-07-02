import '../database/app_database.dart';
import 'app_release_tier.dart';
import 'cloud_sync_enabler.dart';

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
