import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/sync/sync_constants.dart';
import '../../../../core/sync/sync_queue_datasource.dart';
import '../datasources/procurement_local_datasource.dart';
import '../../domain/entities/procurement.dart';
import '../../domain/entities/procurement_sync_entities.dart';

/// Synthèse UX de la synchronisation cloud pour le module approvisionnement.
class ProcurementSyncStatusService {
  ProcurementSyncStatusService({
    required SyncQueueDatasource queue,
    required ProcurementLocalDatasource local,
  })  : _queue = queue,
        _local = local;

  final SyncQueueDatasource _queue;
  final ProcurementLocalDatasource _local;

  static const _procurementTables = {
    SyncEntityTable.suppliers,
    SyncEntityTable.purchaseOrders,
    SyncEntityTable.purchaseReceipts,
    SyncEntityTable.supplierInvoices,
    SyncEntityTable.supplierPayments,
  };

  Future<ProcurementSyncOverview> loadOverview({required int shopId}) async {
    final rows = await _queue.fetchPending(shopId: shopId, limit: 100);
    final procurementRows = rows
        .where((r) => _procurementTables.contains(r.entityTable))
        .toList();

    final failed = await (_local.database.select(_local.database.syncQueue)
          ..where(
            (q) =>
                q.shopId.equals(shopId) &
                q.status.isIn(['failed', 'conflict']) &
                q.entityTable.isIn(_procurementTables.toList()),
          )
          ..orderBy([(q) => OrderingTerm.desc(q.createdAt)])
          ..limit(20))
        .get();

    final allRows = [...procurementRows, ...failed];

    final items = <ProcurementSyncQueueItem>[];
    final documentStates = <String, ProcurementCloudSyncState>{};
    var pendingCount = 0;
    var errorCount = 0;

    for (final row in allRows) {
      final isError = row.status == 'failed' || row.status == 'conflict';
      if (isError) {
        errorCount++;
      } else {
        pendingCount++;
      }

      final resolved = await _resolveQueueItem(shopId: shopId, row: row);
      if (resolved == null) continue;

      items.add(resolved);
      documentStates['${resolved.entityKind.name}:${resolved.localId}'] =
          isError ? ProcurementCloudSyncState.error : ProcurementCloudSyncState.pending;
    }

    items.sort((a, b) => (a.createdAt ?? 0).compareTo(b.createdAt ?? 0));

    return ProcurementSyncOverview(
      items: items,
      bannerMessage: _buildBannerMessage(items, pendingCount, errorCount),
      pendingCount: pendingCount,
      errorCount: errorCount,
      documentStates: documentStates,
    );
  }

  Future<ProcurementDirectSyncProgress> loadDirectProgress({
    required int shopId,
    required String receiptNumber,
    required bool invoiceExpected,
    required bool paymentExpected,
  }) async {
    final receipt = await _local.findReceiptByNumber(shopId, receiptNumber);
    if (receipt == null) {
      return ProcurementDirectSyncProgress(
        receiptNumber: receiptNumber,
        receiptDone: false,
        invoiceExpected: invoiceExpected,
        invoiceDone: false,
        paymentExpected: paymentExpected,
        paymentDone: false,
        allDone: false,
        hasError: false,
      );
    }

    final overview = await loadOverview(shopId: shopId);
    final receiptState = overview.stateFor(
      kind: ProcurementSyncEntityKind.receipt,
      localId: receipt.id,
      serverId: receipt.serverId,
    );

    SupplierInvoice? invoice;
    if (invoiceExpected) {
      invoice = await _local.findInvoiceForDirectReceipt(shopId, receipt);
    }

    var invoiceState = ProcurementCloudSyncState.synced;
    if (invoice != null) {
      invoiceState = overview.stateFor(
        kind: ProcurementSyncEntityKind.invoice,
        localId: invoice.id,
        serverId: invoice.serverId,
      );
    } else if (invoiceExpected) {
      invoiceState = ProcurementCloudSyncState.pending;
    }

    var paymentState = ProcurementCloudSyncState.synced;
    if (paymentExpected && invoice != null) {
      final payments = await _local.listPaymentsForInvoice(shopId, invoice.id);
      if (payments.isEmpty) {
        paymentState = ProcurementCloudSyncState.pending;
      } else {
        final allSynced = payments.every(
          (p) =>
              overview.stateFor(
                kind: ProcurementSyncEntityKind.payment,
                localId: p.id,
                serverId: p.serverId,
              ) ==
              ProcurementCloudSyncState.synced,
        );
        if (!allSynced) {
          paymentState = payments.any(
                (p) =>
                    overview.stateFor(
                      kind: ProcurementSyncEntityKind.payment,
                      localId: p.id,
                      serverId: p.serverId,
                    ) ==
                    ProcurementCloudSyncState.error,
              )
              ? ProcurementCloudSyncState.error
              : ProcurementCloudSyncState.pending;
        }
      }
    } else if (paymentExpected) {
      paymentState = ProcurementCloudSyncState.pending;
    }

    final receiptDone = receiptState == ProcurementCloudSyncState.synced;
    final invoiceDone =
        !invoiceExpected || invoiceState == ProcurementCloudSyncState.synced;
    final paymentDone =
        !paymentExpected || paymentState == ProcurementCloudSyncState.synced;

    return ProcurementDirectSyncProgress(
      receiptNumber: receiptNumber,
      receiptDone: receiptDone,
      invoiceExpected: invoiceExpected,
      invoiceDone: invoiceDone,
      paymentExpected: paymentExpected,
      paymentDone: paymentDone,
      allDone: receiptDone && invoiceDone && paymentDone,
      hasError: receiptState == ProcurementCloudSyncState.error ||
          invoiceState == ProcurementCloudSyncState.error ||
          paymentState == ProcurementCloudSyncState.error,
    );
  }

  Future<bool> hasPendingPaymentForInvoice({
    required int shopId,
    required int invoiceId,
  }) async {
    final rows = await _queue.fetchPending(shopId: shopId, limit: 50);
    for (final row in rows) {
      if (row.entityTable != SyncEntityTable.supplierPayments) continue;
      final payload = _decodePayload(row.payload);
      if (payload['invoiceId'] == invoiceId) return true;
    }
    return false;
  }

  Future<ProcurementSyncQueueItem?> _resolveQueueItem({
    required int shopId,
    required dynamic row,
  }) async {
    final recordId = row.recordId as int;
    final entityTable = row.entityTable as String;
    final lastError = row.lastError as String?;
    final createdAt = row.createdAt as int;
    final isPending = row.status == 'pending';

    switch (entityTable) {
      case SyncEntityTable.purchaseReceipts:
        final receipt = await _local.findReceipt(shopId, recordId);
        if (receipt == null) return null;
        return ProcurementSyncQueueItem(
          entityKind: ProcurementSyncEntityKind.receipt,
          localId: receipt.id,
          label: 'BR ${receipt.receiptNumber}',
          state: isPending
              ? ProcurementCloudSyncState.pending
              : ProcurementCloudSyncState.error,
          detail: _defaultDetail(lastError, 'Réception'),
          groupKey: 'direct:${receipt.receiptNumber}',
          createdAt: createdAt,
        );

      case SyncEntityTable.supplierInvoices:
        final invoice = await _local.findInvoice(shopId, recordId);
        if (invoice == null) return null;
        return ProcurementSyncQueueItem(
          entityKind: ProcurementSyncEntityKind.invoice,
          localId: invoice.id,
          label: 'Facture ${invoice.invoiceNumber}',
          state: isPending
              ? ProcurementCloudSyncState.pending
              : ProcurementCloudSyncState.error,
          detail: _friendlyInvoiceDeferral(lastError),
          groupKey: invoice.purchaseOrderId == null
              ? 'direct:${invoice.invoiceNumber.replaceFirst('FAC-', '')}'
              : 'po:${invoice.purchaseOrderId}',
          createdAt: createdAt,
        );

      case SyncEntityTable.supplierPayments:
        final payment = await _local.findPayment(shopId, recordId);
        if (payment == null) return null;
        final invoice = await _local.findInvoice(shopId, payment.invoiceId);
        return ProcurementSyncQueueItem(
          entityKind: ProcurementSyncEntityKind.payment,
          localId: payment.id,
          label:
              'Paiement ${payment.amount} F · ${invoice?.invoiceNumber ?? 'facture'}',
          state: isPending
              ? ProcurementCloudSyncState.pending
              : ProcurementCloudSyncState.error,
          detail: _friendlyPaymentDeferral(lastError),
          groupKey: invoice?.purchaseOrderId == null && invoice != null
              ? 'direct:${invoice.invoiceNumber.replaceFirst('FAC-', '')}'
              : (invoice?.purchaseOrderId != null
                  ? 'po:${invoice!.purchaseOrderId}'
                  : null),
          createdAt: createdAt,
        );

      case SyncEntityTable.purchaseOrders:
        final po = await _local.findPurchaseOrder(shopId, recordId);
        if (po == null) return null;
        return ProcurementSyncQueueItem(
          entityKind: ProcurementSyncEntityKind.purchaseOrder,
          localId: po.id,
          label: 'Commande ${po.number}',
          state: isPending
              ? ProcurementCloudSyncState.pending
              : ProcurementCloudSyncState.error,
          detail: lastError,
          groupKey: 'po:${po.id}',
          createdAt: createdAt,
        );

      case SyncEntityTable.suppliers:
        final supplier = await _local.findSupplier(shopId, recordId);
        if (supplier == null) return null;
        return ProcurementSyncQueueItem(
          entityKind: ProcurementSyncEntityKind.supplier,
          localId: supplier.id,
          label: 'Fournisseur ${supplier.name}',
          state: isPending
              ? ProcurementCloudSyncState.pending
              : ProcurementCloudSyncState.error,
          detail: lastError,
          createdAt: createdAt,
        );

      default:
        return null;
    }
  }

  String? _buildBannerMessage(
    List<ProcurementSyncQueueItem> items,
    int pending,
    int errors,
  ) {
    if (items.isEmpty) return null;

    if (errors > 0) {
      final first = items.firstWhere(
        (i) => i.state == ProcurementCloudSyncState.error,
        orElse: () => items.first,
      );
      return '${first.label} : ${first.detail ?? 'Synchronisation à vérifier.'} '
          'Consultez « Sync appro » pour le détail.';
    }

    if (pending == 1) {
      final only = items.first;
      return '${only.label} — envoi cloud en cours. '
          'Rien à ressaisir : vos données sont enregistrées sur cet appareil.';
    }

    final labels = items.take(3).map((i) => i.label).join(', ');
    final suffix = items.length > 3 ? '…' : '';
    return '$labels$suffix — synchronisation en cours. '
        'Aucune action requise tant que la connexion est active.';
  }

  String? _defaultDetail(String? lastError, String fallback) {
    if (lastError != null && lastError.isNotEmpty) return lastError;
    return fallback;
  }

  String? _friendlyInvoiceDeferral(String? lastError) {
    if (lastError == null || lastError.isEmpty) {
      return 'En attente des prérequis cloud (fournisseur ou commande).';
    }
    if (lastError.contains('non synchronisée')) {
      return 'En attente de la synchronisation des documents liés.';
    }
    return lastError;
  }

  String? _friendlyPaymentDeferral(String? lastError) {
    if (lastError == null || lastError.isEmpty) {
      return 'En attente de la facture sur le cloud.';
    }
    if (lastError.contains('Facture associée')) {
      return 'Le paiement suivra automatiquement la facture.';
    }
    return lastError;
  }

  Map<String, dynamic> _decodePayload(String raw) {
    if (raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }
}
