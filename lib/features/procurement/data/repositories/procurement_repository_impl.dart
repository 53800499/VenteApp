import 'package:drift/drift.dart';
import '../../../../core/database/app_database.dart' as db hide Supplier, PurchaseOrder, PurchaseOrderItem, PurchaseReceipt, PurchaseReceiptItem, SupplierInvoice, SupplierPayment;
import '../../../../core/errors/failures.dart';
import '../../../../core/network/remote_api_guard.dart';
import '../../../../core/sync/local_write_sync_recorder.dart';
import '../../../../core/sync/sync_policy.dart';
import '../../../../core/sync/sync_pull_entity.dart';
import '../../domain/entities/procurement.dart';
import '../../domain/entities/procurement_report_entities.dart';
import '../../domain/repositories/procurement_repository.dart';
import '../datasources/procurement_local_datasource.dart';
import '../datasources/procurement_remote_datasource.dart';
import '../models/procurement_api_models.dart';
import '../services/procurement_sync_status_service.dart';
import '../utils/procurement_remote_payloads.dart';

class ProcurementRepositoryImpl implements ProcurementRepository {
  ProcurementRepositoryImpl({
    required ProcurementLocalDatasource local,
    required ProcurementRemoteDatasource remote,
    required RemoteApiGuard apiGuard,
    required SyncPolicy syncPolicy,
    LocalWriteSyncRecorder? recorder,
    ProcurementSyncStatusService? syncStatus,
  })  : _local = local,
        _remote = remote,
        _apiGuard = apiGuard,
        _syncPolicy = syncPolicy,
        _recorder = recorder,
        _syncStatus = syncStatus;

  final ProcurementLocalDatasource _local;
  final ProcurementRemoteDatasource _remote;
  final RemoteApiGuard _apiGuard;
  final SyncPolicy _syncPolicy;
  final LocalWriteSyncRecorder? _recorder;
  final ProcurementSyncStatusService? _syncStatus;

  Future<bool> _usesSyncQueue(int shopId) async {
    return (await _syncPolicy.resolve(shopId: shopId)).shouldUseSyncQueue;
  }

  Future<void> _assertReceiptNumberAvailable(int shopId, String receiptNumber) async {
    final trimmed = receiptNumber.trim();
    if (await _local.isReceiptNumberUsedInGroup(
      shopId: shopId,
      receiptNumber: trimmed,
    )) {
      final suggested = await _local.nextOrderReceiptNumber(shopId);
      throw ValidationFailure(
        'Le bon « $trimmed » existe déjà dans votre réseau de boutiques. '
        'Utilisez « $suggested » ou synchronisez à nouveau.',
      );
    }
  }

  Future<void> _assertPurchaseOrderNumberAvailable(int shopId, String number) async {
    final trimmed = number.trim();
    if (await _local.isPurchaseOrderNumberUsedInGroup(
      shopId: shopId,
      number: trimmed,
    )) {
      final suggested = await _local.nextPurchaseOrderNumber(shopId);
      throw ValidationFailure(
        'La commande « $trimmed » existe déjà dans votre réseau de boutiques. '
        'Utilisez « $suggested » ou synchronisez à nouveau.',
      );
    }
  }

  Future<void> _assertInvoiceNumberAvailable(int shopId, String invoiceNumber) async {
    final trimmed = invoiceNumber.trim();
    if (await _local.isInvoiceNumberUsedInGroup(
      shopId: shopId,
      invoiceNumber: trimmed,
    )) {
      final suggested = await _local.nextSupplierInvoiceNumber(shopId);
      throw ValidationFailure(
        'La facture « $trimmed » existe déjà dans votre réseau de boutiques. '
        'Utilisez « $suggested » ou synchronisez à nouveau.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Suppliers
  // ---------------------------------------------------------------------------
  @override
  Future<List<Supplier>> listSuppliers({required int shopId}) {
    return _local.listSuppliers(shopId);
  }

  @override
  Future<Supplier> createSupplier({
    required int shopId,
    required String name,
    String? phone,
    String? email,
    String? address,
  }) async {
    final supplier = await _local.createSupplier(
      shopId,
      name,
      phone: phone,
      email: email,
      address: address,
    );

    await _recorder?.recordSupplierCreate(
      shopId: shopId,
      supplierId: supplier.id,
      payload: {
        'name': name,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
      },
    );

    if (!(await _usesSyncQueue(shopId))) {
      _pushSupplierCreateInBackground(shopId, supplier);
    }
    return supplier;
  }

  @override
  Future<Supplier> updateSupplier({
    required int shopId,
    required int id,
    String? name,
    String? phone,
    String? email,
    String? address,
    bool? isActive,
  }) async {
    final supplier = await _local.updateSupplier(
      shopId,
      id,
      name: name,
      phone: phone,
      email: email,
      address: address,
      isActive: isActive,
    );

    await _recorder?.recordSupplierUpdate(
      shopId: shopId,
      supplierId: id,
      payload: {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
        if (isActive != null) 'isActive': isActive,
      },
    );

    if (!(await _usesSyncQueue(shopId))) {
      _pushSupplierUpdateInBackground(shopId, id, {
        if (name != null) 'name': name,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (address != null) 'address': address,
        if (isActive != null) 'isActive': isActive,
      });
    }
    return supplier;
  }

  // ---------------------------------------------------------------------------
  // Purchase Orders
  // ---------------------------------------------------------------------------
  @override
  Future<List<PurchaseOrder>> listPurchaseOrders({
    required int shopId,
    int? supplierId,
    PurchaseOrderStatus? status,
  }) {
    return _local.listPurchaseOrders(
      shopId,
      supplierId: supplierId,
      status: status != null ? _local.orderStatusToDb(status) : null,
    );
  }

  @override
  Future<PurchaseOrder?> findPurchaseOrder({
    required int shopId,
    required int id,
  }) {
    return _local.findPurchaseOrder(shopId, id);
  }

  @override
  Future<PurchaseOrder> createPurchaseOrder({
    required int shopId,
    required int userId,
    required int supplierId,
    required String number,
    required int orderedAt,
    int? expectedAt,
    required int subtotal,
    required int discount,
    required int tax,
    required int total,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    await _assertPurchaseOrderNumberAvailable(shopId, number);
    final po = await _local.createPurchaseOrder(
      shopId,
      userId,
      supplierId,
      number,
      orderedAt,
      expectedAt,
      subtotal,
      discount,
      tax,
      total,
      notes,
      items,
    );

    await _local.addHistory(
      shopId,
      po.id,
      'Commande créée',
      userId,
      details: 'Création initiale en statut brouillon.',
    );

    await _recorder?.recordPurchaseOrderCreate(
      shopId: shopId,
      poId: po.id,
      payload: {
        'supplierId': supplierId,
        'number': number,
        'orderedAt': orderedAt,
        if (expectedAt != null) 'expectedAt': expectedAt,
        'subtotal': subtotal,
        'discount': discount,
        'tax': tax,
        'total': total,
        if (notes != null) 'notes': notes,
        'items': items,
      },
    );

    if (!(await _usesSyncQueue(shopId))) {
      _pushPurchaseOrderCreateInBackground(shopId, po, items);
    }
    return po;
  }

  @override
  Future<PurchaseOrder> updatePurchaseOrder({
    required int shopId,
    required int userId,
    required int poId,
    String? number,
    int? supplierId,
    int? orderedAt,
    int? expectedAt,
    int? subtotal,
    int? discount,
    int? tax,
    int? total,
    String? notes,
    List<Map<String, dynamic>>? items,
  }) async {
    final existing = await _local.findPurchaseOrder(shopId, poId);
    if (existing == null) {
      throw const ValidationFailure('Commande introuvable.');
    }
    if (existing.status != PurchaseOrderStatus.draft) {
      throw const ValidationFailure(
        'Seules les commandes au statut brouillon peuvent être modifiées.',
      );
    }

    final po = await _local.updatePurchaseOrder(
      shopId,
      poId,
      number: number,
      supplierId: supplierId,
      orderedAt: orderedAt,
      expectedAt: expectedAt,
      subtotal: subtotal,
      discount: discount,
      tax: tax,
      total: total,
      notes: notes,
      items: items,
    );

    await _local.addHistory(
      shopId,
      poId,
      'Commande modifiée',
      userId,
      details: 'Modification des détails en statut brouillon.',
    );

    await _recorder?.recordPurchaseOrderUpdate(
      shopId: shopId,
      poId: poId,
      payload: {
        if (number != null) 'number': number,
        if (supplierId != null) 'supplierId': supplierId,
        if (orderedAt != null) 'orderedAt': orderedAt,
        if (expectedAt != null) 'expectedAt': expectedAt,
        if (subtotal != null) 'subtotal': subtotal,
        if (discount != null) 'discount': discount,
        if (tax != null) 'tax': tax,
        if (total != null) 'total': total,
        if (notes != null) 'notes': notes,
        if (items != null) 'items': items,
      },
    );

    if (!(await _usesSyncQueue(shopId))) {
      _pushPurchaseOrderUpdateInBackground(shopId, poId, {
        if (number != null) 'number': number,
        if (supplierId != null) 'supplierId': supplierId,
        if (orderedAt != null) 'orderedAt': orderedAt,
        if (expectedAt != null) 'expectedAt': expectedAt,
        if (subtotal != null) 'subtotal': subtotal,
        if (discount != null) 'discount': discount,
        if (tax != null) 'tax': tax,
        if (total != null) 'total': total,
        if (notes != null) 'notes': notes,
        if (items != null) 'items': items,
      });
    }

    return po;
  }

  @override
  Future<void> validatePurchaseOrder({
    required int shopId,
    required int userId,
    required int poId,
  }) async {
    await _local.updatePurchaseOrderStatus(shopId, poId, 'validated');
    await _local.addHistory(
      shopId,
      poId,
      'Commande validée',
      userId,
      details: 'Validation de la commande. Prête pour envoi.',
    );
    await _recorder?.recordPurchaseOrderValidate(shopId: shopId, poId: poId);

    if (!(await _usesSyncQueue(shopId))) {
      Future(() async {
        try {
          final serverId = await _resolvePoServerId(shopId, poId);
          if (serverId != null) {
            await _apiGuard.ensureReady();
            await _remote.validatePurchaseOrder(serverId);
          }
        } catch (_) {}
      });
    }
  }

  @override
  Future<void> sendPurchaseOrder({
    required int shopId,
    required int userId,
    required int poId,
  }) async {
    await _local.updatePurchaseOrderStatus(shopId, poId, 'sent');
    await _local.addHistory(
      shopId,
      poId,
      'Commande envoyée',
      userId,
      details: 'Commande marquée comme envoyée au fournisseur.',
    );
    await _recorder?.recordPurchaseOrderSend(shopId: shopId, poId: poId);

    if (!(await _usesSyncQueue(shopId))) {
      Future(() async {
        try {
          final serverId = await _resolvePoServerId(shopId, poId);
          if (serverId != null) {
            await _apiGuard.ensureReady();
            await _remote.sendPurchaseOrder(serverId);
          }
        } catch (_) {}
      });
    }
  }

  @override
  Future<void> cancelPurchaseOrder({
    required int shopId,
    required int userId,
    required int poId,
    String? reason,
  }) async {
    await _local.updatePurchaseOrderStatus(shopId, poId, 'cancelled');
    await _local.addHistory(
      shopId,
      poId,
      'Commande annulée',
      userId,
      details: reason ?? 'La commande a été annulée.',
    );
    await _recorder?.recordPurchaseOrderCancel(
      shopId: shopId,
      poId: poId,
      payload: {if (reason != null) 'reason': reason},
    );

    if (!(await _usesSyncQueue(shopId))) {
      Future(() async {
        try {
          final serverId = await _resolvePoServerId(shopId, poId);
          if (serverId != null) {
            await _apiGuard.ensureReady();
            await _remote.cancelPurchaseOrder(serverId, reason);
          }
        } catch (_) {}
      });
    }
  }

  @override
  Future<PurchaseReceipt> receiveItems({
    required int shopId,
    required int poId,
    required int userId,
    required String receiptNumber,
    required int receivedAt,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    await _assertReceiptNumberAvailable(shopId, receiptNumber);
    final receipt = await _local.createReceipt(
      shopId,
      poId,
      receiptNumber,
      receivedAt,
      userId,
      notes,
      items,
    );

    await _local.addHistory(
      shopId,
      poId,
      'Réception',
      userId,
      details: 'Réception locale enregistrée sous le bon #${receiptNumber}.',
    );

    await _recorder?.recordPurchaseOrderReceive(
      shopId: shopId,
      poId: poId,
      receiptId: receipt.id,
      payload: {
        'receiptNumber': receiptNumber,
        'receivedAt': receivedAt,
        if (notes != null) 'notes': notes,
        'items': items,
      },
    );

    final syncContext = await _syncPolicy.resolve(shopId: shopId);
    if (!syncContext.shouldUseSyncQueue) {
      await _pushReceiptCreateToRemote(shopId, poId, receipt, items);
    }
    return receipt;
  }

  @override
  Future<String> nextDirectReceiptNumber({required int shopId}) {
    return _local.nextDirectReceiptNumber(shopId);
  }

  @override
  Future<String> nextOrderReceiptNumber({required int shopId}) {
    return _local.nextOrderReceiptNumber(shopId);
  }

  @override
  Future<String> nextPurchaseOrderNumber({required int shopId}) {
    return _local.nextPurchaseOrderNumber(shopId);
  }

  @override
  Future<String> nextSupplierInvoiceNumber({required int shopId}) {
    return _local.nextSupplierInvoiceNumber(shopId);
  }

  @override
  Future<PurchaseReceipt> recordDirectProcurement({
    required int shopId,
    required int userId,
    required int supplierId,
    required String receiptNumber,
    required int receivedAt,
    String? notes,
    required List<Map<String, dynamic>> items,
    bool recordSupplierInvoice = true,
    String? invoiceNumber,
    int? paymentAmount,
    PurchasePaymentMethod paymentMethod = PurchasePaymentMethod.cash,
    String? paymentReference,
  }) async {
    await _assertReceiptNumberAvailable(shopId, receiptNumber);
    final receipt = await _local.createDirectReceipt(
      shopId: shopId,
      supplierId: supplierId,
      receiptNumber: receiptNumber,
      receivedAt: receivedAt,
      receivedBy: userId,
      notes: notes,
      items: items,
    );

    if (recordSupplierInvoice) {
      final subtotal = items.fold<int>(
        0,
        (sum, it) =>
            sum +
            (it['quantityReceived'] as int) * (it['unitCost'] as int),
      );
      final invoice = await createInvoice(
        shopId: shopId,
        poId: null,
        invoiceNumber: invoiceNumber ?? 'FAC-$receiptNumber',
        supplierId: supplierId,
        invoiceDate: receivedAt,
        dueDate: null,
        subtotal: subtotal,
        tax: 0,
        total: subtotal,
      );

      final payAmount = paymentAmount ?? subtotal;
      if (payAmount > 0) {
        await recordPayment(
          shopId: shopId,
          userId: userId,
          invoiceId: invoice.id,
          amount: payAmount,
          paymentMethod: paymentMethod,
          paymentDate: receivedAt,
          reference: paymentReference,
        );
      }
    }

    await _recorder?.recordDirectGoodsReceipt(
      shopId: shopId,
      receiptId: receipt.id,
      payload: {
        'items': items,
      },
    );

    final syncContext = await _syncPolicy.resolve(shopId: shopId);
    if (!syncContext.shouldUseSyncQueue) {
      await _pushDirectReceiptCreateToRemote(shopId, receipt, items);
    }
    return receipt;
  }

  @override
  Future<List<PurchaseReceipt>> listDirectReceipts({
    required int shopId,
    int? supplierId,
    int limit = 50,
  }) {
    return _local.listDirectReceipts(
      shopId,
      supplierId: supplierId,
      limit: limit,
    );
  }

  @override
  Future<PurchaseReceipt?> findReceipt({
    required int shopId,
    required int id,
  }) {
    return _local.findReceipt(shopId, id);
  }

  @override
  Future<SupplierInvoice?> findInvoiceForDirectReceipt({
    required int shopId,
    required PurchaseReceipt receipt,
  }) {
    return _local.findInvoiceForDirectReceipt(shopId, receipt);
  }

  @override
  Future<List<PurchaseReceipt>> listReceipts({
    required int shopId,
    required int poId,
  }) {
    return _local.listReceipts(shopId, poId);
  }

  @override
  Future<List<PurchaseOrderHistory>> listHistory({
    required int shopId,
    required int poId,
  }) {
    return _local.listHistory(shopId, poId);
  }

  // ---------------------------------------------------------------------------
  // Invoices & Payments
  // ---------------------------------------------------------------------------
  @override
  Future<List<SupplierInvoice>> listInvoices({
    required int shopId,
    int? supplierId,
  }) {
    return _local.listInvoices(shopId, supplierId: supplierId);
  }

  @override
  Future<SupplierInvoice?> findInvoice({
    required int shopId,
    required int id,
  }) {
    return _local.findInvoice(shopId, id);
  }

  @override
  Future<SupplierInvoice> createInvoice({
    required int shopId,
    int? poId,
    required String invoiceNumber,
    required int supplierId,
    required int invoiceDate,
    int? dueDate,
    required int subtotal,
    required int tax,
    required int total,
  }) async {
    await _assertInvoiceNumberAvailable(shopId, invoiceNumber);
    final invoice = await _local.createInvoice(
      shopId,
      poId,
      invoiceNumber,
      supplierId,
      invoiceDate,
      dueDate,
      subtotal,
      tax,
      total,
    );

    await _recorder?.recordSupplierInvoiceCreate(
      shopId: shopId,
      invoiceId: invoice.id,
      payload: {
        if (poId != null) 'purchaseOrderId': poId,
        'invoiceNumber': invoiceNumber,
        'supplierId': supplierId,
        'invoiceDate': invoiceDate,
        if (dueDate != null) 'dueDate': dueDate,
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
      },
    );

    if (!(await _usesSyncQueue(shopId))) {
      _pushInvoiceCreateInBackground(shopId, invoice);
    }
    return invoice;
  }

  @override
  Future<SupplierPayment> recordPayment({
    required int shopId,
    required int userId,
    required int invoiceId,
    required int amount,
    required PurchasePaymentMethod paymentMethod,
    required int paymentDate,
    String? reference,
  }) async {
    final invoice = await _local.findInvoice(shopId, invoiceId);
    if (invoice == null) {
      throw const ValidationFailure('Facture introuvable.');
    }
    if (invoice.status == SupplierInvoiceStatus.paid) {
      final pendingSync = await _syncStatus?.hasPendingPaymentForInvoice(
            shopId: shopId,
            invoiceId: invoiceId,
          ) ??
          false;
      if (pendingSync) {
        throw const ValidationFailure(
          'Cette facture est déjà payée sur cet appareil. '
          'Le paiement est en cours de synchronisation cloud — aucune action nécessaire.',
        );
      }
      throw const ValidationFailure('La facture est déjà entièrement payée.');
    }
    final paidSoFar = await _local.sumPaymentsForInvoice(shopId, invoiceId);
    if (paidSoFar + amount > invoice.total) {
      throw ValidationFailure(
        'Le montant dépasse le solde restant (${invoice.total - paidSoFar} FCFA).',
      );
    }

    final payment = await _local.createPayment(
      shopId,
      invoiceId,
      amount,
      paymentMethod.apiValue,
      paymentDate,
      reference,
    );

    final updatedInvoice = await _local.findInvoice(shopId, invoiceId);
    if (invoice.purchaseOrderId != null && updatedInvoice != null) {
      await _local.addHistory(
        shopId,
        invoice.purchaseOrderId!,
        'Paiement',
        userId,
        details:
            'Paiement de ${amount} FCFA pour la facture ${invoice.invoiceNumber}. '
            'Statut : ${updatedInvoice.status.label}.',
      );
    }

    await _recorder?.recordSupplierPaymentCreate(
      shopId: shopId,
      invoiceId: invoiceId,
      paymentId: payment.id,
      payload: {
        'amount': amount,
        'paymentMethod': paymentMethod.apiValue,
        'paymentDate': paymentDate,
        if (reference != null) 'reference': reference,
      },
    );

    if (!(await _usesSyncQueue(shopId))) {
      _pushPaymentCreateInBackground(shopId, invoiceId, payment);
    }
    return payment;
  }

  @override
  Future<ProcurementReportSummary> getReportSummary({required int shopId}) {
    return _local.buildReportSummary(shopId);
  }

  // ---------------------------------------------------------------------------
  // Background Push Helpers
  // ---------------------------------------------------------------------------
  void _pushSupplierCreateInBackground(int shopId, Supplier supplier) {
    Future(() async {
      try {
        await _apiGuard.ensureReady();
        final res = await _remote.createSupplier({
          'name': supplier.name,
          'phone': supplier.phone,
          'email': supplier.email,
          'address': supplier.address,
        });
        final serverId = res['id']?.toString();
        final version = res['version'] as int? ?? 1;
        if (serverId != null) {
          await _local.updateSupplier(shopId, supplier.id, serverId: serverId, syncStatus: 'synced', version: version);
        }
      } catch (_) {}
    });
  }

  void _pushSupplierUpdateInBackground(int shopId, int id, Map<String, dynamic> fields) {
    Future(() async {
      try {
        final supplier = await _local.findSupplier(shopId, id);
        if (supplier == null || supplier.serverId == null) return;
        await _apiGuard.ensureReady();
        await _remote.updateSupplier(int.parse(supplier.serverId!), fields);
      } catch (_) {}
    });
  }

  void _pushPurchaseOrderCreateInBackground(int shopId, PurchaseOrder po, List<Map<String, dynamic>> items) {
    Future(() async {
      try {
        final supplier = await _local.findSupplier(shopId, po.supplierId);
        if (supplier == null || supplier.serverId == null) return;

        // Resolve remote product serverIds
        final remoteItems = <Map<String, dynamic>>[];
        for (final it in items) {
          final prod = await (_local.database.select(_local.database.products)
                ..where((p) => p.id.equals(it['productId'] as int)))
              .getSingleOrNull();
          if (prod == null || prod.serverId == null) return; // Wait for product to be synced
          remoteItems.add({
            'productId': int.parse(prod.serverId!),
            'quantityOrdered': it['quantityOrdered'],
            'unitCost': it['unitCost'],
            'discount': it['discount'] ?? 0,
            'tax': it['tax'] ?? 0,
            'subtotal': it['subtotal'],
          });
        }

        await _apiGuard.ensureReady();
        var res = await _remote.createPurchaseOrder({
          'supplierId': int.parse(supplier.serverId!),
          'number': po.number,
          'orderedAt': po.orderedAt,
          if (po.expectedAt != null) 'expectedAt': po.expectedAt,
          'subtotal': po.subtotal,
          'discount': po.discount,
          'tax': po.tax,
          'total': po.total,
          'notes': po.notes,
          'items': remoteItems,
        });

        if (res['items'] is! List || (res['items'] as List).isEmpty) {
          final serverPoId = (res['id'] as num?)?.toInt();
          if (serverPoId != null) {
            res = await _remote.fetchPurchaseOrder(serverPoId);
          }
        }
        await _local.applyRemotePurchaseOrderSnapshot(shopId, po.id, res);
      } catch (_) {}
    });
  }

  void _pushPurchaseOrderUpdateInBackground(int shopId, int poId, Map<String, dynamic> fields) {
    Future(() async {
      try {
        await _pushPurchaseOrderUpdateToRemote(shopId, poId, fields);
      } catch (_) {}
    });
  }

  Future<void> _pushPurchaseOrderUpdateToRemote(
    int shopId,
    int poId,
    Map<String, dynamic> fields,
  ) async {
    final po = await _local.findPurchaseOrder(shopId, poId);
    if (po == null || po.serverId == null) return;

    final body = <String, dynamic>{};
    if (fields.containsKey('number')) body['number'] = fields['number'];
    if (fields.containsKey('orderedAt')) body['orderedAt'] = fields['orderedAt'];
    if (fields.containsKey('expectedAt')) body['expectedAt'] = fields['expectedAt'];
    if (fields.containsKey('subtotal')) body['subtotal'] = fields['subtotal'];
    if (fields.containsKey('discount')) body['discount'] = fields['discount'];
    if (fields.containsKey('tax')) body['tax'] = fields['tax'];
    if (fields.containsKey('total')) body['total'] = fields['total'];
    if (fields.containsKey('notes')) body['notes'] = fields['notes'];

    if (fields.containsKey('supplierId')) {
      final supplier =
          await _local.findSupplier(shopId, fields['supplierId'] as int);
      if (supplier == null || supplier.serverId == null) return;
      body['supplierId'] = int.parse(supplier.serverId!);
    }

    if (fields.containsKey('items')) {
      final remoteItems = <Map<String, dynamic>>[];
      for (final it in fields['items'] as List) {
        final prod = await (_local.database.select(_local.database.products)
              ..where((p) => p.id.equals(it['productId'] as int)))
            .getSingleOrNull();
        if (prod == null || prod.serverId == null) return;
        remoteItems.add({
          'productId': int.parse(prod.serverId!),
          'quantityOrdered': it['quantityOrdered'],
          'unitCost': it['unitCost'],
          'discount': it['discount'] ?? 0,
          'tax': it['tax'] ?? 0,
          'subtotal': it['subtotal'],
        });
      }
      body['items'] = remoteItems;
    }

    if (body.isEmpty) return;

    await _apiGuard.ensureReady();
    await _remote.updatePurchaseOrder(int.parse(po.serverId!), body);
  }

  Future<void> _pushReceiptCreateToRemote(
    int shopId,
    int poId,
    PurchaseReceipt receipt,
    List<Map<String, dynamic>> items,
  ) async {
    final po = await _local.findPurchaseOrder(shopId, poId);
    if (po == null || po.serverId == null) return;

    final remoteItems = <Map<String, dynamic>>[];
    for (final it in items) {
      final poItem = await (_local.database.select(_local.database.purchaseOrderItems)
            ..where((i) => i.id.equals(it['purchaseOrderItemId'] as int)))
          .getSingleOrNull();
      if (poItem == null || poItem.serverId == null) {
        throw const ValidationFailure(
          'Ligne de commande non synchronisée. Réessayez après la synchronisation cloud.',
        );
      }

      remoteItems.add(
        ProcurementRemotePayloads.purchaseOrderReceiptItem(
          serverPurchaseOrderItemId: int.parse(poItem.serverId!),
          quantityReceived: it['quantityReceived'] as int,
          unitCost: it['unitCost'] as int,
          batchNumber: it['batchNumber'] as String?,
          expiryDate: it['expiryDate'] as int?,
        ),
      );
    }

    await _apiGuard.ensureReady();
    final res = await _remote.receiveItems(
      int.parse(po.serverId!),
      ProcurementRemotePayloads.purchaseOrderReceiveBody(
        receiptNumber: receipt.receiptNumber,
        receivedAt: receipt.receivedAt,
        notes: receipt.notes,
        items: remoteItems,
      ),
    );

    final serverId = res['id']?.toString();
    if (serverId != null) {
      await (_local.database.update(_local.database.purchaseReceipts)
            ..where((r) => r.id.equals(receipt.id)))
          .write(db.PurchaseReceiptsCompanion(
        serverId: Value(serverId),
        syncStatus: const Value('synced'),
      ));
    }
  }

  Future<void> _pushDirectReceiptCreateToRemote(
    int shopId,
    PurchaseReceipt receipt,
    List<Map<String, dynamic>> items,
  ) async {
    final supplier = await _local.findSupplier(shopId, receipt.supplierId);
    if (supplier == null || supplier.serverId == null) {
      throw const ValidationFailure(
        'Fournisseur non synchronisé. Réessayez après la synchronisation cloud.',
      );
    }

    final remoteItems = <Map<String, dynamic>>[];
    for (final it in items) {
      final prod = await (_local.database.select(_local.database.products)
            ..where((p) => p.id.equals(it['productId'] as int)))
          .getSingleOrNull();
      if (prod == null || prod.serverId == null) {
        throw const ValidationFailure(
          'Produit non synchronisé. Réessayez après la synchronisation cloud.',
        );
      }

      remoteItems.add(
        ProcurementRemotePayloads.directReceiptItem(
          serverProductId: int.parse(prod.serverId!),
          quantityReceived: it['quantityReceived'] as int,
          unitCost: it['unitCost'] as int,
          batchNumber: it['batchNumber'] as String?,
          expiryDate: it['expiryDate'] as int?,
        ),
      );
    }

    await _apiGuard.ensureReady();
    final res = await _remote.createDirectGoodsReceipt(
      ProcurementRemotePayloads.directGoodsReceiptBody(
        serverSupplierId: int.parse(supplier.serverId!),
        receiptNumber: receipt.receiptNumber,
        receivedAt: receipt.receivedAt,
        notes: receipt.notes,
        items: remoteItems,
      ),
    );

    final serverId = res['id']?.toString();
    if (serverId != null) {
      await (_local.database.update(_local.database.purchaseReceipts)
            ..where((r) => r.id.equals(receipt.id)))
          .write(db.PurchaseReceiptsCompanion(
        serverId: Value(serverId),
        syncStatus: const Value('synced'),
      ));
    }
  }

  void _pushInvoiceCreateInBackground(int shopId, SupplierInvoice invoice) {
    Future(() async {
      try {
        final supplier = await _local.findSupplier(shopId, invoice.supplierId);
        if (supplier == null || supplier.serverId == null) return;

        int? remotePoId;
        if (invoice.purchaseOrderId != null) {
          final po = await _local.findPurchaseOrder(shopId, invoice.purchaseOrderId!);
          if (po == null || po.serverId == null) return;
          remotePoId = int.parse(po.serverId!);
        }

        await _apiGuard.ensureReady();
        final res = await _remote.createInvoice({
          if (remotePoId != null) 'purchaseOrderId': remotePoId,
          'invoiceNumber': invoice.invoiceNumber,
          'supplierId': int.parse(supplier.serverId!),
          'invoiceDate': invoice.invoiceDate,
          if (invoice.dueDate != null) 'dueDate': invoice.dueDate,
          'subtotal': invoice.subtotal,
          'tax': invoice.tax,
          'total': invoice.total,
        });

        final serverId = res['id']?.toString();
        if (serverId != null) {
          await (_local.database.update(_local.database.supplierInvoices)
                ..where((i) => i.id.equals(invoice.id)))
              .write(db.SupplierInvoicesCompanion(
            serverId: Value(serverId),
            syncStatus: const Value('synced'),
          ));
        }
      } catch (_) {}
    });
  }

  void _pushPaymentCreateInBackground(int shopId, int invoiceId, SupplierPayment payment) {
    Future(() async {
      try {
        final invoice = await _local.findInvoice(shopId, invoiceId);
        if (invoice == null || invoice.serverId == null) return;

        await _apiGuard.ensureReady();
        final res = await _remote.recordPayment(int.parse(invoice.serverId!), {
          'amount': payment.amount,
          'paymentMethod': payment.paymentMethod.apiValue,
          'paymentDate': payment.paymentDate,
          'reference': payment.reference,
        });

        final serverId = res['id']?.toString();
        if (serverId != null) {
          await (_local.database.update(_local.database.supplierPayments)
                ..where((p) => p.id.equals(payment.id)))
              .write(db.SupplierPaymentsCompanion(
            serverId: Value(serverId),
            syncStatus: const Value('synced'),
          ));
        }
      } catch (_) {}
    });
  }

  Future<int?> _resolvePoServerId(int shopId, int poId) async {
    final po = await _local.findPurchaseOrder(shopId, poId);
    return po?.serverId != null ? int.parse(po!.serverId!) : null;
  }

  @override
  Future<void> syncFromRemote({required int shopId, bool force = false}) async {
    if (!await _syncPolicy.shouldPullEntity(
      shopId: shopId,
      entity: SyncPullEntity.procurement,
      force: force,
    )) {
      return;
    }

    await _apiGuard.ensureReady();

    // Resolve a local userId for new records
    final defaultUserId = await _local.resolveDefaultUserId(shopId) ?? 0;

    // 1. Pull Suppliers
    final rawSuppliers = await _remote.fetchSuppliers();
    for (final raw in rawSuppliers) {
      final dto = SupplierApiDto.fromJson(raw);
      await _local.upsertSupplierFromRemote(shopId: shopId, remote: dto);
    }

    // 2. Pull commandes (détail seulement si version locale en retard / sans lignes)
    final rawOrders = await _remote.fetchPurchaseOrders();
    for (final raw in rawOrders) {
      final serverPoId = (raw['id'] as num?)?.toInt();
      if (serverPoId == null) continue;

      final remoteVersion = (raw['version'] as num?)?.toInt() ?? 1;
      final remoteStatus = raw['status'] as String? ?? '';
      final localMeta = await _local.findPurchaseOrderSyncMeta(
        shopId,
        '$serverPoId',
      );
      // Skip détail seulement si statut aligné + version à jour.
      // (Le BE incrémente désormais version à chaque changement de statut.)
      if (localMeta != null &&
          localMeta.hasItems &&
          localMeta.status == remoteStatus &&
          localMeta.version >= remoteVersion) {
        continue;
      }

      Map<String, dynamic> detail;
      try {
        final fetched = await _remote.fetchPurchaseOrder(serverPoId);
        detail = fetched;
      } catch (_) {
        detail = raw;
      }

      final dto = PurchaseOrderApiDto.fromJson(detail);
      await _local.upsertPurchaseOrderFromRemote(
        shopId: shopId,
        defaultUserId: defaultUserId,
        remote: dto,
      );

      final receipts = detail['receipts'] as List?;
      if (receipts != null) {
        for (final r in receipts) {
          if (r is! Map<String, dynamic>) continue;
          final rDto = PurchaseReceiptApiDto.fromJson(r);
          await _local.upsertPurchaseReceiptFromRemote(
            shopId: shopId,
            defaultUserId: defaultUserId,
            remote: rDto,
          );
        }
      }
    }

    // 3. Pull réceptions directes (hors commandes)
    try {
      final rawDirectReceipts = await _remote.fetchDirectGoodsReceipts();
      for (final raw in rawDirectReceipts) {
        final rDto = PurchaseReceiptApiDto.fromJson(raw);
        await _local.upsertPurchaseReceiptFromRemote(
          shopId: shopId,
          defaultUserId: defaultUserId,
          remote: rDto,
        );
      }
    } catch (_) {
      // Endpoint absent ou offline : ne pas bloquer le reste du pull.
    }

    // 4. Pull Invoices
    final rawInvoices = await _remote.fetchInvoices();
    for (final raw in rawInvoices) {
      final dto = SupplierInvoiceApiDto.fromJson(raw);
      await _local.upsertSupplierInvoiceFromRemote(shopId: shopId, remote: dto);

      // 5. Pull Payments embedded in invoice detail
      final serverInvId = (raw['id'] as num?)?.toInt();
      if (serverInvId == null) continue;
      try {
        final invDetail = await _remote.fetchInvoice(serverInvId);
        final payments = invDetail['payments'] as List?;
        if (payments != null) {
          for (final p in payments) {
            final pDto = SupplierPaymentApiDto.fromJson(p as Map<String, dynamic>);
            await _local.upsertSupplierPaymentFromRemote(shopId: shopId, remote: pDto);
          }
        }
      } catch (_) {}
    }

    await _syncPolicy.markEntitySynced(
      shopId: shopId,
      entity: SyncPullEntity.procurement,
    );
  }
}
