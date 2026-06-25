/// Boutique active côté serveur (header `X-Shop-Id` sur les requêtes API).
class ActiveShopContext {
  int? _serverShopId;

  int? get serverShopId => _serverShopId;

  void setServerShopId(int? shopId) {
    _serverShopId = shopId;
  }

  void clear() => _serverShopId = null;
}
