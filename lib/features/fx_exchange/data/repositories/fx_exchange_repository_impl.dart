import 'dart:async';

import '../../../../core/network/remote_api_guard.dart';
import '../../../../core/sync/local_write_sync_recorder.dart';
import '../../../../core/sync/sync_constants.dart';
import '../../domain/entities/fx_exchange_entities.dart';
import '../../domain/repositories/fx_exchange_repository.dart';
import '../datasources/local/fx_exchange_local_datasource.dart';
import '../datasources/remote/fx_exchange_remote_datasource.dart';

class FxExchangeRepositoryImpl implements FxExchangeRepository {
  FxExchangeRepositoryImpl({
    required FxExchangeLocalDatasource local,
    FxExchangeRemoteDatasource? remote,
    RemoteApiGuard? apiGuard,
    LocalWriteSyncRecorder? recorder,
  })  : _local = local,
        _remote = remote,
        _apiGuard = apiGuard,
        _recorder = recorder;

  final FxExchangeLocalDatasource _local;
  final FxExchangeRemoteDatasource? _remote;
  final RemoteApiGuard? _apiGuard;
  final LocalWriteSyncRecorder? _recorder;

  @override
  Future<bool> isModuleEnabled({required int shopId}) =>
      _local.isModuleEnabled(shopId);

  static const _moduleToggleRemoteTimeout = Duration(seconds: 12);

  @override
  Future<void> toggleModule({required int shopId, required bool enabled}) async {
    await _local.saveModuleStatus(shopId, enabled);
    unawaited(_pushModuleToggleToRemote(shopId: shopId, enabled: enabled));
  }

  Future<void> _pushModuleToggleToRemote({
    required int shopId,
    required bool enabled,
  }) async {
    try {
      await _apiGuard
          ?.ensureReady(timeout: _moduleToggleRemoteTimeout)
          .timeout(_moduleToggleRemoteTimeout);
      await _remote
          ?.toggleModule(enabled)
          .timeout(_moduleToggleRemoteTimeout);
    } catch (_) {
      await _recorder?.record(
        shopId: shopId,
        entityTable: SyncEntityTable.tenantModules,
        recordId: 1,
        operation: SyncOperation.update,
        payload: {'moduleCode': fxModuleCode, 'enabled': enabled},
      );
    }
  }

  @override
  Future<List<FxCurrency>> listCurrencies() => _local.listCurrencies();

  @override
  Future<List<FxShopCurrency>> listShopCurrencies({required int shopId}) =>
      _local.listShopCurrencies(shopId);

  @override
  Future<List<FxShopCurrency>> upsertShopCurrencies({
    required int shopId,
    required List<UpsertFxShopCurrencyInput> items,
  }) =>
      _local.upsertShopCurrencies(shopId, items);

  @override
  Future<FxRateSnapshot> createRate({
    required int shopId,
    required int userId,
    required CreateFxRateInput input,
  }) async {
    final rate = await _local.createRate(
      shopId: shopId,
      userId: userId,
      input: input,
    );
    await _recorder?.record(
      shopId: shopId,
      entityTable: SyncEntityTable.fxRateSnapshots,
      recordId: rate.id,
      operation: SyncOperation.create,
      payload: {
        'quoteCurrency': input.quoteCurrency,
        'buyRateNumerator': input.buyRateNumerator,
        'buyRateDenominator': input.buyRateDenominator,
        'sellRateNumerator': input.sellRateNumerator,
        'sellRateDenominator': input.sellRateDenominator,
      },
    );
    return rate;
  }

  @override
  Future<List<FxRateSnapshot>> listLatestRates({required int shopId}) =>
      _local.listLatestRates(shopId);

  @override
  Future<List<FxRateSnapshot>> listRateHistory({
    required int shopId,
    String? quoteCurrency,
    int limit = 100,
  }) =>
      _local.listRateHistory(
        shopId: shopId,
        quoteCurrency: quoteCurrency,
        limit: limit,
      );

  @override
  Future<FxSession?> findOpenSession({required int shopId}) =>
      _local.findOpenSession(shopId);

  @override
  Future<List<FxSessionListRow>> listSessions({
    required int shopId,
    int limit = 50,
  }) =>
      _local.listSessions(shopId: shopId, limit: limit);

  @override
  Future<FxSession> getSession({
    required int shopId,
    required int sessionId,
  }) =>
      _local.getSession(shopId, sessionId);

  @override
  Future<Map<String, int>> computeLiveBalances({
    required int shopId,
    required int sessionId,
  }) =>
      _local.computeLiveBalances(shopId, sessionId);

  @override
  Future<FxSession> openSession({
    required int shopId,
    required int userId,
    required OpenFxSessionInput input,
  }) async {
    final session = await _local.openSession(
      shopId: shopId,
      userId: userId,
      input: input,
    );
    await _recorder?.record(
      shopId: shopId,
      entityTable: SyncEntityTable.fxSessions,
      recordId: session.id,
      operation: SyncOperation.fxSessionOpen,
      payload: {
        'openingBalances': input.openingBalances.entries
            .map(
              (e) => {'currencyCode': e.key, 'amount': e.value},
            )
            .toList(),
      },
    );
    return session;
  }

  @override
  Future<FxSession> closeSession({
    required int shopId,
    required int userId,
    required int sessionId,
    required CloseFxSessionInput input,
  }) async {
    final session = await _local.closeSession(
      shopId: shopId,
      userId: userId,
      sessionId: sessionId,
      input: input,
    );
    await _recorder?.record(
      shopId: shopId,
      entityTable: SyncEntityTable.fxSessions,
      recordId: sessionId,
      operation: SyncOperation.fxSessionClose,
      payload: {
        'countedBalances': input.countedBalances.entries
            .map(
              (e) => {'currencyCode': e.key, 'amount': e.value},
            )
            .toList(),
        'closingNote': input.closingNote,
      },
    );
    return session;
  }

  @override
  Future<FxOperationPreview> previewOperation({
    required int shopId,
    required CreateFxOperationInput input,
  }) =>
      _local.previewOperation(shopId: shopId, input: input);

  @override
  Future<FxOperation> createOperation({
    required int shopId,
    required int userId,
    required int sessionId,
    required CreateFxOperationInput input,
    required bool allowNegativeBalance,
  }) async {
    final operation = await _local.createOperation(
      shopId: shopId,
      userId: userId,
      sessionId: sessionId,
      input: input,
      allowNegativeBalance: allowNegativeBalance,
    );
    await _recorder?.record(
      shopId: shopId,
      entityTable: SyncEntityTable.fxOperations,
      recordId: operation.id,
      operation: SyncOperation.fxOperationCreate,
      payload: {
        'sessionId': sessionId,
        'operationType': input.operationType.code,
        'fromCurrency': input.fromCurrency,
        'fromAmount': input.fromAmount,
        'toCurrency': input.toCurrency,
        'toAmount': operation.toAmount,
        'note': input.note,
      },
    );
    return operation;
  }

  @override
  Future<List<FxOperation>> listOperations({
    required int shopId,
    int? sessionId,
    int limit = 200,
  }) =>
      _local.listOperations(
        shopId: shopId,
        sessionId: sessionId,
        limit: limit,
      );

  @override
  Future<FxMovement> createMovement({
    required int shopId,
    required int userId,
    required int sessionId,
    required CreateFxMovementInput input,
    required bool allowNegativeBalance,
  }) async {
    final movement = await _local.createMovement(
      shopId: shopId,
      userId: userId,
      sessionId: sessionId,
      input: input,
      allowNegativeBalance: allowNegativeBalance,
    );
    await _recorder?.record(
      shopId: shopId,
      entityTable: SyncEntityTable.fxMovements,
      recordId: movement.id,
      operation: SyncOperation.fxMovementCreate,
      payload: {
        'sessionId': sessionId,
        'currencyCode': input.currencyCode,
        'movementType': input.movementType.code,
        'amount': input.amount,
        'note': input.note,
      },
    );
    return movement;
  }

  @override
  Future<List<FxMovement>> listMovements({
    required int shopId,
    int? sessionId,
    int limit = 200,
  }) =>
      _local.listMovements(
        shopId: shopId,
        sessionId: sessionId,
        limit: limit,
      );

  @override
  Future<FxDailyReport> getDailyReport({
    required int shopId,
    required int sessionId,
  }) async {
    final session = await _local.getSession(shopId, sessionId);
    final operations = await _local.listOperations(
      shopId: shopId,
      sessionId: sessionId,
      limit: 10_000,
    );
    final movements = await _local.listMovements(
      shopId: shopId,
      sessionId: sessionId,
      limit: 10_000,
    );
    final live = session.isOpen
        ? await _local.computeLiveBalances(shopId, sessionId)
        : {
            for (final b in session.balances)
              b.currencyCode: b.expectedBalance ?? b.openingBalance,
          };

    final volumeByCurrency = <String, int>{};
    for (final op in operations) {
      volumeByCurrency[op.fromCurrency] =
          (volumeByCurrency[op.fromCurrency] ?? 0) + op.fromAmount;
    }

    return FxDailyReport(
      session: session,
      operations: operations,
      movements: movements,
      liveBalances: live,
      volumeByCurrency: volumeByCurrency,
    );
  }

  static const _syncRemoteTimeout = Duration(seconds: 12);

  @override
  Future<void> syncFromRemote({required int shopId}) async {
    final remote = _remote;
    final guard = _apiGuard;
    if (remote == null || guard == null) return;

    final enabledLocally = await _local.isModuleEnabled(shopId);
    if (!enabledLocally) return;

    try {
      await guard
          .ensureReady(timeout: _syncRemoteTimeout)
          .timeout(_syncRemoteTimeout);
    } catch (_) {
      return;
    }

    // Ne pas écraser le statut local du module (offline-first).
    try {
      await remote.fetchRates().timeout(_syncRemoteTimeout);
    } catch (_) {}

    try {
      await remote.fetchOpenSession().timeout(_syncRemoteTimeout);
    } catch (_) {}
  }
}
