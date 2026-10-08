import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../utils/time.dart';
import 'sync_constants.dart';
import 'sync_policy.dart';
import 'workflow/sync_workflow.dart';
import 'workflow/sync_workflow_registry.dart';

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

  Future<SyncQueueData?> findPendingOperation({
    required int shopId,
    required String entityTable,
    required int recordId,
    required String operation,
  }) async {
    return (_db.select(_db.syncQueue)
          ..where(
            (q) =>
                q.shopId.equals(shopId) &
                q.entityTable.equals(entityTable) &
                q.recordId.equals(recordId) &
                q.operation.equals(operation) &
                q.status.equals('pending'),
          )
          ..limit(1))
        .getSingleOrNull();
  }

  Future<List<SyncQueueData>> fetchPendingForRecord({
    required int shopId,
    required String entityTable,
    required int recordId,
  }) async {
    return (_db.select(_db.syncQueue)
          ..where(
            (q) =>
                q.shopId.equals(shopId) &
                q.entityTable.equals(entityTable) &
                q.recordId.equals(recordId) &
                q.status.equals('pending'),
          )
          ..orderBy([(q) => OrderingTerm.asc(q.createdAt)]))
        .get();
  }

  /// Toutes boutiques : requis pour les workflows cross-shop (transferts).
  Future<List<SyncQueueData>> fetchPendingForRecordAnyShop({
    required String entityTable,
    required int recordId,
  }) async {
    return (_db.select(_db.syncQueue)
          ..where(
            (q) =>
                q.entityTable.equals(entityTable) &
                q.recordId.equals(recordId) &
                q.status.equals('pending'),
          )
          ..orderBy([(q) => OrderingTerm.asc(q.createdAt)]))
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
      SyncEntityTable.suppliers: 'fournisseur(s)',
      SyncEntityTable.purchaseOrders: 'commande(s) achat',
      SyncEntityTable.purchaseReceipts: 'réception(s) achat',
      SyncEntityTable.supplierInvoices: 'facture(s) fournisseur',
      SyncEntityTable.supplierPayments: 'paiement(s) fournisseur',
      SyncEntityTable.stockTransfers: 'transfert(s) inter-boutiques',
      SyncEntityTable.salesOrders: 'commande(s) client',
      SyncEntityTable.fxRateSnapshots: 'taux de change',
      SyncEntityTable.fxShopCurrencies: 'devise(s) boutique',
      SyncEntityTable.fxSessions: 'session(s) bureau de change',
      SyncEntityTable.fxOperations: 'opération(s) de change',
      SyncEntityTable.fxMovements: 'mouvement(s) de change',
    };

    final parts = byTable.entries
        .map((e) => '${e.value} ${labels[e.key] ?? e.key}')
        .join(', ');

    final workflowHints = <String>[];
    final byRecord = <String, List<SyncQueueData>>{};
    for (final row in rows) {
      final key = '${row.entityTable}:${row.recordId}';
      byRecord.putIfAbsent(key, () => []).add(row);
    }

    for (final entry in byRecord.entries) {
      if (workflowHints.length >= 2) break;
      final sample = entry.value.first;
      final workflow = SyncWorkflowRegistry.forTable(sample.entityTable);
      if (workflow == null) continue;

      final progress = WorkflowProgress.derive(
        workflow: workflow,
        recordId: sample.recordId,
        pendingOps: [
          for (final r in entry.value)
            WorkflowPendingOp(operation: r.operation, lastError: r.lastError),
        ],
      );
      if (progress.blockedReason != null &&
          progress.blockedReason!.trim().isNotEmpty) {
        workflowHints.add(progress.blockedReason!);
      } else if (progress.current != null) {
        final lines = progress.formatLines(workflow);
        final focus = lines.where((l) => l.startsWith('⏳')).take(2).join(' → ');
        if (focus.isNotEmpty) {
          workflowHints.add(focus);
        }
      }
    }

    final hints = workflowHints.isNotEmpty
        ? workflowHints.join(' · ')
        : rows
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
        ' Des étapes cloud sont en attente dans l\'ordre. '
        'Relancez la sync ; les étapes suivantes partiront automatiquement. '
        'Ne recréez pas l\'action localement.',
      );
    }
    return buffer.toString();
  }

  Future<void> markDeferred(int queueId, String reason) async {
    await (_db.update(_db.syncQueue)..where((q) => q.id.equals(queueId))).write(
      SyncQueueCompanion(
        status: const Value('deferred'),
        lastError: Value(reason),
      ),
    );
  }

  Future<void> markBlocked(int queueId, String reason) async {
    await (_db.update(_db.syncQueue)..where((q) => q.id.equals(queueId))).write(
      SyncQueueCompanion(
        status: const Value('blocked'),
        lastError: Value(reason),
      ),
    );
  }

  Future<void> markPermanentFailure(
    int queueId,
    String error, {
    String? errorCode,
  }) async {
    await (_db.update(_db.syncQueue)..where((q) => q.id.equals(queueId))).write(
      SyncQueueCompanion(
        status: const Value('failed_permanent'),
        lastError: Value(error),
        errorCode: Value(errorCode),
        processedAt: Value(nowMs()),
      ),
    );
  }

  Future<void> markRetryWithBackoff(
    int queueId,
    String error, {
    int backoffSeconds = 5,
  }) async {
    final row = await (_db.select(_db.syncQueue)
          ..where((q) => q.id.equals(queueId)))
        .getSingleOrNull();
    if (row == null) return;

    final retries = row.retryCount + 1;
    final nextRetry = nowMs() + (backoffSeconds * 1000);

    if (retries >= maxRetries * 3) {
      await markPermanentFailure(
        queueId,
        'Nombre maximal de tentatives dépassé ($retries retries) : $error',
        errorCode: 'MAX_RETRIES_EXCEEDED',
      );
      return;
    }

    await (_db.update(_db.syncQueue)..where((q) => q.id.equals(queueId))).write(
      SyncQueueCompanion(
        status: const Value('pending'),
        retryCount: Value(retries),
        nextRetryAt: Value(nextRetry),
        lastError: Value(error),
      ),
    );
  }

  /// Map une table vers son domaine métier d'isolation logique.
  static String mapTableToDomain(String tableName) {
    switch (tableName) {
      case SyncEntityTable.sales:
      case SyncEntityTable.salesOrders:
      case SyncEntityTable.customers:
      case SyncEntityTable.debts:
        return 'SALES';
      case SyncEntityTable.categories:
      case SyncEntityTable.products:
        return 'INVENTORY';
      case SyncEntityTable.cashSessions:
      case SyncEntityTable.cashMovements:
      case SyncEntityTable.expenses:
        return 'CASH';
      case SyncEntityTable.suppliers:
      case SyncEntityTable.purchaseOrders:
      case SyncEntityTable.purchaseReceipts:
      case SyncEntityTable.supplierInvoices:
      case SyncEntityTable.supplierPayments:
        return 'PROCUREMENT';
      case SyncEntityTable.stockTransfers:
        return 'TRANSFER';
      case SyncEntityTable.fxSessions:
      case SyncEntityTable.fxOperations:
      case SyncEntityTable.fxMovements:
      case SyncEntityTable.fxRateSnapshots:
      case SyncEntityTable.fxShopCurrencies:
        return 'FX';
      default:
        return 'SYSTEM';
    }
  }

  Future<void> enqueue({
    required int shopId,
    required String tableName,
    required int recordId,
    required String operation,
    required String payload,
    required int localVersion,
    String? domain,
    String? idempotencyKey,
    String businessCriticality = 'NORMAL',
    int basePriority = 10,
    SyncContext? context,
  }) async {
    if (context != null && !context.shouldUseSyncQueue) return;

    try {
      await _insertQueueItem(
        shopId: shopId,
        tableName: tableName,
        recordId: recordId,
        operation: operation,
        payload: payload,
        localVersion: localVersion,
        domain: domain,
        idempotencyKey: idempotencyKey,
        businessCriticality: businessCriticality,
        basePriority: basePriority,
      );
    } catch (e) {
      if (e.toString().contains('sync_queue has no column') ||
          e.toString().contains('no column named')) {
        await _autoRepairSyncQueueSchema();
        await _insertQueueItem(
          shopId: shopId,
          tableName: tableName,
          recordId: recordId,
          operation: operation,
          payload: payload,
          localVersion: localVersion,
          domain: domain,
          idempotencyKey: idempotencyKey,
          businessCriticality: businessCriticality,
          basePriority: basePriority,
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> _insertQueueItem({
    required int shopId,
    required String tableName,
    required int recordId,
    required String operation,
    required String payload,
    required int localVersion,
    String? domain,
    String? idempotencyKey,
    required String businessCriticality,
    required int basePriority,
  }) async {
    await (_db.delete(_db.syncQueue)
          ..where(
            (q) =>
                q.shopId.equals(shopId) &
                q.entityTable.equals(tableName) &
                q.recordId.equals(recordId) &
                q.operation.equals(operation) &
                q.status.equals('pending'),
          ))
        .go();

    final timestamp = nowMs();
    final effectiveDomain = domain ?? mapTableToDomain(tableName);
    final key = idempotencyKey ??
        'FEDA-SYNC-${timestamp}-${tableName}-${recordId}-${operation}';

    await _db.into(_db.syncQueue).insert(
          SyncQueueCompanion.insert(
            shopId: shopId,
            domain: Value(effectiveDomain),
            entityTable: tableName,
            recordId: recordId,
            operation: operation,
            payload: payload,
            idempotencyKey: Value(key),
            businessCriticality: Value(businessCriticality),
            basePriority: Value(basePriority),
            localVersion: localVersion,
            createdAt: timestamp,
          ),
        );
  }

  Future<void> _autoRepairSyncQueueSchema() async {
    final columns = [
      ('domain', "TEXT NOT NULL DEFAULT 'SALES'"),
      ('idempotency_key', 'TEXT NULL'),
      ('business_criticality', "TEXT NOT NULL DEFAULT 'NORMAL'"),
      ('base_priority', 'INTEGER NOT NULL DEFAULT 10'),
      ('dependency_boost', 'INTEGER NOT NULL DEFAULT 0'),
      ('local_version', 'INTEGER NOT NULL DEFAULT 1'),
      ('next_retry_at', 'INTEGER NULL'),
      ('last_error', 'TEXT NULL'),
      ('error_code', 'TEXT NULL'),
      ('processed_at', 'INTEGER NULL'),
    ];

    for (final col in columns) {
      try {
        final rows =
            await _db.customSelect('PRAGMA table_info(sync_queue)').get();
        final exists = rows.any((r) => r.read<String>('name') == col.$1);
        if (!exists) {
          await _db.customStatement(
            'ALTER TABLE sync_queue ADD COLUMN ${col.$1} ${col.$2}',
          );
        }
      } catch (_) {}
    }
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
    await markRetryWithBackoff(queueId, error, backoffSeconds: 5);
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

  Future<void> markActionRequired(
    int queueId, {
    required String error,
    String suggestedAction = 'EDIT_OPERATION',
  }) async {
    await _db.customStatement(
      'UPDATE sync_queue SET status = ?, last_error = ?, suggested_action = ? WHERE id = ?',
      ['action_required', error, suggestedAction, queueId],
    );
  }

  Future<void> markDiscarded(
    int queueId, {
    required int userId,
    required String reason,
  }) async {
    final timestamp = nowMs();
    await _db.customStatement(
      'UPDATE sync_queue SET status = ?, discarded_at = ?, discarded_by = ?, discard_reason = ? WHERE id = ?',
      ['discarded', timestamp, userId, reason, queueId],
    );
  }

  Future<void> retryQueueItem(int queueId) async {
    await (_db.update(_db.syncQueue)..where((q) => q.id.equals(queueId))).write(
      const SyncQueueCompanion(
        status: Value('pending'),
        nextRetryAt: Value(null),
      ),
    );
  }

  Future<List<SyncQueueData>> listUnresolvedItems(int shopId) async {
    return (_db.select(_db.syncQueue)
          ..where(
            (q) =>
                q.shopId.equals(shopId) &
                (q.status.equals('action_required') |
                    q.status.equals('failed_permanent') |
                    q.status.equals('conflict')),
          )
          ..orderBy([(q) => OrderingTerm.desc(q.createdAt)]))
        .get();
  }
}
