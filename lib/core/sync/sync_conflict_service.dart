import 'dart:convert';

import 'package:drift/drift.dart';

import '../audit/local_audit_writer.dart';
import '../database/app_database.dart';
import '../security/production_message_policy.dart';
import '../utils/time.dart';
import '../../features/customers/data/datasources/local/customers_local_datasource.dart';
import '../../features/customers/data/datasources/remote/customers_remote_datasource.dart';
import '../../features/sales_orders/data/datasources/sales_order_local_datasource.dart';
import '../../features/sales_orders/data/datasources/sales_order_remote_datasource.dart';
import '../../shared/enums/audit_enums.dart';
import 'sync_constants.dart';
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

  bool get isSalesOrderDeliverConflict =>
      entityTable == SyncEntityTable.salesOrders && operation == 'deliver';
}

class SyncConflictService {
  SyncConflictService({
    required AppDatabase db,
    required SyncQueueDatasource queue,
    LocalAuditWriter? auditWriter,
    CustomersLocalDatasource? customersLocal,
    CustomersRemoteDatasource? customersRemote,
    SalesOrderLocalDatasource? salesOrderLocal,
    SalesOrderRemoteDatasource? salesOrderRemote,
  })  : _db = db,
        _queue = queue,
        _auditWriter = auditWriter ?? LocalAuditWriter(db),
        _customersLocal = customersLocal,
        _customersRemote = customersRemote,
        _salesOrderLocal = salesOrderLocal,
        _salesOrderRemote = salesOrderRemote;

  final AppDatabase _db;
  final SyncQueueDatasource _queue;
  final LocalAuditWriter _auditWriter;
  final CustomersLocalDatasource? _customersLocal;
  final CustomersRemoteDatasource? _customersRemote;
  final SalesOrderLocalDatasource? _salesOrderLocal;
  final SalesOrderRemoteDatasource? _salesOrderRemote;

  Future<List<SyncConflictView>> listConflicts({required int shopId}) async {
    final items = <SyncConflictView>[];
    final queueSoIds = <int>{};

    final queueRows = await _queue.fetchConflicts(shopId: shopId);
    for (final row in queueRows) {
      if (row.entityTable == SyncEntityTable.salesOrders) {
        queueSoIds.add(row.recordId);
      }
      final details = _formatPayload(row.payload);
      final deliverWarning = row.entityTable == SyncEntityTable.salesOrders &&
          row.operation == 'deliver';
      items.add(
        SyncConflictView(
          key: 'queue-${row.id}',
          source: 'queue',
          entityTable: row.entityTable,
          recordId: row.recordId,
          operation: row.operation,
          localSummary: _summarizePayload(row.payload),
          localDetails: details,
          serverMessage: row.lastError != null
              ? ProductionMessagePolicy.sanitize(row.lastError!)
              : null,
          serverDetails: deliverWarning
              ? '${_formatServerError(row.lastError) ?? ''}\n\n'
                  'Attention : garder le serveur abandonne cette sync. '
                  'Vente/stock déjà enregistrés localement ne sont pas annulés — '
                  'vérifiez-les manuellement.'
                      .trim()
              : _formatServerError(row.lastError),
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

    final orders = await (_db.select(_db.salesOrders)
          ..where(
            (t) =>
                t.shopId.equals(shopId) & t.syncStatus.equals('conflict'),
          ))
        .get();
    for (final order in orders) {
      if (queueSoIds.contains(order.id)) continue;
      items.add(
        SyncConflictView(
          key: 'sales-order-${order.id}',
          source: 'sales_order',
          entityTable: SyncEntityTable.salesOrders,
          recordId: order.id,
          operation: 'sync',
          localSummary: 'Commande ${order.number} (v${order.version})',
          localDetails: _prettyJson(
            jsonEncode({
              'number': order.number,
              'status': order.status,
              'version': order.version,
              'updatedAt': order.updatedAt,
              'deviceId': order.deviceId,
            }),
          ),
          serverMessage: 'Conflit de version multi-appareil',
          serverDetails:
              'Garder le serveur recharge la commande cloud. '
              'Garder la mienne rejoue la sync locale.',
        ),
      );
    }

    return items;
  }

  Future<int> countConflicts({required int shopId}) async {
    final items = await listConflicts(shopId: shopId);
    return items.length;
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

    if (conflict.entityTable == SyncEntityTable.salesOrders) {
      await _salesOrderLocal?.markPendingSync(conflict.recordId);
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
    await _applyServerVersion(
      shopId: shopId,
      userId: userId,
      conflict: conflict,
    );

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

    if (conflict.entityTable == SyncEntityTable.salesOrders) {
      await _salesOrderLocal?.clearSyncConflict(conflict.recordId);
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
    required int userId,
    required SyncConflictView conflict,
  }) async {
    if (conflict.entityTable == 'customers') {
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
      return;
    }

    if (conflict.entityTable != SyncEntityTable.salesOrders) return;
    final local = _salesOrderLocal;
    final remote = _salesOrderRemote;
    if (local == null || remote == null) return;

    final order = await local.findOrder(
      shopId: shopId,
      id: conflict.recordId,
    );
    if (order?.serverId == null || order!.serverId!.isEmpty) return;

    try {
      final detail = await remote.getOrder(order.serverId!);
      await local.upsertOrderFromRemote(
        shopId: shopId,
        remote: detail,
        importUserId: userId,
        force: true,
      );
    } catch (_) {
      // Acceptation serveur sans relecture si API indisponible.
      await local.clearSyncConflict(conflict.recordId);
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
      final number = map['number'] as String?;
      if (number != null) return number;
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
    final sanitized = ProductionMessagePolicy.sanitize(error);
    if (!ProductionMessagePolicy.isTechnicalMessage(error)) {
      return _prettyJson(sanitized) ?? sanitized;
    }
    return sanitized;
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
