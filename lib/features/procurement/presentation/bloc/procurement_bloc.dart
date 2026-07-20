import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/procurement.dart';
import '../../domain/entities/procurement_report_entities.dart';
import '../../domain/repositories/procurement_repository.dart';

part 'procurement_event.dart';
part 'procurement_state.dart';

class ProcurementBloc extends Bloc<ProcurementEvent, ProcurementState> {
  ProcurementBloc({
    required ProcurementRepository repository,
    required AuthSession session,
  })  : _repository = repository,
        _session = session,
        super(const ProcurementState()) {
    on<ProcurementSuppliersLoadRequested>(_onLoadSuppliers);
    on<ProcurementSupplierCreateSubmitted>(_onCreateSupplier);
    on<ProcurementSupplierUpdateSubmitted>(_onUpdateSupplier);
    on<ProcurementOrdersLoadRequested>(_onLoadOrders);
    on<ProcurementOrderDetailLoadRequested>(_onLoadOrderDetail);
    on<ProcurementOrderCreateSubmitted>(_onCreateOrder);
    on<ProcurementOrderUpdateSubmitted>(_onUpdateOrder);
    on<ProcurementOrderValidateRequested>(_onValidateOrder);
    on<ProcurementOrderSendRequested>(_onSendOrder);
    on<ProcurementOrderCancelRequested>(_onCancelOrder);
    on<ProcurementOrderReceiveSubmitted>(_onReceiveItems);
    on<ProcurementDirectProcurementSubmitted>(_onDirectProcurement);
    on<ProcurementDirectReceiptsLoadRequested>(_onLoadDirectReceipts);
    on<ProcurementDirectReceiptDetailLoadRequested>(_onLoadDirectReceiptDetail);
    on<ProcurementInvoicesLoadRequested>(_onLoadInvoices);
    on<ProcurementInvoiceDetailLoadRequested>(_onLoadInvoiceDetail);
    on<ProcurementInvoiceCreateSubmitted>(_onCreateInvoice);
    on<ProcurementPaymentRecordSubmitted>(_onRecordPayment);
    on<ProcurementReportLoadRequested>(_onLoadReport);
  }

  final ProcurementRepository _repository;
  final AuthSession _session;

  AuthSession get session => _session;

  int get shopId => _session.shop.id;
  int get userId => _session.user.id;

  Future<void> _onLoadSuppliers(
    ProcurementSuppliersLoadRequested event,
    Emitter<ProcurementState> emit,
  ) async {
    emit(state.copyWith(status: ProcurementStatus.loading, clearError: true));
    try {
      final list = await _repository.listSuppliers(shopId: shopId);
      emit(state.copyWith(status: ProcurementStatus.loaded, suppliers: list));
    } on Failure catch (e) {
      emit(state.copyWith(status: ProcurementStatus.failure, errorMessage: friendlyErrorMessage(e)));
    }
  }

  Future<void> _onCreateSupplier(
    ProcurementSupplierCreateSubmitted event,
    Emitter<ProcurementState> emit,
  ) async {
    emit(state.copyWith(status: ProcurementStatus.refreshing, clearError: true));
    try {
      await _repository.createSupplier(
        shopId: shopId,
        name: event.name,
        phone: event.phone,
        email: event.email,
        address: event.address,
      );
      final list = await _repository.listSuppliers(shopId: shopId);
      emit(state.copyWith(status: ProcurementStatus.loaded, suppliers: list));
    } on Failure catch (e) {
      emit(state.copyWith(status: ProcurementStatus.failure, errorMessage: friendlyErrorMessage(e)));
    }
  }

  Future<void> _onUpdateSupplier(
    ProcurementSupplierUpdateSubmitted event,
    Emitter<ProcurementState> emit,
  ) async {
    emit(state.copyWith(status: ProcurementStatus.refreshing, clearError: true));
    try {
      await _repository.updateSupplier(
        shopId: shopId,
        id: event.id,
        name: event.name,
        phone: event.phone,
        email: event.email,
        address: event.address,
        isActive: event.isActive,
      );
      final list = await _repository.listSuppliers(shopId: shopId);
      emit(state.copyWith(status: ProcurementStatus.loaded, suppliers: list));
    } on Failure catch (e) {
      emit(state.copyWith(status: ProcurementStatus.failure, errorMessage: friendlyErrorMessage(e)));
    }
  }

  Future<void> _onLoadOrders(
    ProcurementOrdersLoadRequested event,
    Emitter<ProcurementState> emit,
  ) async {
    emit(state.copyWith(
      status: state.purchaseOrders.isEmpty
          ? ProcurementStatus.loading
          : ProcurementStatus.refreshing,
      clearError: true,
    ));
    try {
      final list = await _repository.listPurchaseOrders(
        shopId: shopId,
        supplierId: event.supplierId,
        status: event.status,
      );
      emit(state.copyWith(status: ProcurementStatus.loaded, purchaseOrders: list));
    } on Failure catch (e) {
      emit(state.copyWith(status: ProcurementStatus.failure, errorMessage: friendlyErrorMessage(e)));
    }
  }

  Future<void> _onLoadOrderDetail(
    ProcurementOrderDetailLoadRequested event,
    Emitter<ProcurementState> emit,
  ) async {
    final sameOrder = state.selectedOrder?.id == event.poId;
    emit(state.copyWith(
      status: sameOrder ? ProcurementStatus.refreshing : ProcurementStatus.loading,
      clearError: true,
      clearSelectedOrder: !sameOrder,
    ));
    try {
      final order = await _repository.findPurchaseOrder(shopId: shopId, id: event.poId);
      if (order == null) {
        emit(state.copyWith(status: ProcurementStatus.failure, errorMessage: 'Commande introuvable.'));
        return;
      }
      final history = await _repository.listHistory(shopId: shopId, poId: event.poId);
      
      final receipts = await _repository.listReceipts(shopId: shopId, poId: event.poId);

      emit(state.copyWith(
        status: ProcurementStatus.loaded,
        selectedOrder: order,
        orderHistory: history,
        orderReceipts: receipts,
      ));
    } on Failure catch (e) {
      emit(state.copyWith(status: ProcurementStatus.failure, errorMessage: friendlyErrorMessage(e)));
    }
  }

  Future<void> _onCreateOrder(
    ProcurementOrderCreateSubmitted event,
    Emitter<ProcurementState> emit,
  ) async {
    emit(state.copyWith(status: ProcurementStatus.refreshing, clearError: true));
    try {
      await _repository.createPurchaseOrder(
        shopId: shopId,
        userId: userId,
        supplierId: event.supplierId,
        number: event.number,
        orderedAt: event.orderedAt,
        expectedAt: event.expectedAt,
        subtotal: event.subtotal,
        discount: event.discount,
        tax: event.tax,
        total: event.total,
        notes: event.notes,
        items: event.items,
      );
      final list = await _repository.listPurchaseOrders(shopId: shopId);
      emit(state.copyWith(status: ProcurementStatus.loaded, purchaseOrders: list));
    } on Failure catch (e) {
      emit(state.copyWith(status: ProcurementStatus.failure, errorMessage: friendlyErrorMessage(e)));
    }
  }

  Future<void> _onUpdateOrder(
    ProcurementOrderUpdateSubmitted event,
    Emitter<ProcurementState> emit,
  ) async {
    emit(state.copyWith(status: ProcurementStatus.refreshing, clearError: true));
    try {
      await _repository.updatePurchaseOrder(
        shopId: shopId,
        userId: userId,
        poId: event.poId,
        supplierId: event.supplierId,
        number: event.number,
        orderedAt: event.orderedAt,
        expectedAt: event.expectedAt,
        subtotal: event.subtotal,
        discount: event.discount,
        tax: event.tax,
        total: event.total,
        notes: event.notes,
        items: event.items,
      );
      final list = await _repository.listPurchaseOrders(shopId: shopId);
      emit(state.copyWith(status: ProcurementStatus.loaded, purchaseOrders: list));
    } on Failure catch (e) {
      emit(state.copyWith(status: ProcurementStatus.failure, errorMessage: friendlyErrorMessage(e)));
    }
  }

  Future<void> _onValidateOrder(
    ProcurementOrderValidateRequested event,
    Emitter<ProcurementState> emit,
  ) async {
    emit(state.copyWith(status: ProcurementStatus.refreshing, clearError: true));
    try {
      await _repository.validatePurchaseOrder(
        shopId: shopId,
        userId: userId,
        poId: event.poId,
      );
      add(ProcurementOrderDetailLoadRequested(event.poId));
    } on Failure catch (e) {
      emit(state.copyWith(status: ProcurementStatus.failure, errorMessage: friendlyErrorMessage(e)));
    }
  }

  Future<void> _onSendOrder(
    ProcurementOrderSendRequested event,
    Emitter<ProcurementState> emit,
  ) async {
    emit(state.copyWith(status: ProcurementStatus.refreshing, clearError: true));
    try {
      await _repository.sendPurchaseOrder(
        shopId: shopId,
        userId: userId,
        poId: event.poId,
      );
      add(ProcurementOrderDetailLoadRequested(event.poId));
    } on Failure catch (e) {
      emit(state.copyWith(status: ProcurementStatus.failure, errorMessage: friendlyErrorMessage(e)));
    }
  }

  Future<void> _onCancelOrder(
    ProcurementOrderCancelRequested event,
    Emitter<ProcurementState> emit,
  ) async {
    emit(state.copyWith(status: ProcurementStatus.refreshing, clearError: true));
    try {
      await _repository.cancelPurchaseOrder(
        shopId: shopId,
        userId: userId,
        poId: event.poId,
        reason: event.reason,
      );
      add(ProcurementOrderDetailLoadRequested(event.poId));
    } on Failure catch (e) {
      emit(state.copyWith(status: ProcurementStatus.failure, errorMessage: friendlyErrorMessage(e)));
    }
  }

  Future<void> _onReceiveItems(
    ProcurementOrderReceiveSubmitted event,
    Emitter<ProcurementState> emit,
  ) async {
    emit(state.copyWith(status: ProcurementStatus.refreshing, clearError: true));
    try {
      await _repository.receiveItems(
        shopId: shopId,
        poId: event.poId,
        userId: userId,
        receiptNumber: event.receiptNumber,
        receivedAt: event.receivedAt,
        notes: event.notes,
        items: event.items,
      );
      add(ProcurementOrderDetailLoadRequested(event.poId));
    } on Failure catch (e) {
      emit(state.copyWith(status: ProcurementStatus.failure, errorMessage: friendlyErrorMessage(e)));
    }
  }

  Future<void> _onDirectProcurement(
    ProcurementDirectProcurementSubmitted event,
    Emitter<ProcurementState> emit,
  ) async {
    emit(state.copyWith(status: ProcurementStatus.refreshing, clearError: true));
    try {
      await _repository.recordDirectProcurement(
        shopId: shopId,
        userId: userId,
        supplierId: event.supplierId,
        receiptNumber: event.receiptNumber,
        receivedAt: event.receivedAt,
        notes: event.notes,
        items: event.items,
        recordSupplierInvoice: event.recordSupplierInvoice,
        invoiceNumber: event.invoiceNumber,
        paymentAmount: event.paymentAmount,
        paymentMethod: event.paymentMethod,
        paymentReference: event.paymentReference,
      );
      add(const ProcurementOrdersLoadRequested());
      add(const ProcurementDirectReceiptsLoadRequested());
      emit(state.copyWith(status: ProcurementStatus.loaded));
    } on Failure catch (e) {
      emit(state.copyWith(status: ProcurementStatus.failure, errorMessage: friendlyErrorMessage(e)));
    }
  }

  Future<void> _onLoadDirectReceipts(
    ProcurementDirectReceiptsLoadRequested event,
    Emitter<ProcurementState> emit,
  ) async {
    emit(state.copyWith(
      status: state.directReceipts.isEmpty
          ? ProcurementStatus.loading
          : ProcurementStatus.refreshing,
      clearError: true,
    ));
    try {
      final list = await _repository.listDirectReceipts(
        shopId: shopId,
        supplierId: event.supplierId,
      );
      emit(state.copyWith(
        status: ProcurementStatus.loaded,
        directReceipts: list,
      ));
    } on Failure catch (e) {
      emit(state.copyWith(status: ProcurementStatus.failure, errorMessage: friendlyErrorMessage(e)));
    }
  }

  Future<void> _onLoadDirectReceiptDetail(
    ProcurementDirectReceiptDetailLoadRequested event,
    Emitter<ProcurementState> emit,
  ) async {
    final sameReceipt = state.selectedDirectReceipt?.id == event.receiptId;
    emit(state.copyWith(
      status: sameReceipt ? ProcurementStatus.refreshing : ProcurementStatus.loading,
      clearError: true,
      clearSelectedDirectReceipt: !sameReceipt,
    ));
    try {
      final receipt = await _repository.findReceipt(
        shopId: shopId,
        id: event.receiptId,
      );
      if (receipt == null) {
        emit(state.copyWith(
          status: ProcurementStatus.failure,
          errorMessage: 'Bon de réception introuvable.',
        ));
        return;
      }

      final invoice = await _repository.findInvoiceForDirectReceipt(
        shopId: shopId,
        receipt: receipt,
      );

      emit(state.copyWith(
        status: ProcurementStatus.loaded,
        selectedDirectReceipt: receipt,
        selectedDirectReceiptInvoice: invoice,
      ));
    } on Failure catch (e) {
      emit(state.copyWith(status: ProcurementStatus.failure, errorMessage: friendlyErrorMessage(e)));
    }
  }

  Future<void> _onLoadInvoices(
    ProcurementInvoicesLoadRequested event,
    Emitter<ProcurementState> emit,
  ) async {
    emit(state.copyWith(
      status: state.invoices.isEmpty
          ? ProcurementStatus.loading
          : ProcurementStatus.refreshing,
      clearError: true,
    ));
    try {
      final list = await _repository.listInvoices(shopId: shopId, supplierId: event.supplierId);
      emit(state.copyWith(status: ProcurementStatus.loaded, invoices: list));
    } on Failure catch (e) {
      emit(state.copyWith(status: ProcurementStatus.failure, errorMessage: friendlyErrorMessage(e)));
    }
  }

  Future<void> _onLoadInvoiceDetail(
    ProcurementInvoiceDetailLoadRequested event,
    Emitter<ProcurementState> emit,
  ) async {
    final sameInvoice = state.selectedInvoice?.id == event.invoiceId;
    emit(state.copyWith(
      status: sameInvoice ? ProcurementStatus.refreshing : ProcurementStatus.loading,
      clearError: true,
      clearSelectedInvoice: !sameInvoice,
    ));
    try {
      final invoice = await _repository.findInvoice(shopId: shopId, id: event.invoiceId);
      if (invoice == null) {
        emit(state.copyWith(status: ProcurementStatus.failure, errorMessage: 'Facture introuvable.'));
        return;
      }
      emit(state.copyWith(status: ProcurementStatus.loaded, selectedInvoice: invoice));
    } on Failure catch (e) {
      emit(state.copyWith(status: ProcurementStatus.failure, errorMessage: friendlyErrorMessage(e)));
    }
  }

  Future<void> _onCreateInvoice(
    ProcurementInvoiceCreateSubmitted event,
    Emitter<ProcurementState> emit,
  ) async {
    emit(state.copyWith(status: ProcurementStatus.refreshing, clearError: true));
    try {
      await _repository.createInvoice(
        shopId: shopId,
        poId: event.poId,
        invoiceNumber: event.invoiceNumber,
        supplierId: event.supplierId,
        invoiceDate: event.invoiceDate,
        dueDate: event.dueDate,
        subtotal: event.subtotal,
        tax: event.tax,
        total: event.total,
      );
      final list = await _repository.listInvoices(shopId: shopId);
      emit(state.copyWith(status: ProcurementStatus.loaded, invoices: list));
    } on Failure catch (e) {
      emit(state.copyWith(status: ProcurementStatus.failure, errorMessage: friendlyErrorMessage(e)));
    }
  }

  Future<void> _onRecordPayment(
    ProcurementPaymentRecordSubmitted event,
    Emitter<ProcurementState> emit,
  ) async {
    emit(state.copyWith(status: ProcurementStatus.refreshing, clearError: true));
    try {
      await _repository.recordPayment(
        shopId: shopId,
        userId: userId,
        invoiceId: event.invoiceId,
        amount: event.amount,
        paymentMethod: event.paymentMethod,
        paymentDate: event.paymentDate,
        reference: event.reference,
      );
      add(ProcurementInvoiceDetailLoadRequested(event.invoiceId));
      if (state.selectedDirectReceipt != null) {
        add(ProcurementDirectReceiptDetailLoadRequested(
          state.selectedDirectReceipt!.id,
        ));
      }
    } on Failure catch (e) {
      emit(state.copyWith(status: ProcurementStatus.failure, errorMessage: friendlyErrorMessage(e)));
    }
  }

  Future<void> _onLoadReport(
    ProcurementReportLoadRequested event,
    Emitter<ProcurementState> emit,
  ) async {
    emit(state.copyWith(status: ProcurementStatus.loading, clearError: true));
    try {
      final report = await _repository.getReportSummary(shopId: shopId);
      emit(state.copyWith(status: ProcurementStatus.loaded, reportSummary: report));
    } on Failure catch (e) {
      emit(state.copyWith(status: ProcurementStatus.failure, errorMessage: friendlyErrorMessage(e)));
    }
  }
}
