import '../../../../core/utils/currency_formatter.dart';

/// Présente les payloads d'audit en libellés FR compréhensibles.
class AuditValuePresenter {
  const AuditValuePresenter();

  static const _fieldLabels = <String, String>{
    'id': 'Identifiant',
    'name': 'Nom',
    'phone': 'Téléphone',
    'email': 'E-mail',
    'address': 'Adresse',
    'notes': 'Notes',
    'note': 'Note',
    'role': 'Rôle',
    'status': 'Statut',
    'price': 'Prix',
    'priceSell': 'Prix de vente',
    'priceBuy': 'Prix d\'achat',
    'priceSemiWholesale': 'Prix semi-gros',
    'priceWholesale': 'Prix gros',
    'quantity': 'Quantité',
    'quantityInStock': 'Stock',
    'sku': 'Référence',
    'barcode': 'Code-barres',
    'categoryId': 'Catégorie',
    'categoryName': 'Catégorie',
    'customerId': 'Client',
    'customerName': 'Client',
    'productId': 'Produit',
    'productName': 'Produit',
    'shopId': 'Boutique',
    'shopName': 'Boutique',
    'userId': 'Utilisateur',
    'userName': 'Utilisateur',
    'total': 'Total',
    'subtotal': 'Sous-total',
    'discountAmount': 'Remise',
    'amount': 'Montant',
    'paidAmount': 'Montant payé',
    'remainingAmount': 'Reste dû',
    'paymentMethod': 'Mode de paiement',
    'saleType': 'Type de vente',
    'receiptNumber': 'N° reçu',
    'isActive': 'Actif',
    'isArchived': 'Archivé',
    'isDefault': 'Par défaut',
    'biometricEnabled': 'Biométrie',
    'autoLockMinutes': 'Verrouillage auto (min)',
    'currency': 'Devise',
    'shopLogoPath': 'Logo',
    'openingCash': 'Fond espèces',
    'openingMomo': 'Fond Mobile Money',
    'countedCash': 'Espèces comptées',
    'countedMomo': 'Mobile Money compté',
    'closingNote': 'Note de clôture',
    'reason': 'Motif',
    'createdAt': 'Créé le',
    'updatedAt': 'Modifié le',
    'deletedAt': 'Supprimé le',
    'lockedUntil': 'Verrouillé jusqu\'au',
    'lastLoginAt': 'Dernière connexion',
    'serverId': 'ID serveur',
    'syncStatus': 'Statut sync',
    'permissions': 'Permissions',
    'overrides': 'Exceptions',
    'items': 'Lignes',
    'unitPrice': 'Prix unitaire',
    'lineTotal': 'Total ligne',
    'movementType': 'Type de mouvement',
    'registerType': 'Caisse',
    'expenseCategory': 'Catégorie dépense',
    'description': 'Description',
    'label': 'Libellé',
    'code': 'Code',
    'type': 'Type',
    'enabled': 'Activé',
    'cloudSyncEnabled': 'Sync cloud',
    'fromRole': 'Ancien rôle',
    'toRole': 'Nouveau rôle',
    'oldPrice': 'Ancien prix',
    'newPrice': 'Nouveau prix',
    'delta': 'Écart',
    'before': 'Avant',
    'after': 'Après',
  };

  static const _entityLabels = <String, String>{
    'products': 'Produit',
    'customers': 'Client',
    'sales': 'Vente',
    'sale_items': 'Ligne de vente',
    'debts': 'Créance',
    'users': 'Utilisateur',
    'shops': 'Boutique',
    'settings': 'Paramètres',
    'categories': 'Catégorie',
    'expenses': 'Dépense',
    'cash_sessions': 'Session de caisse',
    'cash_movements': 'Mouvement de caisse',
    'stock_movements': 'Mouvement de stock',
    'auth_sessions': 'Session',
    'sync_queue': 'File de sync',
  };

  String entityLabel(String table) =>
      _entityLabels[table] ?? table.replaceAll('_', ' ');

  String fieldLabel(String key) {
    if (_fieldLabels.containsKey(key)) return _fieldLabels[key]!;
    // camelCase / snake_case → libellé approximatif
    final spaced = key
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ');
    if (spaced.isEmpty) return key;
    return spaced[0].toUpperCase() + spaced.substring(1);
  }

  String formatValue(dynamic value) {
    if (value == null) return '—';
    if (value is bool) return value ? 'Oui' : 'Non';
    if (value is num) {
      if (value is int && value > 1e11) {
        return _formatDateTime(value);
      }
      return value.toString();
    }
    if (value is String) {
      if (value.isEmpty) return '—';
      return value;
    }
    if (value is List) {
      if (value.isEmpty) return 'Aucun';
      return '${value.length} élément(s)';
    }
    if (value is Map) {
      return '${value.length} champ(s)';
    }
    return value.toString();
  }

  String formatField(String key, dynamic value) {
    if (value == null) return '—';
    final lower = key.toLowerCase();
    final isMoney = lower.contains('price') ||
        lower.contains('amount') ||
        lower.contains('total') ||
        lower.contains('cash') ||
        lower.contains('momo') ||
        lower.contains('subtotal') ||
        lower.contains('discount') ||
        lower == 'delta';
    if (isMoney && value is num) {
      return formatFcfa(value.round());
    }
    if ((lower.endsWith('at') ||
            lower.contains('date') ||
            lower.contains('until')) &&
        value is int &&
        value > 1e11) {
      return _formatDateTime(value);
    }
    if (lower == 'paymentmethod' || lower == 'payment_method') {
      return _paymentLabel('$value');
    }
    if (lower == 'role') return _roleLabel('$value');
    if (lower == 'status') return _statusLabel('$value');
    return formatValue(value);
  }

  /// Lignes clé/valeur aplaties (1 niveau + résumé des maps/listes).
  List<({String label, String value})> rowsFrom(Map<String, dynamic> data) {
    final rows = <({String label, String value})>[];
    final keys = data.keys.toList()..sort();
    for (final key in keys) {
      if (_isInternalKey(key)) continue;
      rows.add((label: fieldLabel(key), value: formatField(key, data[key])));
    }
    return rows;
  }

  /// Diff avant/après : champs modifiés en premier, puis ajouts/suppressions.
  List<AuditFieldDiff> diff({
    Map<String, dynamic>? before,
    Map<String, dynamic>? after,
  }) {
    final oldMap = before ?? const <String, dynamic>{};
    final newMap = after ?? const <String, dynamic>{};
    final keys = {...oldMap.keys, ...newMap.keys}.toList()..sort();
    final diffs = <AuditFieldDiff>[];

    for (final key in keys) {
      if (_isInternalKey(key)) continue;
      final oldVal = oldMap[key];
      final newVal = newMap[key];
      if (_deepEquals(oldVal, newVal)) continue;
      diffs.add(
        AuditFieldDiff(
          key: key,
          label: fieldLabel(key),
          before: oldMap.containsKey(key) ? formatField(key, oldVal) : null,
          after: newMap.containsKey(key) ? formatField(key, newVal) : null,
        ),
      );
    }
    return diffs;
  }

  bool _isInternalKey(String key) {
    const skip = {
      'serverId',
      'syncedAt',
      'syncStatus',
      'localVersion',
      'pinHash',
      'passwordHash',
      'token',
      'refreshToken',
    };
    return skip.contains(key);
  }

  bool _deepEquals(dynamic a, dynamic b) {
    if (a == b) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return false;
  }

  String _paymentLabel(String code) => switch (code) {
        'cash' => 'Espèces',
        'momo' || 'mtn_momo' => 'Mobile Money',
        'moov_money' => 'Moov Money',
        'credit' => 'Crédit',
        'mixed' => 'Mixte',
        _ => code,
      };

  String _roleLabel(String code) => switch (code) {
        'owner' => 'Patron',
        'manager' => 'Gérant',
        'cashier' => 'Caissier',
        'seller' => 'Vendeur',
        _ => code,
      };

  String _statusLabel(String code) => switch (code) {
        'open' => 'Ouverte',
        'closed' => 'Clôturée',
        'active' => 'Actif',
        'inactive' => 'Inactif',
        'pending' => 'En attente',
        'cancelled' => 'Annulé',
        'paid' => 'Payé',
        'partial' => 'Partiel',
        _ => code,
      };

  String _formatDateTime(int ms) {
    const offset = 60 * 60 * 1000;
    final local = DateTime.fromMillisecondsSinceEpoch(ms + offset, isUtc: true);
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m/${local.year} à $h:$min';
  }
}

class AuditFieldDiff {
  const AuditFieldDiff({
    required this.key,
    required this.label,
    this.before,
    this.after,
  });

  final String key;
  final String label;
  final String? before;
  final String? after;
}
