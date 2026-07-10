import 'package:shared_preferences/shared_preferences.dart';

/// Dernière boutique utilisée pour l'écran PIN au démarrage.
class LastShopStorage {
  LastShopStorage(this._prefs);

  static const _lastShopIdKey = 'last_shop_id';

  final SharedPreferences _prefs;

  int get lastShopId => _prefs.getInt(_lastShopIdKey) ?? 1;

  Future<void> save(int shopId) async {
    await _prefs.setInt(_lastShopIdKey, shopId);
  }

  Future<void> clear() async {
    await _prefs.remove(_lastShopIdKey);
  }
}
