import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Brouillons de formulaires (client, produit, vente) par boutique.
class FormDraftStorage {
  FormDraftStorage(this._prefs);

  final SharedPreferences _prefs;

  Future<void> save(String key, Map<String, dynamic> data) async {
    await _prefs.setString(
      'form_draft_$key',
      jsonEncode({...data, 'savedAt': DateTime.now().toIso8601String()}),
    );
  }

  Future<Map<String, dynamic>?> read(String key) async {
    final raw = _prefs.getString('form_draft_$key');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  Future<void> clear(String key) async {
    await _prefs.remove('form_draft_$key');
  }

  static String customerKey(int shopId, {int? customerId}) =>
      'customer_${shopId}_${customerId ?? 'new'}';

  static String productKey(int shopId, {int? productId}) =>
      'product_${shopId}_${productId ?? 'new'}';

  static String saleKey(int shopId) => 'sale_$shopId';
}
