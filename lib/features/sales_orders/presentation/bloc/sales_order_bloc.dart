import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/failures.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../sales/domain/entities/sale_entities.dart';
import '../../domain/entities/sales_order.dart';
import '../../domain/repositories/sales_order_repository.dart';

part 'sales_order_event.dart';
part 'sales_order_state.dart';

class SalesOrderBloc extends Bloc<SalesOrderEvent, SalesOrderState> {
  SalesOrderBloc({
    required SalesOrderRepository repository,
    required AuthSession session,
  })  : _repository = repository,
        _session = session,
        super(const SalesOrderState()) {
    on<SalesOrderListRequested>(_onList);
    on<SalesOrderDetailRequested>(_onDetail);
    on<SalesOrderCreateRequested>(_onCreate);
    on<SalesOrderConfirmRequested>(_onConfirm);
    on<SalesOrderPrepareRequested>(_onPrepare);
    on<SalesOrderCancelRequested>(_onCancel);
    on<SalesOrderCloseRequested>(_onClose);
    on<SalesOrderDeliverRequested>(_onDeliver);
    on<SalesOrderReportRequested>(_onReport);
    on<SalesOrderFeedbackCleared>(_onFeedbackCleared);
  }

  final SalesOrderRepository _repository;
  final AuthSession _session;

  int get _shopId => _session.shop.id;
  int get _userId => _session.user.id;

  Future<void> _onList(
    SalesOrderListRequested event,
    Emitter<SalesOrderState> emit,
  ) async {
    try {
      // Étape 1 : Lire et émettre immédiatement les commandes locales (Cache First - 0 ms)
      final localOrders = await _repository.listOrders(
        shopId: _shopId,
        status: event.status,
        search: event.search,
      );
      emit(
        state.copyWith(
          status: SalesOrderViewStatus.ready,
          orders: localOrders,
          filterStatus: event.status,
          search: event.search ?? '',
          clearError: true,
        ),
      );

      // Étape 2 : Synchroniser en tâche de fond avec un timeout strict de 4 secondes
      try {
        await _repository
            .syncFromRemote(
              shopId: _shopId,
              importUserId: _userId,
            )
            .timeout(const Duration(seconds: 4));
      } catch (_) {
        // Pull best-effort : on conserve les commandes locales affichées.
      }

      // Étape 3 : Mettre à jour avec les données rafraîchies
      final refreshedOrders = await _repository.listOrders(
        shopId: _shopId,
        status: event.status,
        search: event.search,
      );
      emit(
        state.copyWith(
          status: SalesOrderViewStatus.ready,
          orders: refreshedOrders,
          filterStatus: event.status,
          search: event.search ?? '',
        ),
      );
    } on Failure catch (e) {
      if (state.orders.isNotEmpty) {
        return;
      }
      emit(
        state.copyWith(
          status: SalesOrderViewStatus.failure,
          errorMessage: e.message,
        ),
      );
    } catch (_) {
      if (state.orders.isNotEmpty) {
        return;
      }
      emit(
        state.copyWith(
          status: SalesOrderViewStatus.failure,
          errorMessage: 'Chargement impossible.',
        ),
      );
    }
  }

  Future<void> _onDetail(
    SalesOrderDetailRequested event,
    Emitter<SalesOrderState> emit,
  ) async {
    emit(state.copyWith(detailLoading: true, clearError: true));
    try {
      try {
        await _repository.refreshOrderFromRemote(
          shopId: _shopId,
          orderId: event.orderId,
          importUserId: _userId,
        );
      } catch (_) {}
      final order = await _repository.findOrder(
        shopId: _shopId,
        id: event.orderId,
      );
      emit(
        state.copyWith(
          detailLoading: false,
          selected: order,
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          detailLoading: false,
          errorMessage: e.message,
        ),
      );
    }
  }

  Future<void> _onCreate(
    SalesOrderCreateRequested event,
    Emitter<SalesOrderState> emit,
  ) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      final order = await _repository.createOrder(
        shopId: _shopId,
        userId: _userId,
        customerId: event.customerId,
        items: event.items,
        notes: event.notes,
      );
      emit(
        state.copyWith(
          saving: false,
          selected: order,
          successMessage: 'Commande ${order.number} créée.',
        ),
      );
      add(const SalesOrderListRequested());
    } on Failure catch (e) {
      emit(state.copyWith(saving: false, errorMessage: e.message));
    } catch (_) {
      emit(
        state.copyWith(
          saving: false,
          errorMessage: 'Création impossible.',
        ),
      );
    }
  }

  Future<void> _onConfirm(
    SalesOrderConfirmRequested event,
    Emitter<SalesOrderState> emit,
  ) async {
    await _runAction(
      emit,
      () => _repository.confirmOrder(
        shopId: _shopId,
        userId: _userId,
        orderId: event.orderId,
      ),
      success: 'Commande confirmée.',
    );
  }

  Future<void> _onPrepare(
    SalesOrderPrepareRequested event,
    Emitter<SalesOrderState> emit,
  ) async {
    await _runAction(
      emit,
      () => _repository.markPreparing(
        shopId: _shopId,
        userId: _userId,
        orderId: event.orderId,
      ),
      success: 'En préparation.',
    );
  }

  Future<void> _onCancel(
    SalesOrderCancelRequested event,
    Emitter<SalesOrderState> emit,
  ) async {
    await _runAction(
      emit,
      () => _repository.cancelOrder(
        shopId: _shopId,
        userId: _userId,
        orderId: event.orderId,
        reason: event.reason,
      ),
      success: 'Commande annulée.',
    );
  }

  Future<void> _onClose(
    SalesOrderCloseRequested event,
    Emitter<SalesOrderState> emit,
  ) async {
    await _runAction(
      emit,
      () => _repository.closeOrder(
        shopId: _shopId,
        userId: _userId,
        orderId: event.orderId,
      ),
      success: 'Commande clôturée.',
    );
  }

  Future<void> _onDeliver(
    SalesOrderDeliverRequested event,
    Emitter<SalesOrderState> emit,
  ) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      final result = await _repository.deliver(
        shopId: _shopId,
        userId: _userId,
        orderId: event.orderId,
        lines: event.lines,
        paymentMethod: event.paymentMethod,
        notes: event.notes,
        driverName: event.driverName,
        vehiclePlate: event.vehiclePlate,
        remainingReason: event.remainingReason,
        amountCash: event.amountCash,
        amountMomo: event.amountMomo,
        amountCredit: event.amountCredit,
      );
      final delivery = result.delivery;
      final order = await _repository.findOrder(
        shopId: _shopId,
        id: event.orderId,
      );
      emit(
        state.copyWith(
          saving: false,
          selected: order,
          lastDelivery: delivery,
          successMessage: 'Livraison ${delivery.number} enregistrée.',
        ),
      );
      add(const SalesOrderListRequested());
    } on Failure catch (e) {
      emit(state.copyWith(saving: false, errorMessage: e.message));
    } catch (_) {
      emit(
        state.copyWith(
          saving: false,
          errorMessage: 'Livraison impossible.',
        ),
      );
    }
  }

  Future<void> _onReport(
    SalesOrderReportRequested event,
    Emitter<SalesOrderState> emit,
  ) async {
    emit(state.copyWith(reportLoading: true, clearError: true));
    try {
      final report = await _repository.fulfillmentReport(
        shopId: _shopId,
        fromMs: event.fromMs,
        toMs: event.toMs,
      );
      emit(state.copyWith(reportLoading: false, report: report));
    } on Failure catch (e) {
      emit(state.copyWith(reportLoading: false, errorMessage: e.message));
    } catch (_) {
      emit(
        state.copyWith(
          reportLoading: false,
          errorMessage: 'Rapport indisponible.',
        ),
      );
    }
  }

  Future<void> _runAction(
    Emitter<SalesOrderState> emit,
    Future<SalesOrder> Function() action, {
    required String success,
  }) async {
    emit(state.copyWith(saving: true, clearError: true));
    try {
      final order = await action();
      emit(
        state.copyWith(
          saving: false,
          selected: order,
          successMessage: success,
        ),
      );
      add(const SalesOrderListRequested());
    } on Failure catch (e) {
      emit(state.copyWith(saving: false, errorMessage: e.message));
    } catch (_) {
      emit(
        state.copyWith(
          saving: false,
          errorMessage: 'Action impossible.',
        ),
      );
    }
  }

  void _onFeedbackCleared(
    SalesOrderFeedbackCleared event,
    Emitter<SalesOrderState> emit,
  ) {
    emit(state.copyWith(clearError: true, clearSuccess: true));
  }
}
