import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../errors/failures.dart';
import '../utils/time.dart';
import 'shop_backup_crypto.dart';

class ShopBackupFile {
  const ShopBackupFile({
    required this.bytes,
    required this.filename,
  });

  final List<int> bytes;
  final String filename;
}

class ShopJsonExport {
  const ShopJsonExport({
    required this.json,
    required this.filename,
  });

  final String json;
  final String filename;
}

/// Export / restauration locale boutique (RG-PARAM-04/06/07/08).
class ShopBackupService {
  ShopBackupService(this._db);

  final AppDatabase _db;

  static const _shopTables = [
    'categories',
    'products',
    'customers',
    'sales',
    'sale_items',
    'debts',
    'stock_movements',
    'audit_logs',
    'sync_queue',
    'notification_daily_states',
  ];

  Future<ShopBackupFile> createEncryptedBackup({
    required int shopId,
    required String passphrase,
    required String shopName,
  }) async {
    final payload = await _buildPayload(shopId: shopId, shopName: shopName);
    final envelope = ShopBackupCrypto.seal(
      const JsonEncoder.withIndent('  ').convert(payload),
      passphrase,
    );
    final bytes = utf8.encode(const JsonEncoder.withIndent('  ').convert(envelope));
    final safeName = _safeFileName(shopName);
    final date = DateTime.now();
    final stamp =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    return ShopBackupFile(
      bytes: bytes,
      filename: '${safeName}_$stamp.venteapp',
    );
  }

  Future<ShopJsonExport> exportReadableJson({
    required int shopId,
    required String shopName,
  }) async {
    final payload = await _buildPayload(
      shopId: shopId,
      shopName: shopName,
      maskSecrets: true,
    );
    final safeName = _safeFileName(shopName);
    final date = DateTime.now();
    final stamp =
        '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    return ShopJsonExport(
      json: const JsonEncoder.withIndent('  ').convert(payload),
      filename: '${safeName}_$stamp.json',
    );
  }

  Future<void> restoreEncryptedBackup({
    required int shopId,
    required List<int> bytes,
    required String passphrase,
  }) async {
    final Map<String, dynamic> envelope;
    try {
      envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } catch (_) {
      throw const ValidationFailure('Fichier .venteapp illisible.');
    }

    final plaintext = ShopBackupCrypto.open(envelope, passphrase);
    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(plaintext) as Map<String, dynamic>;
    } catch (_) {
      throw const ValidationFailure('Contenu de sauvegarde invalide.');
    }

    if (payload['format'] != 'venteapp-shop-export') {
      throw const ValidationFailure('Format de données incompatible.');
    }
    final backupShopId = payload['shopId'] as int?;
    if (backupShopId != null && backupShopId != shopId) {
      throw const ValidationFailure(
        'Cette sauvegarde appartient à une autre boutique.',
      );
    }

    final tables = payload['tables'] as Map<String, dynamic>?;
    if (tables == null) {
      throw const ValidationFailure('Sauvegarde incomplète.');
    }

    await _db.transaction(() async {
      await _clearShopData(shopId);
      await _updateShopRow(shopId, tables['shops']);
      await _insertTableRows('users', tables['users']);
      await _insertTableRows('settings', tables['settings']);
      for (final table in _shopTables) {
        await _insertTableRows(table, tables[table]);
      }
    });
  }

  Future<void> _updateShopRow(int shopId, Object? rawRows) async {
    if (rawRows is! List || rawRows.isEmpty) return;
    final raw = rawRows.first;
    if (raw is! Map) return;
    final row = Map<String, Object?>.from(raw)..remove('id');
    if (row.isEmpty) return;

    final columns = row.keys.toList();
    final setClause = columns.map((c) => '$c = ?').join(', ');
    await _db.customUpdate(
      'UPDATE shops SET $setClause WHERE id = ?',
      variables: [
        ...columns.map((c) => Variable<Object>(row[c] as Object)),
        Variable<int>(shopId),
      ],
    );
  }

  Future<Map<String, dynamic>> _buildPayload({
    required int shopId,
    required String shopName,
    bool maskSecrets = false,
  }) async {
    final shops = await _selectRows('shops', 'id = ?', [shopId]);
    final users = await _selectRows('users', 'shop_id = ?', [shopId]);
    if (maskSecrets) {
      for (final row in users) {
        row['pin_hash'] = '***';
        row['emergency_recovery_hash'] = null;
      }
    }

    final tables = <String, dynamic>{
      'shops': shops,
      'users': users,
      'settings': await _selectRows('settings', 'shop_id = ?', [shopId]),
    };
    for (final table in _shopTables) {
      tables[table] = await _selectRows(table, 'shop_id = ?', [shopId]);
    }

    return {
      'format': 'venteapp-shop-export',
      'version': 1,
      'exportedAt': nowMs(),
      'shopId': shopId,
      'shopName': shopName,
      'tables': tables,
    };
  }

  Future<List<Map<String, Object?>>> _selectRows(
    String table,
    String whereClause,
    List<Object?> args,
  ) async {
    final rows = await _db.customSelect(
      'SELECT * FROM $table WHERE $whereClause',
      variables: args.map((a) => Variable<Object>(a as Object)).toList(),
    ).get();
    return rows.map((row) => Map<String, Object?>.from(row.data)).toList();
  }

  Future<void> _clearShopData(int shopId) async {
    const deletes = [
      'DELETE FROM sale_items WHERE shop_id = ?',
      'DELETE FROM debts WHERE shop_id = ?',
      'DELETE FROM stock_movements WHERE shop_id = ?',
      'DELETE FROM sales WHERE shop_id = ?',
      'DELETE FROM products WHERE shop_id = ?',
      'DELETE FROM categories WHERE shop_id = ?',
      'DELETE FROM customers WHERE shop_id = ?',
      'DELETE FROM audit_logs WHERE shop_id = ?',
      'DELETE FROM sync_queue WHERE shop_id = ?',
      'DELETE FROM notification_daily_states WHERE shop_id = ?',
      'DELETE FROM settings WHERE shop_id = ?',
      'DELETE FROM users WHERE shop_id = ?',
    ];
    for (final sql in deletes) {
      await _db.customStatement(sql, [shopId]);
    }
  }

  Future<void> _insertTableRows(
    String table,
    Object? rawRows,
  ) async {
    if (rawRows is! List || rawRows.isEmpty) return;

    for (final raw in rawRows) {
      if (raw is! Map) continue;
      final row = Map<String, Object?>.from(raw);
      final columns = row.keys.toList();
      final placeholders = List.filled(columns.length, '?').join(', ');
      final sql =
          'INSERT INTO $table (${columns.join(', ')}) VALUES ($placeholders)';
      await _db.customInsert(
        sql,
        variables: columns
            .map((c) => Variable<Object>(row[c] as Object))
            .toList(),
      );
    }
  }

  String _safeFileName(String name) {
    final cleaned = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? 'boutique' : cleaned;
  }
}
