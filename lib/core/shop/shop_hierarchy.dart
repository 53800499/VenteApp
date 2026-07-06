import '../database/app_database.dart';

/// Réseau commercial : boutique racine + sous-boutiques créées depuis elle.
class ShopHierarchy {
  const ShopHierarchy._();

  static int resolveRootShopId(List<Shop> shops, int contextShopId) {
    final byId = {for (final shop in shops) shop.id: shop};
    var current = byId[contextShopId];
    if (current == null) return contextShopId;

    var depth = 0;
    while (current!.parentShopId != null && depth < 10) {
      final parent = byId[current.parentShopId!];
      if (parent == null) break;
      current = parent;
      depth++;
    }
    return current.id;
  }

  static List<int> groupShopIds(List<Shop> shops, int contextShopId) {
    final rootId = resolveRootShopId(shops, contextShopId);
    final ids = shops
        .where(
          (shop) =>
              shop.isActive &&
              (shop.id == rootId || shop.parentShopId == rootId),
        )
        .map((shop) => shop.id)
        .toList();
    return ids.isEmpty ? [contextShopId] : ids;
  }

  static Future<List<int>> groupShopIdsFromDb(
    AppDatabase db,
    int contextShopId,
  ) async {
    final shops = await db.select(db.shops).get();
    return groupShopIds(shops, contextShopId);
  }
}
