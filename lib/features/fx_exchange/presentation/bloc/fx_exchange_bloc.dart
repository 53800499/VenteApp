import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/fx_exchange_entities.dart';
import '../../domain/usecases/fx_exchange_usecases.dart';
import '../fx_workspace_mode_controller.dart';

enum FxExchangeStatus { initial, loading, ready, failure }

abstract class FxExchangeEvent extends Equatable {
  const FxExchangeEvent();

  @override
  List<Object?> get props => [];
}

class FxExchangeLoadRequested extends FxExchangeEvent {
  const FxExchangeLoadRequested();
}

class FxExchangeRefreshRequested extends FxExchangeEvent {
  const FxExchangeRefreshRequested();
}

class FxModuleToggleRequested extends FxExchangeEvent {
  const FxModuleToggleRequested({required this.enabled});

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

class FxOpenSessionRequested extends FxExchangeEvent {
  const FxOpenSessionRequested({required this.openingBalances});

  final Map<String, int> openingBalances;

  @override
  List<Object?> get props => [openingBalances];
}

class FxCloseSessionRequested extends FxExchangeEvent {
  const FxCloseSessionRequested({
    required this.countedBalances,
    this.closingNote,
  });

  final Map<String, int> countedBalances;
  final String? closingNote;

  @override
  List<Object?> get props => [countedBalances, closingNote];
}

class FxConfirmCloseSessionRequested extends FxExchangeEvent {
  const FxConfirmCloseSessionRequested();
}

class FxCancelPendingCloseRequested extends FxExchangeEvent {
  const FxCancelPendingCloseRequested();
}

class FxCreateRateRequested extends FxExchangeEvent {
  const FxCreateRateRequested({required this.input});

  final CreateFxRateInput input;

  @override
  List<Object?> get props => [input];
}

class FxCreateOperationRequested extends FxExchangeEvent {
  const FxCreateOperationRequested({
    required this.input,
    required this.allowNegativeBalance,
  });

  final CreateFxOperationInput input;
  final bool allowNegativeBalance;

  @override
  List<Object?> get props => [input, allowNegativeBalance];
}

class FxCreateMovementRequested extends FxExchangeEvent {
  const FxCreateMovementRequested({
    required this.input,
    required this.allowNegativeBalance,
  });

  final CreateFxMovementInput input;
  final bool allowNegativeBalance;

  @override
  List<Object?> get props => [input, allowNegativeBalance];
}

class FxSaveCurrenciesRequested extends FxExchangeEvent {
  const FxSaveCurrenciesRequested({required this.items});

  final List<UpsertFxShopCurrencyInput> items;

  @override
  List<Object?> get props => [items];
}

class FxSaveCustomerThresholdRequested extends FxExchangeEvent {
  const FxSaveCustomerThresholdRequested({required this.amountFcfa});

  final int amountFcfa;

  @override
  List<Object?> get props => [amountFcfa];
}

class FxPrimaryWorkspaceSaveRequested extends FxExchangeEvent {
  const FxPrimaryWorkspaceSaveRequested({required this.enabled});

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

class FxExchangeState extends Equatable {
  const FxExchangeState({
    this.status = FxExchangeStatus.initial,
    this.moduleEnabled = false,
    this.currencies = const [],
    this.shopCurrencies = const [],
    this.latestRates = const [],
    this.openSession,
    this.liveBalances = const {},
    this.history = const [],
    this.operations = const [],
    this.movements = const [],
    this.customerRequiredAboveFcfa = 0,
    this.primaryWorkspace = false,
    this.isRefreshing = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.successMessage,
  });

  final FxExchangeStatus status;
  final bool moduleEnabled;
  final List<FxCurrency> currencies;
  final List<FxShopCurrency> shopCurrencies;
  final List<FxRateSnapshot> latestRates;
  final FxSession? openSession;
  final Map<String, int> liveBalances;
  final List<FxSessionListRow> history;
  final List<FxOperation> operations;
  final List<FxMovement> movements;
  final int customerRequiredAboveFcfa;
  final bool primaryWorkspace;
  final bool isRefreshing;
  final bool isSubmitting;
  final String? errorMessage;
  final String? successMessage;

  FxExchangeState copyWith({
    FxExchangeStatus? status,
    bool? moduleEnabled,
    List<FxCurrency>? currencies,
    List<FxShopCurrency>? shopCurrencies,
    List<FxRateSnapshot>? latestRates,
    FxSession? openSession,
    bool clearOpenSession = false,
    Map<String, int>? liveBalances,
    List<FxSessionListRow>? history,
    List<FxOperation>? operations,
    List<FxMovement>? movements,
    int? customerRequiredAboveFcfa,
    bool? primaryWorkspace,
    bool? isRefreshing,
    bool? isSubmitting,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return FxExchangeState(
      status: status ?? this.status,
      moduleEnabled: moduleEnabled ?? this.moduleEnabled,
      currencies: currencies ?? this.currencies,
      shopCurrencies: shopCurrencies ?? this.shopCurrencies,
      latestRates: latestRates ?? this.latestRates,
      openSession: clearOpenSession ? null : (openSession ?? this.openSession),
      liveBalances: liveBalances ?? this.liveBalances,
      history: history ?? this.history,
      operations: operations ?? this.operations,
      movements: movements ?? this.movements,
      customerRequiredAboveFcfa:
          customerRequiredAboveFcfa ?? this.customerRequiredAboveFcfa,
      primaryWorkspace: primaryWorkspace ?? this.primaryWorkspace,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage:
          clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        moduleEnabled,
        currencies,
        shopCurrencies,
        latestRates,
        openSession,
        liveBalances,
        history,
        operations,
        movements,
        customerRequiredAboveFcfa,
        primaryWorkspace,
        isRefreshing,
        isSubmitting,
        errorMessage,
        successMessage,
      ];
}

class FxExchangeBloc extends Bloc<FxExchangeEvent, FxExchangeState> {
  FxExchangeBloc({
    required AuthSession session,
    required IsFxModuleEnabled isModuleEnabled,
    required ToggleFxModule toggleModule,
    required ListFxCurrencies listCurrencies,
    required ListFxShopCurrencies listShopCurrencies,
    required UpsertFxShopCurrencies upsertShopCurrencies,
    required CreateFxRate createRate,
    required ListFxLatestRates listLatestRates,
    required ListFxSessionRates listSessionRates,
    required FindOpenFxSession findOpenSession,
    required ListFxSessions listSessions,
    required GetFxLiveBalances getLiveBalances,
    required OpenFxSession openSession,
    required CloseFxSession closeSession,
    required ConfirmFxSessionClose confirmCloseSession,
    required CancelFxPendingClose cancelPendingClose,
    required CreateFxOperation createOperation,
    required CreateFxMovement createMovement,
    required ListFxOperations listOperations,
    required ListFxMovements listMovements,
    required GetFxCustomerRequiredAboveFcfa getCustomerRequiredAboveFcfa,
    required SetFxCustomerRequiredAboveFcfa setCustomerRequiredAboveFcfa,
    required GetFxPrimaryWorkspace getPrimaryWorkspace,
    required SetFxPrimaryWorkspace setPrimaryWorkspace,
    required FxWorkspaceModeController workspaceMode,
    required SyncFxExchangeFromRemote syncFromRemote,
  })  : _session = session,
        _isModuleEnabled = isModuleEnabled,
        _toggleModule = toggleModule,
        _listCurrencies = listCurrencies,
        _listShopCurrencies = listShopCurrencies,
        _upsertShopCurrencies = upsertShopCurrencies,
        _createRate = createRate,
        _listLatestRates = listLatestRates,
        _listSessionRates = listSessionRates,
        _findOpenSession = findOpenSession,
        _listSessions = listSessions,
        _getLiveBalances = getLiveBalances,
        _openSession = openSession,
        _closeSession = closeSession,
        _confirmCloseSession = confirmCloseSession,
        _cancelPendingClose = cancelPendingClose,
        _createOperation = createOperation,
        _createMovement = createMovement,
        _listOperations = listOperations,
        _listMovements = listMovements,
        _getCustomerRequiredAboveFcfa = getCustomerRequiredAboveFcfa,
        _setCustomerRequiredAboveFcfa = setCustomerRequiredAboveFcfa,
        _getPrimaryWorkspace = getPrimaryWorkspace,
        _setPrimaryWorkspace = setPrimaryWorkspace,
        _workspaceMode = workspaceMode,
        _syncFromRemote = syncFromRemote,
        super(const FxExchangeState()) {
    on<FxExchangeLoadRequested>(_onLoad);
    on<FxExchangeRefreshRequested>(_onRefresh);
    on<FxModuleToggleRequested>(_onToggleModule);
    on<FxOpenSessionRequested>(_onOpenSession);
    on<FxCloseSessionRequested>(_onCloseSession);
    on<FxConfirmCloseSessionRequested>(_onConfirmCloseSession);
    on<FxCancelPendingCloseRequested>(_onCancelPendingClose);
    on<FxCreateRateRequested>(_onCreateRate);
    on<FxCreateOperationRequested>(_onCreateOperation);
    on<FxCreateMovementRequested>(_onCreateMovement);
    on<FxSaveCurrenciesRequested>(_onSaveCurrencies);
    on<FxSaveCustomerThresholdRequested>(_onSaveCustomerThreshold);
    on<FxPrimaryWorkspaceSaveRequested>(_onSavePrimaryWorkspace);
  }

  final AuthSession _session;
  final IsFxModuleEnabled _isModuleEnabled;
  final ToggleFxModule _toggleModule;
  final ListFxCurrencies _listCurrencies;
  final ListFxShopCurrencies _listShopCurrencies;
  final UpsertFxShopCurrencies _upsertShopCurrencies;
  final CreateFxRate _createRate;
  final ListFxLatestRates _listLatestRates;
  final ListFxSessionRates _listSessionRates;
  final FindOpenFxSession _findOpenSession;
  final ListFxSessions _listSessions;
  final GetFxLiveBalances _getLiveBalances;
  final OpenFxSession _openSession;
  final CloseFxSession _closeSession;
  final ConfirmFxSessionClose _confirmCloseSession;
  final CancelFxPendingClose _cancelPendingClose;
  final CreateFxOperation _createOperation;
  final CreateFxMovement _createMovement;
  final ListFxOperations _listOperations;
  final ListFxMovements _listMovements;
  final GetFxCustomerRequiredAboveFcfa _getCustomerRequiredAboveFcfa;
  final SetFxCustomerRequiredAboveFcfa _setCustomerRequiredAboveFcfa;
  final GetFxPrimaryWorkspace _getPrimaryWorkspace;
  final SetFxPrimaryWorkspace _setPrimaryWorkspace;
  final FxWorkspaceModeController _workspaceMode;
  final SyncFxExchangeFromRemote _syncFromRemote;

  AuthSession get session => _session;
  int get shopId => _session.shop.id;

  Future<void> _onLoad(
    FxExchangeLoadRequested event,
    Emitter<FxExchangeState> emit,
  ) async {
    final showFullLoader = state.status == FxExchangeStatus.initial;
    if (showFullLoader) {
      emit(state.copyWith(status: FxExchangeStatus.loading, clearMessages: true));
    }
    await _loadCore(
      emit,
      refreshRemote: true,
      showFullLoader: showFullLoader,
    );
  }

  Future<void> _onRefresh(
    FxExchangeRefreshRequested event,
    Emitter<FxExchangeState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true, clearMessages: true));
    await _loadCore(
      emit,
      refreshRemote: true,
      showFullLoader: false,
    );
    emit(state.copyWith(isRefreshing: false));
  }

  Future<void> _loadCore(
    Emitter<FxExchangeState> emit, {
    required bool refreshRemote,
    required bool showFullLoader,
  }) async {
    try {
      final snapshot = await _readLocalSnapshot();
      emit(
        state.copyWith(
          status: FxExchangeStatus.ready,
          moduleEnabled: snapshot.enabled,
          currencies: snapshot.currencies,
          shopCurrencies: snapshot.shopCurrencies,
          latestRates: snapshot.latestRates,
          openSession: snapshot.openSession,
          clearOpenSession: snapshot.openSession == null,
          liveBalances: snapshot.liveBalances,
          history: snapshot.history,
          operations: snapshot.operations,
          movements: snapshot.movements,
          customerRequiredAboveFcfa: snapshot.customerRequiredAboveFcfa,
          primaryWorkspace: snapshot.primaryWorkspace,
        ),
      );
      _workspaceMode.apply(
        primary: snapshot.primaryWorkspace,
        moduleEnabled: snapshot.enabled,
      );
      if (!refreshRemote || !snapshot.enabled) return;

      emit(state.copyWith(isRefreshing: true));
      try {
        await _syncFromRemote(shopId: shopId);
      } catch (_) {
        // Données locales déjà affichées.
      }

      final refreshed = await _readLocalSnapshot();
      emit(
        state.copyWith(
          status: FxExchangeStatus.ready,
          isRefreshing: false,
          moduleEnabled: refreshed.enabled,
          currencies: refreshed.currencies,
          shopCurrencies: refreshed.shopCurrencies,
          latestRates: refreshed.latestRates,
          openSession: refreshed.openSession,
          clearOpenSession: refreshed.openSession == null,
          liveBalances: refreshed.liveBalances,
          history: refreshed.history,
          operations: refreshed.operations,
          movements: refreshed.movements,
          customerRequiredAboveFcfa: refreshed.customerRequiredAboveFcfa,
          primaryWorkspace: refreshed.primaryWorkspace,
        ),
      );
      _workspaceMode.apply(
        primary: refreshed.primaryWorkspace,
        moduleEnabled: refreshed.enabled,
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: showFullLoader && state.status == FxExchangeStatus.loading
              ? FxExchangeStatus.failure
              : FxExchangeStatus.ready,
          isRefreshing: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<_FxLocalSnapshot> _readLocalSnapshot() async {
    final enabled = await _isModuleEnabled(shopId: shopId);
    List<FxCurrency> currencies = const [];
    try {
      currencies = await _listCurrencies();
    } catch (_) {}

    List<FxShopCurrency> shopCurrencies = const [];
    try {
      shopCurrencies = await _listShopCurrencies(shopId: shopId);
    } catch (_) {}

    final history =
        enabled ? await _safeListSessions() : <FxSessionListRow>[];
    var customerRequiredAboveFcfa = 0;
    try {
      customerRequiredAboveFcfa =
          await _getCustomerRequiredAboveFcfa(shopId: shopId);
    } catch (_) {
      customerRequiredAboveFcfa = 0;
    }
    var primaryWorkspace = false;
    try {
      primaryWorkspace = await _getPrimaryWorkspace(shopId: shopId);
    } catch (_) {
      primaryWorkspace = false;
    }
    FxSession? openSession;
    Map<String, int> liveBalances = {};
    List<FxOperation> operations = [];
    List<FxMovement> movements = [];
    List<FxRateSnapshot> latestRates = [];

    if (enabled) {
      try {
        openSession = await _findOpenSession(shopId: shopId);
        if (openSession != null) {
          // Pendant une session : afficher les taux gelés (pas le dernier snapshot global).
          latestRates = await _listSessionRates(
            shopId: shopId,
            sessionId: openSession.id,
          );
          liveBalances = await _getLiveBalances(
            shopId: shopId,
            sessionId: openSession.id,
          );
          operations = await _listOperations(
            shopId: shopId,
            sessionId: openSession.id,
          );
          movements = await _listMovements(
            shopId: shopId,
            sessionId: openSession.id,
          );
        } else {
          latestRates = await _listLatestRates(shopId: shopId);
        }
      } catch (_) {
        // Module actif : on affiche quand même l'écran même si une sous-lecture échoue.
        try {
          latestRates = await _listLatestRates(shopId: shopId);
        } catch (_) {}
      }
    }

    return _FxLocalSnapshot(
      enabled: enabled,
      currencies: currencies,
      shopCurrencies: shopCurrencies,
      latestRates: latestRates,
      openSession: openSession,
      liveBalances: liveBalances,
      history: history,
      operations: operations,
      movements: movements,
      customerRequiredAboveFcfa: customerRequiredAboveFcfa,
      primaryWorkspace: primaryWorkspace,
    );
  }

  Future<List<FxSessionListRow>> _safeListSessions() async {
    try {
      return await _listSessions(shopId: shopId);
    } catch (_) {
      return const [];
    }
  }

  Future<void> _onToggleModule(
    FxModuleToggleRequested event,
    Emitter<FxExchangeState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      await _toggleModule(shopId: shopId, enabled: event.enabled);
      _workspaceMode.apply(
        primary: state.primaryWorkspace,
        moduleEnabled: event.enabled,
      );
      await _loadCore(
        emit,
        refreshRemote: false,
        showFullLoader: false,
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          moduleEnabled: event.enabled,
          successMessage: event.enabled
              ? 'Module Bureau de change activé.'
              : 'Module Bureau de change désactivé.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _onOpenSession(
    FxOpenSessionRequested event,
    Emitter<FxExchangeState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      await _openSession(
        shopId: shopId,
        userId: _session.user.id,
        input: OpenFxSessionInput(openingBalances: event.openingBalances),
      );
      add(const FxExchangeLoadRequested());
      emit(
        state.copyWith(
          isSubmitting: false,
          successMessage: 'Session FX ouverte.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _onCloseSession(
    FxCloseSessionRequested event,
    Emitter<FxExchangeState> emit,
  ) async {
    final session = state.openSession;
    if (session == null) return;

    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      await _closeSession(
        shopId: shopId,
        userId: _session.user.id,
        sessionId: session.id,
        input: CloseFxSessionInput(
          countedBalances: event.countedBalances,
          closingNote: event.closingNote,
        ),
      );
      add(const FxExchangeLoadRequested());
      emit(
        state.copyWith(
          isSubmitting: false,
          successMessage: 'Comptage soumis — en attente de validation.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _onConfirmCloseSession(
    FxConfirmCloseSessionRequested event,
    Emitter<FxExchangeState> emit,
  ) async {
    final session = state.openSession;
    if (session == null) return;

    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      await _confirmCloseSession(
        shopId: shopId,
        userId: _session.user.id,
        sessionId: session.id,
      );
      add(const FxExchangeLoadRequested());
      emit(
        state.copyWith(
          isSubmitting: false,
          successMessage: 'Session FX clôturée.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _onCancelPendingClose(
    FxCancelPendingCloseRequested event,
    Emitter<FxExchangeState> emit,
  ) async {
    final session = state.openSession;
    if (session == null) return;

    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      await _cancelPendingClose(
        shopId: shopId,
        sessionId: session.id,
      );
      add(const FxExchangeLoadRequested());
      emit(
        state.copyWith(
          isSubmitting: false,
          successMessage: 'Clôture annulée — session rouverte.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _onCreateRate(
    FxCreateRateRequested event,
    Emitter<FxExchangeState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      await _createRate(
        shopId: shopId,
        userId: _session.user.id,
        input: event.input,
      );
      add(const FxExchangeLoadRequested());
      final appliedNow = event.input.applyMode == FxRateApplyMode.now;
      emit(
        state.copyWith(
          isSubmitting: false,
          successMessage: appliedNow
              ? 'Taux enregistré et appliqué à la session.'
              : 'Taux enregistré (prochaine session).',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _onCreateOperation(
    FxCreateOperationRequested event,
    Emitter<FxExchangeState> emit,
  ) async {
    final session = state.openSession;
    if (session == null) return;

    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      await _createOperation(
        shopId: shopId,
        userId: _session.user.id,
        sessionId: session.id,
        input: event.input,
        allowNegativeBalance: event.allowNegativeBalance,
      );
      add(const FxExchangeLoadRequested());
      emit(
        state.copyWith(
          isSubmitting: false,
          successMessage: 'Opération enregistrée.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _onCreateMovement(
    FxCreateMovementRequested event,
    Emitter<FxExchangeState> emit,
  ) async {
    final session = state.openSession;
    if (session == null) return;

    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      await _createMovement(
        shopId: shopId,
        userId: _session.user.id,
        sessionId: session.id,
        input: event.input,
        allowNegativeBalance: event.allowNegativeBalance,
      );
      add(const FxExchangeLoadRequested());
      emit(
        state.copyWith(
          isSubmitting: false,
          successMessage: 'Mouvement enregistré.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _onSaveCurrencies(
    FxSaveCurrenciesRequested event,
    Emitter<FxExchangeState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      await _upsertShopCurrencies(shopId: shopId, items: event.items);
      add(const FxExchangeLoadRequested());
      emit(
        state.copyWith(
          isSubmitting: false,
          successMessage: 'Devises mises à jour.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _onSaveCustomerThreshold(
    FxSaveCustomerThresholdRequested event,
    Emitter<FxExchangeState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      await _setCustomerRequiredAboveFcfa(
        shopId: shopId,
        amountFcfa: event.amountFcfa,
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          customerRequiredAboveFcfa: event.amountFcfa,
          successMessage: 'Seuil client mis à jour.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _onSavePrimaryWorkspace(
    FxPrimaryWorkspaceSaveRequested event,
    Emitter<FxExchangeState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearMessages: true));
    try {
      if (event.enabled && !state.moduleEnabled) {
        await _toggleModule(shopId: shopId, enabled: true);
      }
      await _setPrimaryWorkspace(shopId: shopId, enabled: event.enabled);
      final moduleEnabled = event.enabled ? true : state.moduleEnabled;
      _workspaceMode.apply(
        primary: event.enabled,
        moduleEnabled: moduleEnabled,
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          moduleEnabled: moduleEnabled,
          primaryWorkspace: event.enabled,
          successMessage: event.enabled
              ? 'Change est maintenant l’écran d’accueil.'
              : 'Navigation classique rétablie.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }
}

class _FxLocalSnapshot {
  const _FxLocalSnapshot({
    required this.enabled,
    required this.currencies,
    required this.shopCurrencies,
    required this.latestRates,
    required this.openSession,
    required this.liveBalances,
    required this.history,
    required this.operations,
    required this.movements,
    required this.customerRequiredAboveFcfa,
    required this.primaryWorkspace,
  });

  final bool enabled;
  final List<FxCurrency> currencies;
  final List<FxShopCurrency> shopCurrencies;
  final List<FxRateSnapshot> latestRates;
  final FxSession? openSession;
  final Map<String, int> liveBalances;
  final List<FxSessionListRow> history;
  final List<FxOperation> operations;
  final List<FxMovement> movements;
  final int customerRequiredAboveFcfa;
  final bool primaryWorkspace;
}
