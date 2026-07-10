import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../utils/time.dart';
import 'sync_constants.dart';
import 'sync_policy.dart';

/// Couche 2 — file d'attente locale (V2/V3, BDD §3.2).
class SyncQueueDatasource {
  SyncQueueDatasource(this._db);

  final AppDatabase _db;

  static const maxRetries = 5;

  Future<int> countPending({required int shopId}) async {
    final rows = await (_db.select(_db.syncQueue)
          ..where(
            (q) =>
                q.shopId.equals(shopId) &
                q.status.equals('pending'),
          ))
        .get();
    return rows.length;
  }

  Future<int> countConflicts({required int shopId}) async {
    final rows = await (_db.select(_db.syncQueue)
          ..where(
            (q) =>
                q.shopId.equals(shopId) &
                q.status.equals('conflict'),
          ))
        .get();
    return rows.length;
  }

  Future<List<SyncQueueData>> fetchConflicts({
    required int shopId,
  }) async {
    return (_db.select(_db.syncQueue)
          ..where(
            (q) =>
                q.shopId.equals(shopId) &
                q.status.equals('conflict'),
          )
          ..orderBy([(q) => OrderingTerm.desc(q.processedAt)]))
        .get();
  }

  Future<void> requeueConflict(int queueId) async {
    await (_db.update(_db.syncQueue)..where((q) => q.id.equals(queueId))).write(
      const SyncQueueCompanion(
        status: Value('pending'),
        processedAt: Value(null),
        lastError: Value(null),
      ),
    );
  }

  Future<List<SyncQueueData>> fetchPending({
    required int shopId,
    int limit = 25,
  }) async {
    return (_db.select(_db.syncQueue)
          ..where(
            (q) =>
                q.shopId.equals(shopId) &
                q.status.equals('pending'),
          )
          ..orderBy([(q) => OrderingTerm.asc(q.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Résumé lisible des éléments encore en file (pour l'UI cloud).
  Future<String?> describePendingBlock({required int shopId}) async {
    final rows = await fetchPending(shopId: shopId, limit: 50);
    if (rows.isEmpty) return null;

    final byTable = <String, int>{};
    for (final row in rows) {
      byTable[row.entityTable] = (byTable[row.entityTable] ?? 0) + 1;
    }

    const labels = <String, String>{
      SyncEntityTable.customers: 'client(s)',
      SyncEntityTable.categories: 'catégorie(s)',
      SyncEntityTable.products: 'produit(s)',
      SyncEntityTable.sales: 'vente(s)',
      SyncEntityTable.debts: 'créance(s)',
      SyncEntityTable.expenses: 'dépense(s)',
      SyncEntityTable.cashSessions: 'session(s) de caisse',
      SyncEntityTable.cashMovements: 'mouvement(s) de caisse',
      SyncEntityTable.tenantModules: 'module(s) boutique',
      SyncEntityTable.calculatorProductData: 'config(s) calculateur',
      SyncEntityTable.calculatorHistory: 'calcul(s) enregistré(s)',
    };

    final parts = byTable.entries
        .map((e) => '${e.value} ${labels[e.key] ?? e.key}')
        .join(', ');

    final hints = rows
        .map((r) => r.lastError)
        .whereType<String>()
        .where((m) => m.trim().isNotEmpty)
        .toSet()
        .take(2)
        .join(' · ');

    final buffer = StringBuffer('$parts en attente.');
    if (hints.isNotEmpty) {
      buffer.write(' $hints');
    } else {
      buffer.write(
        ' Les ventes nécessitent des produits synchronisés ; '
        'les produits nécessitent leurs catégories.',
      );
    }
    return buffer.toString();
  }

  Future<void> markDeferred(int queueId, String reason) async {
    await (_db.update(_db.syncQueue)..where((q) => q.id.equals(queueId))).write(
      SyncQueueCompanion(lastError: Value(reason)),
    );
  }

  Future<void> enqueue({
    required int shopId,
    required String tableName,
    required int recordId,
    required String operation,
    required String payload,
    required int localVersion,
    SyncContext? context,
  }) async {
    if (context != null && !context.shouldUseSyncQueue) return;

    await (_db.delete(_db.syncQueue)
          ..where(
            (q) =>
                q.shopId.equals(shopId) &
                q.entityTable.equals(tableName) &
                q.recordId.equals(recordId) &
                q.status.equals('pending'),
          ))
        .go();

    final timestamp = nowMs();
    await _db.into(_db.syncQueue).insert(
          SyncQueueCompanion.insert(
            shopId: shopId,
            entityTable: tableName,
            recordId: recordId,
            operation: operation,
            payload: payload,
            localVersion: localVersion,
            createdAt: timestamp,
          ),
        );
  }

  Future<void> markProcessed(int queueId) async {
    await (_db.update(_db.syncQueue)..where((q) => q.id.equals(queueId))).write(
      SyncQueueCompanion(
        status: const Value('processed'),
        processedAt: Value(nowMs()),
        lastError: const Value(null),
      ),
    );
  }

  Future<void> markFailed(int queueId, String error) async {
    final row = await (_db.select(_db.syncQueue)
          ..where((q) => q.id.equals(queueId)))
        .getSingleOrNull();
    if (row == null) return;

    final retries = row.retryCount + 1;
    await (_db.update(_db.syncQueue)..where((q) => q.id.equals(queueId))).write(
      SyncQueueCompanion(
        retryCount: Value(retries),
        lastError: Value(error),
        status: Value(retries >= maxRetries ? 'failed' : 'pending'),
      ),
    );
  }

  Future<void> markConflict(int queueId, String error) async {
    await (_db.update(_db.syncQueue)..where((q) => q.id.equals(queueId))).write(
      SyncQueueCompanion(
        status: const Value('conflict'),
        lastError: Value(error),
        processedAt: Value(nowMs()),
      ),
    );
  }
}
