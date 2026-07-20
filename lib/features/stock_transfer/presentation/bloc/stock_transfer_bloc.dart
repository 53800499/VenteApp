import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/sync/sync_policy.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/stock_transfer.dart';
import '../../domain/repositories/stock_transfer_repository.dart';

part 'stock_transfer_event.dart';
part 'stock_transfer_state.dart';

class StockTransferBloc extends Bloc<StockTransferEvent, StockTransferState> {
  StockTransferBloc({
    required StockTransferRepository repository,
    required AuthSession session,
    required SyncPolicy syncPolicy,
    SyncService? syncService,
  })  : _repository = repository,
        _session = session,
        _syncPolicy = syncPolicy,
        _syncService = syncService,
        super(const StockTransferState()) {
    on<StockTransferListLoadRequested>(_onLoadList);
    on<StockTransferListRefreshRequested>(_onRefreshList);
    on<StockTransferDetailLoadRequested>(_onLoadDetail);
    on<StockTransferCreateSubmitted>(_onCreate);
    on<StockTransferValidateRequested>(_onValidate);
    on<StockTransferSubmitForApprovalRequested>(_onSubmitForApproval);
    on<StockTransferApproveRequested>(_onApprove);
    on<StockTransferShipRequested>(_onShip);
    on<StockTransferReceiveSubmitted>(_onReceive);
    on<StockTransferCancelRequested>(_onCancel);
    on<StockTransferCloseRequested>(_onClose);
    on<StockTransferResolveDiscrepancySubmitted>(_onResolveDiscrepancy);
    on<StockTransferReportLoadRequested>(_onLoadReport);
    on<StockTransferReturnCreateRequested>(_onCreateReturn);
    on<StockTransferDestinationsLoadRequested>(_onLoadDestinations);
  }

  final StockTransferRepository _repository;
  final AuthSession _session;
  final SyncPolicy _syncPolicy;
  final SyncService? _syncService;

  int get shopId => _session.shop.id;
  int get userId => _session.user.id;
  AuthSession get session => _session;

  Future<StockTransfer?> _loadTransferDetail(int transferId) =>
      _repository.findTransfer(transferId: transferId, shopId: shopId);

  void _scheduleCloudSync() {
    _syncService?.scheduleSync(shopId: shopId);
  }

  Future<
      ({
        List<StockTransfer> outgoing,
        List<StockTransfer> incoming,
        List<StockTransfer> inTransit,
      })> _loadLists() async {
    final outgoing = await _repository.listOutgoing(shopId: shopId);
    final incoming = await _repository.listIncoming(shopId: shopId);
    final inTransit = await _repository.listInTransit(shopId: shopId);
    return (outgoing: outgoing, incoming: incoming, inTransit: inTransit);
  }

  Future<void> _onLoadList(
    StockTransferListLoadRequested event,
    Emitter<StockTransferState> emit,
  ) async {
    await _fetchLists(emit, syncRemote: true, forceRemote: true);
  }

  Future<void> _onRefreshList(
    StockTransferListRefreshRequested event,
    Emitter<StockTransferState> emit,
  ) async {
    await _fetchLists(
      emit,
      syncRemote: true,
      forceRemote: event.forceRemote,
    );
  }

  Future<void> _fetchLists(
    Emitter<StockTransferState> emit, {
    bool syncRemote = false,
    bool forceRemote = false,
    bool localOnly = false,
  }) async {
    try {
      if (state.outgoing.isEmpty &&
          state.incoming.isEmpty &&
          state.inTransit.isEmpty &&
          state.status != StockTransferBlocStatus.loaded) {
        emit(
          state.copyWith(
            status: StockTransferBlocStatus.loading,
            clearError: true,
          ),
        );
      }

      final lists = await _loadLists();
      final report = await _repository.buildReportSummary(shopId: shopId);

      emit(
        state.copyWith(
          status: StockTransferBlocStatus.loaded,
          outgoing: lists.outgoing,
          incoming: lists.incoming,
          inTransit: lists.inTransit,
          reportSummary: report,
          isRefreshing: syncRemote && !localOnly,
          clearError: true,
        ),
      );

      if (localOnly) {
        emit(state.copyWith(isRefreshing: false));
        return;
      }

      if (!syncRemote ||
          !await _syncPolicy.shouldRunCloudSync(shopId: shopId)) {
        emit(state.copyWith(isRefreshing: false));
        return;
      }

      emit(state.copyWith(isRefreshing: true));

      try {
        await _repository.syncFromRemote(
          shopId: shopId,
          force: forceRemote,
          importUserId: userId,
        );
      } on Failure {
        // Sync cloud optionnelle — conserver les transferts locaux affichés.
      } catch (_) {
        // Données cloud partielles : ne pas bloquer la liste.
      }

      final refreshedLists = await _loadLists();
      final refreshedReport =
          await _repository.buildReportSummary(shopId: shopId);

      emit(
        state.copyWith(
          status: StockTransferBlocStatus.loaded,
          outgoing: refreshedLists.outgoing,
          incoming: refreshedLists.incoming,
          inTransit: refreshedLists.inTransit,
          reportSummary: refreshedReport,
          isRefreshing: false,
          clearError: true,
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          status: state.outgoing.isEmpty && state.incoming.isEmpty
              ? StockTransferBlocStatus.failure
              : StockTransferBlocStatus.loaded,
          errorMessage: friendlyErrorMessage(e),
          isRefreshing: false,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          status: state.outgoing.isEmpty && state.incoming.isEmpty
              ? StockTransferBlocStatus.failure
              : StockTransferBlocStatus.loaded,
          errorMessage: 'Impossible de charger les transferts.',
          isRefreshing: false,
        ),
      );
    }
  }

  Future<void> _onLoadDetail(
    StockTransferDetailLoadRequested event,
    Emitter<StockTransferState> emit,
  ) async {
    final hasExisting = state.selectedTransfer?.id == event.transferId;
    emit(
      state.copyWith(
        status: hasExisting
            ? StockTransferBlocStatus.loaded
            : StockTransferBlocStatus.loading,
        clearError: true,
      ),
    );
    try {
      final transfer = await _loadTransferDetail(event.transferId);
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.loaded,
          selectedTransfer: transfer,
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.failure,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    }
  }

  Future<void> _onCreateReturn(
    StockTransferReturnCreateRequested event,
    Emitter<StockTransferState> emit,
  ) async {
    emit(
      state.copyWith(
        status: StockTransferBlocStatus.refreshing,
        clearError: true,
        clearSuccess: true,
      ),
    );
    try {
      final returnTransfer = await _repository.createReturnTransfer(
        shopId: shopId,
        userId: userId,
        parentTransferId: event.parentTransferId,
        quantitiesByParentItemId: event.quantitiesByParentItemId,
      );
      final parent = await _loadTransferDetail(event.parentTransferId) ??
          state.selectedTransfer;
      final lists = await _loadLists();
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.loaded,
          outgoing: lists.outgoing,
          incoming: lists.incoming,
          inTransit: lists.inTransit,
          selectedTransfer: parent,
          successMessage:
              'Retour ${returnTransfer.reference} créé (brouillon).',
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.failure,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    }
  }

  Future<void> _onLoadDestinations(
    StockTransferDestinationsLoadRequested event,
    Emitter<StockTransferState> emit,
  ) async {
    try {
      final shops =
          await _repository.listDestinationShops(currentShopId: shopId);
      emit(state.copyWith(destinationShops: shops));
    } on Failure catch (e) {
      emit(state.copyWith(errorMessage: friendlyErrorMessage(e)));
    }
  }

  Future<void> _onCreate(
    StockTransferCreateSubmitted event,
    Emitter<StockTransferState> emit,
  ) async {
    emit(state.copyWith(status: StockTransferBlocStatus.refreshing, clearError: true));
    try {
      final transfer = await _repository.createTransfer(
        sourceShopId: shopId,
        destinationShopId: event.destinationShopId,
        userId: userId,
        reference: event.reference,
        notes: event.notes,
        items: event.items,
      );
      final lists = await _loadLists();
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.loaded,
          outgoing: lists.outgoing,
          incoming: lists.incoming,
          inTransit: lists.inTransit,
          selectedTransfer: transfer,
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.failure,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    }
  }

  Future<void> _onValidate(
    StockTransferValidateRequested event,
    Emitter<StockTransferState> emit,
  ) async {
    emit(state.copyWith(status: StockTransferBlocStatus.refreshing, clearError: true));
    try {
      final transfer = await _repository.validateTransfer(
        sourceShopId: shopId,
        userId: userId,
        transferId: event.transferId,
      );
      _scheduleCloudSync();
      final refreshed = await _loadTransferDetail(event.transferId) ?? transfer;
      final lists = await _loadLists();
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.loaded,
          outgoing: lists.outgoing,
          incoming: lists.incoming,
          inTransit: lists.inTransit,
          selectedTransfer: refreshed,
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.failure,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    }
  }

  Future<void> _onSubmitForApproval(
    StockTransferSubmitForApprovalRequested event,
    Emitter<StockTransferState> emit,
  ) async {
    emit(state.copyWith(status: StockTransferBlocStatus.refreshing, clearError: true));
    try {
      final transfer = await _repository.submitTransferForApproval(
        sourceShopId: shopId,
        userId: userId,
        transferId: event.transferId,
      );
      _scheduleCloudSync();
      final refreshed = await _loadTransferDetail(event.transferId) ?? transfer;
      final lists = await _loadLists();
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.loaded,
          outgoing: lists.outgoing,
          incoming: lists.incoming,
          inTransit: lists.inTransit,
          selectedTransfer: refreshed,
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.failure,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    }
  }

  Future<void> _onApprove(
    StockTransferApproveRequested event,
    Emitter<StockTransferState> emit,
  ) async {
    emit(state.copyWith(status: StockTransferBlocStatus.refreshing, clearError: true));
    try {
      final transfer = await _repository.approveTransfer(
        sourceShopId: shopId,
        userId: userId,
        transferId: event.transferId,
      );
      _scheduleCloudSync();
      final refreshed = await _loadTransferDetail(event.transferId) ?? transfer;
      final lists = await _loadLists();
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.loaded,
          outgoing: lists.outgoing,
          incoming: lists.incoming,
          inTransit: lists.inTransit,
          selectedTransfer: refreshed,
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.failure,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    }
  }

  Future<void> _onShip(
    StockTransferShipRequested event,
    Emitter<StockTransferState> emit,
  ) async {
    emit(state.copyWith(status: StockTransferBlocStatus.refreshing, clearError: true));
    try {
      final transfer = await _repository.shipTransfer(
        sourceShopId: shopId,
        userId: userId,
        transferId: event.transferId,
        shipmentLabel: event.shipmentLabel,
        shipmentNotes: event.shipmentNotes,
        driverName: event.driverName,
        vehiclePlate: event.vehiclePlate,
        quantitiesByItemId: event.quantitiesByItemId,
      );
      _scheduleCloudSync();
      final refreshed = await _loadTransferDetail(event.transferId) ?? transfer;
      final lists = await _loadLists();
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.loaded,
          outgoing: lists.outgoing,
          incoming: lists.incoming,
          inTransit: lists.inTransit,
          selectedTransfer: refreshed,
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.failure,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    }
  }

  Future<void> _onReceive(
    StockTransferReceiveSubmitted event,
    Emitter<StockTransferState> emit,
  ) async {
    emit(state.copyWith(status: StockTransferBlocStatus.refreshing, clearError: true));
    try {
      final transfer = await _repository.receiveTransfer(
        destinationShopId: shopId,
        userId: userId,
        transferId: event.transferId,
        quantitiesByItemId: event.quantitiesByItemId,
        refusalsByItemId: event.refusalsByItemId,
        salePriceByItemId: event.salePriceByItemId,
        shipmentId: event.shipmentId,
      );
      _scheduleCloudSync();
      final refreshed = await _loadTransferDetail(event.transferId) ?? transfer;
      final lists = await _loadLists();
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.loaded,
          outgoing: lists.outgoing,
          incoming: lists.incoming,
          inTransit: lists.inTransit,
          selectedTransfer: refreshed,
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.failure,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    }
  }

  Future<void> _onCancel(
    StockTransferCancelRequested event,
    Emitter<StockTransferState> emit,
  ) async {
    emit(state.copyWith(status: StockTransferBlocStatus.refreshing, clearError: true));
    try {
      await _repository.cancelTransfer(
        sourceShopId: shopId,
        userId: userId,
        transferId: event.transferId,
      );
      _scheduleCloudSync();
      final lists = await _loadLists();
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.loaded,
          outgoing: lists.outgoing,
          incoming: lists.incoming,
          inTransit: lists.inTransit,
          clearSelectedTransfer: true,
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.failure,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    }
  }

  Future<void> _onClose(
    StockTransferCloseRequested event,
    Emitter<StockTransferState> emit,
  ) async {
    emit(state.copyWith(status: StockTransferBlocStatus.refreshing, clearError: true));
    try {
      final transfer = await _repository.closeTransfer(
        sourceShopId: shopId,
        userId: userId,
        transferId: event.transferId,
        notes: event.notes,
      );
      _scheduleCloudSync();
      final refreshed = await _loadTransferDetail(event.transferId) ?? transfer;
      final lists = await _loadLists();
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.loaded,
          outgoing: lists.outgoing,
          incoming: lists.incoming,
          inTransit: lists.inTransit,
          selectedTransfer: refreshed,
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.failure,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    }
  }

  Future<void> _onResolveDiscrepancy(
    StockTransferResolveDiscrepancySubmitted event,
    Emitter<StockTransferState> emit,
  ) async {
    emit(state.copyWith(status: StockTransferBlocStatus.refreshing, clearError: true));
    try {
      final transfer = await _repository.resolveDiscrepancy(
        sourceShopId: shopId,
        userId: userId,
        transferId: event.transferId,
        itemId: event.itemId,
        quantity: event.quantity,
        reason: event.reason,
        resolution: event.resolution,
        notes: event.notes,
      );
      _scheduleCloudSync();
      final refreshed = await _loadTransferDetail(event.transferId) ?? transfer;
      final lists = await _loadLists();
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.loaded,
          outgoing: lists.outgoing,
          incoming: lists.incoming,
          inTransit: lists.inTransit,
          selectedTransfer: refreshed,
        ),
      );
    } on Failure catch (e) {
      emit(
        state.copyWith(
          status: StockTransferBlocStatus.failure,
          errorMessage: friendlyErrorMessage(e),
        ),
      );
    }
  }

  Future<void> _onLoadReport(
    StockTransferReportLoadRequested event,
    Emitter<StockTransferState> emit,
  ) async {
    try {
      final report = await _repository.buildReportSummary(shopId: shopId);
      emit(state.copyWith(reportSummary: report));
    } on Failure catch (e) {
      emit(state.copyWith(errorMessage: friendlyErrorMessage(e)));
    }
  }
}
