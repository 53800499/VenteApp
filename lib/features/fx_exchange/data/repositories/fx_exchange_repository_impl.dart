import 'dart:async';

import '../../../../core/network/remote_api_guard.dart';
import '../../../../core/sync/local_write_sync_recorder.dart';
import '../../../../core/sync/sync_constants.dart';
import '../../../../core/sync/sync_policy.dart';
import '../../../../core/sync/sync_pull_entity.dart';
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
    SyncPolicy? syncPolicy,
  })  : _local = local,
        _remote = remote,
        _apiGuard = apiGuard,
        _recorder = recorder,
        _syncPolicy = syncPolicy;

  final FxExchangeLocalDatasource _local;
  final FxExchangeRemoteDatasource? _remote;
  final RemoteApiGuard? _apiGuard;
  final LocalWriteSyncRecorder? _recorder;
  final SyncPolicy? _syncPolicy;

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
  }) async {
    final result = await _local.upsertShopCurrencies(shopId, items);
    await _recorder?.record(
      shopId: shopId,
      entityTable: SyncEntityTable.fxShopCurrencies,
      recordId: shopId,
      operation: SyncOperation.update,
      payload: {
        'currencies': items
            .map(
              (i) => {
                'currencyCode': i.currencyCode,
                'enabled': i.enabled,
                'sortOrder': i.sortOrder,
              },
            )
            .toList(),
      },
    );
    return result;
  }

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
        'applyMode': input.applyMode.code,
      },
    );
    return rate;
  }

  @override
  Future<List<FxRateSnapshot>> listLatestRates({required int shopId}) =>
      _local.listLatestRates(shopId);

  @override
  Future<List<FxRateSnapshot>> listSessionRates({
    required int shopId,
    required int sessionId,
  }) =>
      _local.listSessionRates(shopId, sessionId);

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
    final session = await _local.submitCloseSession(
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
  Future<FxSession> confirmCloseSession({
    required int shopId,
    required int userId,
    required int sessionId,
  }) async {
    final session = await _local.confirmCloseSession(
      shopId: shopId,
      userId: userId,
      sessionId: sessionId,
    );
    await _recorder?.record(
      shopId: shopId,
      entityTable: SyncEntityTable.fxSessions,
      recordId: sessionId,
      operation: SyncOperation.fxSessionConfirmClose,
      payload: const {},
    );
    return session;
  }

  @override
  Future<FxSession> cancelPendingClose({
    required int shopId,
    required int sessionId,
  }) async {
    final session = await _local.cancelPendingClose(
      shopId: shopId,
      sessionId: sessionId,
    );
    await _recorder?.record(
      shopId: shopId,
      entityTable: SyncEntityTable.fxSessions,
      recordId: sessionId,
      operation: SyncOperation.fxSessionCancelClose,
      payload: const {},
    );
    return session;
  }

  @override
  Future<int> getCustomerRequiredAboveFcfa({required int shopId}) =>
      _local.getCustomerRequiredAboveFcfa(shopId);

  @override
  Future<void> setCustomerRequiredAboveFcfa({
    required int shopId,
    required int amountFcfa,
  }) =>
      _local.setCustomerRequiredAboveFcfa(shopId, amountFcfa);

  @override
  Future<bool> getPrimaryWorkspace({required int shopId}) =>
      _local.getPrimaryWorkspace(shopId);

  @override
  Future<void> setPrimaryWorkspace({
    required int shopId,
    required bool enabled,
  }) =>
      _local.setPrimaryWorkspace(shopId, enabled);

  @override
  Future<FxOperationPreview> previewOperation({
    required int shopId,
    required CreateFxOperationInput input,
    int? sessionId,
  }) =>
      _local.previewOperation(
        shopId: shopId,
        input: input,
        sessionId: sessionId,
      );

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
        'customerId': input.customerId,
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
    final live = session.isActive
        ? await _local.computeLiveBalances(shopId, sessionId)
        : {
            for (final b in session.balances)
              b.currencyCode: b.expectedBalance ?? b.openingBalance,
          };

    final volumeByCurrency = <String, int>{};
    for (final op in operations) {
      volumeByCurrency[op.fromCurrency] =
          (volumeByCurrency[op.fromCurrency] ?? 0) + op.fromAmount;
      volumeByCurrency[op.toCurrency] =
          (volumeByCurrency[op.toCurrency] ?? 0) + op.toAmount;
    }

    return FxDailyReport(
      session: session,
      operations: operations,
      movements: movements,
      liveBalances: live,
      volumeByCurrency: volumeByCurrency,
    );
  }

  @override
  Future<FxPeriodReport> getPeriodReport({
    required int shopId,
    required int fromMs,
    required int toMs,
  }) async {
    final operations = await _local.listOperationsInRange(
      shopId: shopId,
      fromMs: fromMs,
      toMs: toMs,
    );
    final movements = await _local.listMovementsInRange(
      shopId: shopId,
      fromMs: fromMs,
      toMs: toMs,
    );
    final sessionCount = await _local.countSessionsOverlappingRange(
      shopId: shopId,
      fromMs: fromMs,
      toMs: toMs,
    );

    final volumeByCurrency = <String, int>{};
    var totalMargin = 0;
    for (final op in operations) {
      volumeByCurrency[op.fromCurrency] =
          (volumeByCurrency[op.fromCurrency] ?? 0) + op.fromAmount;
      volumeByCurrency[op.toCurrency] =
          (volumeByCurrency[op.toCurrency] ?? 0) + op.toAmount;
      totalMargin += op.marginFcfa;
    }

    return FxPeriodReport(
      fromMs: fromMs,
      toMs: toMs,
      operations: operations,
      movements: movements,
      totalMarginFcfa: totalMargin,
      volumeByCurrency: volumeByCurrency,
      sessionCount: sessionCount,
    );
  }

  static const _syncRemoteTimeout = Duration(seconds: 12);

  @override
  Future<void> syncFromRemote({required int shopId, bool force = false}) async {
    final remote = _remote;
    final guard = _apiGuard;
    final policy = _syncPolicy;
    if (remote == null || guard == null) return;

    final enabledLocally = await _local.isModuleEnabled(shopId);
    if (!enabledLocally) return;

    if (policy != null &&
        !await policy.shouldPullEntity(
          shopId: shopId,
          entity: SyncPullEntity.fxExchange,
          force: force,
        )) {
      return;
    }

    try {
      await guard
          .ensureReady(timeout: _syncRemoteTimeout)
          .timeout(_syncRemoteTimeout);
    } catch (_) {
      return;
    }

    // Ne pas écraser le statut local du module (offline-first).
    try {
      final currencies = await remote
          .fetchCurrencies()
          .timeout(_syncRemoteTimeout);
      final catalog = currencies['catalog'] as List<dynamic>? ?? const [];
      for (final raw in catalog) {
        if (raw is! Map<String, dynamic>) continue;
        final code = raw['code'] as String?;
        if (code == null) continue;
        await _local.upsertCurrencyFromRemote(
          code: code,
          label: raw['label'] as String? ?? code,
          symbol: raw['symbol'] as String? ?? code,
          minorUnit: (raw['minorUnit'] as num?)?.toInt() ??
              (raw['minor_unit'] as num?)?.toInt() ??
              0,
          sortOrder: (raw['sortOrder'] as num?)?.toInt() ??
              (raw['sort_order'] as num?)?.toInt() ??
              0,
        );
      }
      final shopCurrencies = currencies['shopCurrencies'] as List<dynamic>? ??
          currencies['shop_currencies'] as List<dynamic>? ??
          const [];
      for (final raw in shopCurrencies) {
        if (raw is! Map<String, dynamic>) continue;
        final code = raw['currencyCode'] as String? ??
            raw['currency_code'] as String?;
        if (code == null) continue;
        await _local.upsertShopCurrencyFromRemote(
          shopId: shopId,
          currencyCode: code,
          enabled: raw['enabled'] as bool? ?? true,
          sortOrder: (raw['sortOrder'] as num?)?.toInt() ??
              (raw['sort_order'] as num?)?.toInt() ??
              0,
          serverId: raw['id']?.toString(),
        );
      }
    } catch (_) {}

    try {
      final rates =
          await remote.fetchRates().timeout(_syncRemoteTimeout);
      for (final rate in rates) {
        await _local.upsertRateFromRemote(
          shopId: shopId,
          json: {
            'id': rate.id,
            'serverId': '${rate.id}',
            'baseCurrency': rate.baseCurrency,
            'quoteCurrency': rate.quoteCurrency,
            'buyRateNumerator': rate.buyRateNumerator,
            'buyRateDenominator': rate.buyRateDenominator,
            'sellRateNumerator': rate.sellRateNumerator,
            'sellRateDenominator': rate.sellRateDenominator,
            'effectiveAt': rate.effectiveAt,
            'createdBy': rate.createdBy,
            'createdAt': rate.createdAt,
          },
        );
      }
    } catch (_) {}

    try {
      final sessions =
          await remote.fetchSessions().timeout(_syncRemoteTimeout);
      for (final session in sessions) {
        await _local.upsertSessionFromRemote(
          shopId: shopId,
          json: {
            'id': session.id,
            'serverId': '${session.id}',
            'openedBy': session.openedBy,
            'closedBy': session.closedBy,
            'openedAt': session.openedAt,
            'closedAt': session.closedAt,
            'status': session.status,
            'closingNote': session.closingNote,
            'totalMarginFcfa': session.totalMarginFcfa,
            'operationCount': session.operationCount,
            'balances': session.balances
                .map(
                  (b) => {
                    'currencyCode': b.currencyCode,
                    'openingBalance': b.openingBalance,
                    'expectedBalance': b.expectedBalance,
                    'countedBalance': b.countedBalance,
                    'difference': b.difference,
                  },
                )
                .toList(),
            'sessionRates': session.sessionRates
                .map(
                  (r) => {
                    'id': r.id,
                    'quoteCurrency': r.quoteCurrency,
                    'rateSnapshotId': r.rateSnapshotId,
                    'appliedAt': r.appliedAt,
                  },
                )
                .toList(),
          },
        );
      }
    } catch (_) {}

    try {
      final openState =
          await remote.fetchOpenSession().timeout(_syncRemoteTimeout);
      final open = openState.session;
      if (open != null) {
        await _local.upsertSessionFromRemote(
          shopId: shopId,
          json: {
            'id': open.id,
            'serverId': '${open.id}',
            'openedBy': open.openedBy,
            'closedBy': open.closedBy,
            'openedAt': open.openedAt,
            'closedAt': open.closedAt,
            'status': open.status,
            'closingNote': open.closingNote,
            'totalMarginFcfa': open.totalMarginFcfa,
            'operationCount': open.operationCount,
            'balances': open.balances
                .map(
                  (b) => {
                    'currencyCode': b.currencyCode,
                    'openingBalance': b.openingBalance,
                    'expectedBalance': b.expectedBalance,
                    'countedBalance': b.countedBalance,
                    'difference': b.difference,
                  },
                )
                .toList(),
            'sessionRates': open.sessionRates
                .map(
                  (r) => {
                    'id': r.id,
                    'quoteCurrency': r.quoteCurrency,
                    'rateSnapshotId': r.rateSnapshotId,
                    'appliedAt': r.appliedAt,
                  },
                )
                .toList(),
          },
        );
      }
    } catch (_) {}

    try {
      final operations =
          await remote.fetchOperations().timeout(_syncRemoteTimeout);
      for (final op in operations) {
        final localSessionId = await _local.findLocalSessionIdByServerId(
          shopId,
          '${op.sessionId}',
        );
        if (localSessionId == null) continue;
        int? localRateId;
        if (op.rateSnapshotId != null) {
          localRateId = await _local.findLocalRateIdByServerId(
            shopId,
            '${op.rateSnapshotId}',
          );
        }
        int? localCustomerId;
        if (op.customerId != null) {
          localCustomerId = await _local.findLocalCustomerIdByServerId(
            shopId,
            '${op.customerId}',
          );
        }
        await _local.upsertOperationFromRemote(
          shopId: shopId,
          localSessionId: localSessionId,
          localRateSnapshotId: localRateId,
          json: {
            'id': op.id,
            'serverId': '${op.id}',
            'operationType': op.operationType,
            'fromCurrency': op.fromCurrency,
            'fromAmount': op.fromAmount,
            'toCurrency': op.toCurrency,
            'toAmount': op.toAmount,
            'marginFcfa': op.marginFcfa,
            'localCustomerId': localCustomerId,
            'note': op.note,
            'createdBy': op.createdBy,
            'createdAt': op.createdAt,
          },
        );
      }
    } catch (_) {}

    try {
      final movements =
          await remote.fetchMovements().timeout(_syncRemoteTimeout);
      for (final mv in movements) {
        final localSessionId = await _local.findLocalSessionIdByServerId(
          shopId,
          '${mv.sessionId}',
        );
        if (localSessionId == null) continue;
        await _local.upsertMovementFromRemote(
          shopId: shopId,
          localSessionId: localSessionId,
          json: {
            'id': mv.id,
            'serverId': '${mv.id}',
            'currencyCode': mv.currencyCode,
            'movementType': mv.movementType,
            'amount': mv.amount,
            'note': mv.note,
            'createdBy': mv.createdBy,
            'createdAt': mv.createdAt,
          },
        );
      }
    } catch (_) {}

    await policy?.markEntitySynced(
      shopId: shopId,
      entity: SyncPullEntity.fxExchange,
    );
  }
}
