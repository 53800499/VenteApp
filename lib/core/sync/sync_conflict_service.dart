import 'dart:convert';

import 'package:drift/drift.dart';

import '../audit/local_audit_writer.dart';
import '../database/app_database.dart';
import '../utils/time.dart';
import '../../features/customers/data/datasources/local/customers_local_datasource.dart';
import '../../features/customers/data/datasources/remote/customers_remote_datasource.dart';
import '../../shared/enums/audit_enums.dart';
import 'sync_queue_datasource.dart';

/// Conflit affiché sur ECR-20.
class SyncConflictView {
  const SyncConflictView({
    required this.key,
    required this.source,
    required this.entityTable,
    required this.recordId,
    this.operation,
    this.localSummary,
    this.localDetails,
    this.serverMessage,
    this.serverDetails,
    this.queueId,
    this.saleId,
    this.rawPayload,
  });

  final String key;
  final String source;
  final String entityTable;
  final int recordId;
  final String? operation;
  final String? localSummary;
  final String? localDetails;
  final String? serverMessage;
  final String? serverDetails;
  final int? queueId;
  final int? saleId;
  final String? rawPayload;

  bool get isAutoMerged =>
      entityTable == 'sales' || entityTable == 'debts';

  bool get canMerge => isAutoMerged || queueId != null;
}

class SyncConflictService {
  SyncConflictService({
    required AppDatabase db,
    required SyncQueueDatasource queue,
    LocalAuditWriter? auditWriter,
    CustomersLocalDatasource? customersLocal,
    CustomersRemoteDatasource? customersRemote,
  })  : _db = db,
        _queue = queue,
        _auditWriter = auditWriter ?? LocalAuditWriter(db),
        _customersLocal = customersLocal,
        _customersRemote = customersRemote;

  final AppDatabase _db;
  final SyncQueueDatasource _queue;
  final LocalAuditWriter _auditWriter;
  final CustomersLocalDatasource? _customersLocal;
  final CustomersRemoteDatasource? _customersRemote;

  Future<List<SyncConflictView>> listConflicts({required int shopId}) async {
    final items = <SyncConflictView>[];

    final queueRows = await _queue.fetchConflicts(shopId: shopId);
    for (final row in queueRows) {
      final details = _formatPayload(row.payload);
      items.add(
        SyncConflictView(
          key: 'queue-${row.id}',
          source: 'queue',
          entityTable: row.entityTable,
          recordId: row.recordId,
          operation: row.operation,
          localSummary: _summarizePayload(row.payload),
          localDetails: details,
          serverMessage: row.lastError,
          serverDetails: _formatServerError(row.lastError),
          queueId: row.id,
          rawPayload: row.payload,
        ),
      );
    }

    final sales = await (_db.select(_db.sales)
          ..where(
            (s) =>
                s.shopId.equals(shopId) & s.syncStatus.equals('conflict'),
          ))
        .get();

    for (final sale in sales) {
      final localJson = jsonEncode({
        'receiptNumber': sale.receiptNumber,
        'totalAmount': sale.totalAmount,
        'amountPaid': sale.amountPaid,
        'paymentMethod': sale.paymentMethod,
        'status': sale.status,
        'updatedAt': sale.updatedAt,
      });
      items.add(
        SyncConflictView(
          key: 'sale-${sale.id}',
          source: 'sale',
          entityTable: 'sales',
          recordId: sale.id,
          operation: 'sync',
          localSummary:
              'Vente ${sale.receiptNumber ?? '#${sale.id}'} — ${sale.totalAmount} FCFA',
          localDetails: _prettyJson(localJson),
          serverMessage: 'Version serveur différente',
          serverDetails:
              'Les champs distants seront rechargés lors de l\'acceptation serveur.',
          saleId: sale.id,
        ),
      );
    }

    return items;
  }

  Future<int> countConflicts({required int shopId}) async {
    final queueCount = await _queue.countConflicts(shopId: shopId);
    final sales = await (_db.select(_db.sales)
          ..where(
            (s) =>
                s.shopId.equals(shopId) & s.syncStatus.equals('conflict'),
          ))
        .get();
    return queueCount + sales.length;
  }

  Future<void> keepLocal({
    required int shopId,
    required int userId,
    required SyncConflictView conflict,
  }) async {
    if (conflict.queueId != null) {
      await _queue.requeueConflict(conflict.queueId!);
    } else if (conflict.saleId != null) {
      await (_db.update(_db.sales)
            ..where((s) => s.id.equals(conflict.saleId!)))
          .write(
        const SalesCompanion(syncStatus: Value('pending')),
      );
    }
    await _recordResolution(
      shopId: shopId,
      userId: userId,
      conflict: conflict,
      resolution: 'keep_local',
    );
  }

  Future<void> keepServer({
    required int shopId,
    required int userId,
    required SyncConflictView conflict,
  }) async {
    await _applyServerVersion(shopId: shopId, conflict: conflict);

    if (conflict.queueId != null) {
      await _queue.markProcessed(conflict.queueId!);
    } else if (conflict.saleId != null) {
      await (_db.update(_db.sales)
            ..where((s) => s.id.equals(conflict.saleId!)))
          .write(
        SalesCompanion(
          syncStatus: const Value('synced'),
          syncedAt: Value(nowMs()),
        ),
      );
    }
    await _recordResolution(
      shopId: shopId,
      userId: userId,
      conflict: conflict,
      resolution: 'keep_server',
    );
  }

  Future<void> merge({
    required int shopId,
    required int userId,
    required SyncConflictView conflict,
  }) async {
    if (conflict.isAutoMerged) {
      if (conflict.saleId != null) {
        await (_db.update(_db.sales)
              ..where((s) => s.id.equals(conflict.saleId!)))
            .write(
          SalesCompanion(
            syncStatus: const Value('synced'),
            syncedAt: Value(nowMs()),
          ),
        );
      }
    } else if (conflict.queueId != null) {
      await _queue.requeueConflict(conflict.queueId!);
    }
    await _recordResolution(
      shopId: shopId,
      userId: userId,
      conflict: conflict,
      resolution: 'merge',
    );
  }

  Future<void> _applyServerVersion({
    required int shopId,
    required SyncConflictView conflict,
  }) async {
    if (conflict.entityTable != 'customers') return;
    final local = _customersLocal;
    final remote = _customersRemote;
    if (local == null || remote == null) return;

    final customer = await local.findCustomer(shopId, conflict.recordId);
    if (customer?.serverId == null) return;

    try {
      final detail = await remote.getCustomer(int.parse(customer!.serverId!));
      final dto = detail.customer;
      await local.upsertFromRemote(
        shopId: shopId,
        remoteId: dto.id,
        name: dto.name,
        phone: dto.phone,
        address: dto.address,
        note: dto.note,
        isArchived: dto.isArchived,
        isShared: dto.isShared,
        createdAt: dto.createdAt,
        updatedAt: dto.updatedAt,
      );
    } catch (_) {
      // Acceptation serveur sans relecture si API indisponible.
    }
  }

  Future<void> _recordResolution({
    required int shopId,
    required int userId,
    required SyncConflictView conflict,
    required String resolution,
  }) async {
    await _auditWriter.record(
      shopId: shopId,
      userId: userId,
      action: AuditAction.syncConflictResolved.code,
      module: AuditModule.sync.code,
      entityId: conflict.recordId,
      entityTable: conflict.entityTable,
      reason: 'Résolution conflit sync : $resolution',
      oldValue: {
        'source': conflict.source,
        'operation': conflict.operation,
        'localSummary': conflict.localSummary,
      },
      newValue: {
        'resolution': resolution,
        'serverMessage': conflict.serverMessage,
      },
    );
  }

  String? _summarizePayload(String payload) {
    try {
      final map = jsonDecode(payload);
      if (map is! Map<String, dynamic>) return payload;
      final name = map['name'] as String?;
      if (name != null) return name;
      final fields = map['fields'];
      if (fields is Map && fields['name'] != null) {
        return fields['name'].toString();
      }
      return map.entries
          .take(3)
          .map((e) => '${e.key}: ${e.value}')
          .join(' · ');
    } catch (_) {
      return payload.length > 80 ? '${payload.substring(0, 80)}…' : payload;
    }
  }

  String? _formatPayload(String payload) => _prettyJson(payload);

  String? _formatServerError(String? error) {
    if (error == null || error.isEmpty) return null;
    return _prettyJson(error) ?? error;
  }

  String? _prettyJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (_) {
      return null;
    }
  }
}
