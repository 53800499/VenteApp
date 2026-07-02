import 'dart:convert';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../utils/time.dart';

/// Écriture locale du journal d'audit (hors ligne).
class LocalAuditWriter {
  LocalAuditWriter(this._db);

  final AppDatabase _db;

  Future<void> record({
    required int shopId,
    required int userId,
    required String action,
    required String module,
    required int entityId,
    required String entityTable,
    String? reason,
    Map<String, dynamic>? oldValue,
    Map<String, dynamic>? newValue,
  }) async {
    await _db.into(_db.auditLogs).insert(
          AuditLogsCompanion.insert(
            shopId: shopId,
            userId: userId,
            action: action,
            module: module,
            entityId: entityId,
            entityTable: entityTable,
            oldValue: Value(
              oldValue == null ? null : jsonEncode(oldValue),
            ),
            newValue: Value(
              newValue == null ? null : jsonEncode(newValue),
            ),
            reason: Value(reason),
            createdAt: nowMs(),
          ),
        );
  }
}
