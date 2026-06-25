import '../entities/shop_entities.dart';

abstract class ShopRepository {
  Future<ShopListResult> listShops();

  Future<ManagedShop> getShop(int id);

  Future<ManagedShop> createShop(CreateShopInput input);

  Future<ManagedShop> updateShop(int id, UpdateShopInput input);

  Future<void> deactivateShop(int id, {String? reason});

  Future<void> setDefaultShop(int id);
}
