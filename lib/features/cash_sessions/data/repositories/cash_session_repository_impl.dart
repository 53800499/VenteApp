import '../../../../core/errors/failures.dart';
import '../../../../core/network/remote_api_guard.dart';
import '../../../../core/sync/local_write_sync_recorder.dart';
import '../../domain/entities/cash_session_entities.dart';
import '../../domain/repositories/cash_session_repository.dart';
import '../../domain/services/cash_session_aggregation_service.dart';
import '../datasources/local/cash_sessions_local_datasource.dart';
import '../datasources/remote/cash_sessions_remote_datasource.dart';
import '../models/cash_session_api_models.dart';

class CashSessionRepositoryImpl implements CashSessionRepository {
  CashSessionRepositoryImpl({
    required CashSessionsLocalDatasource local,
    CashSessionsRemoteDatasource? remote,
    RemoteApiGuard? apiGuard,
    CashSessionAggregationService? aggregation,
    LocalWriteSyncRecorder? recorder,
  })  : _local = local,
        _remote = remote,
        _apiGuard = apiGuard,
        _aggregation = aggregation ?? const CashSessionAggregationService(),
        _recorder = recorder;

  final CashSessionsLocalDatasource _local;
  final CashSessionsRemoteDatasource? _remote;
  final RemoteApiGuard? _apiGuard;
  final CashSessionAggregationService _aggregation;
  final LocalWriteSyncRecorder? _recorder;

  @override
  Future<CashSession?> findOpenSession({required int shopId}) =>
      _local.findOpenSession(shopId);

  @override
  Future<List<CashSessionListRow>> listSessions({
    required int shopId,
    int limit = 50,
  }) =>
      _local.listSessions(shopId: shopId, limit: limit);

  @override
  Future<CashSession> getSession({
    required int shopId,
    required int sessionId,
  }) =>
      _local.getSession(shopId, sessionId);

  @override
  Future<CashSessionLiveTotals> getLiveTotals({
    required int shopId,
    required int sessionId,
    required int openedAt,
    int? closedAt,
  }) =>
      _local.computeLiveTotals(
        shopId: shopId,
        sessionId: sessionId,
        openedAt: openedAt,
        closedAt: closedAt,
      );

  @override
  Future<List<CashMovement>> listMovements({
    required int shopId,
    required int sessionId,
  }) =>
      _local.listMovements(shopId, sessionId);

  @override
  Future<CashSession> openSession({
    required int shopId,
    required int userId,
    required OpenCashSessionInput input,
  }) async {
    if (input.openingCash < 0 || input.openingMomo < 0) {
      throw const ValidationFailure('Le fond de caisse ne peut pas être négatif.');
    }

    final session = await _local.openSession(
      shopId: shopId,
      userId: userId,
      input: input,
    );
    await _recorder?.recordCashSessionOpen(
      shopId: shopId,
      sessionId: session.id,
    );
    return session;
  }

  @override
  Future<CashSession> closeSession({
    required int shopId,
    required int userId,
    required int sessionId,
    required CloseCashSessionInput input,
  }) async {
    final session = await _local.getSession(shopId, sessionId);
    if (!session.isOpen) {
      throw const ConflictFailure('Cette session est déjà clôturée.');
    }

    final totals = await _local.computeLiveTotals(
      shopId: shopId,
      sessionId: sessionId,
      openedAt: session.openedAt,
    );

    final expectedCash = _aggregation.expectedCash(
      openingCash: session.openingCash,
      salesCash: totals.salesCash,
      depositsCash: totals.depositsCash,
      expensesCash: totals.expensesCash,
      withdrawalsCash: totals.withdrawalsCash,
    );
    final expectedMomo = _aggregation.expectedMomo(
      openingMomo: session.openingMomo,
      salesMomo: totals.salesMomo,
      depositsMomo: totals.depositsMomo,
      expensesMomo: totals.expensesMomo,
      withdrawalsMomo: totals.withdrawalsMomo,
    );

    final differenceCash =
        _aggregation.difference(input.countedCash, expectedCash);
    final differenceMomo =
        _aggregation.difference(input.countedMomo, expectedMomo);

    final closed = await _local.closeSession(
      shopId: shopId,
      userId: userId,
      sessionId: sessionId,
      input: input,
      totals: totals,
      expectedCash: expectedCash,
      expectedMomo: expectedMomo,
      differenceCash: differenceCash,
      differenceMomo: differenceMomo,
    );

    await _recorder?.recordCashSessionClose(
      shopId: shopId,
      sessionId: sessionId,
      payload: CloseCashSessionApiRequest(
        countedCash: input.countedCash,
        countedMomo: input.countedMomo,
        closingNote: input.closingNote,
        ownerPin: input.ownerPin,
        salesCash: totals.salesCash,
        salesMomo: totals.salesMomo,
        expensesCash: totals.expensesCash,
        expensesMomo: totals.expensesMomo,
        depositsCash: totals.depositsCash,
        depositsMomo: totals.depositsMomo,
        withdrawalsCash: totals.withdrawalsCash,
        withdrawalsMomo: totals.withdrawalsMomo,
        saleCount: totals.saleCount,
      ).toJson(),
    );
    return closed;
  }

  @override
  Future<CashMovement> recordMovement({
    required int shopId,
    required int userId,
    required int sessionId,
    required RecordCashMovementInput input,
  }) async {
    if (input.amount <= 0) {
      throw const ValidationFailure('Le montant doit être positif.');
    }
    final movement = await _local.recordMovement(
      shopId: shopId,
      userId: userId,
      sessionId: sessionId,
      input: input,
    );
    await _recorder?.recordCashMovement(
      shopId: shopId,
      movementId: movement.id,
      payload: CreateCashMovementApiRequest(
        movementType: input.movementType.code,
        registerType: input.registerType.code,
        amount: input.amount,
        note: input.note,
      ).toJson(),
    );
    return movement;
  }

  @override
  Future<void> syncFromRemote({required int shopId}) async {
    if (_remote == null || _apiGuard == null) return;
    try {
      await _apiGuard.ensureReady();
      final remote = await _remote.fetchSessions();
      for (final dto in remote) {
        await _local.upsertFromRemote(
          shopId: shopId,
          json: {
            ...dto.toJson(),
            'id': dto.id,
            'serverId': dto.serverId ?? '${dto.id}',
            'openedBy': dto.openedBy,
            'closedBy': dto.closedBy,
          },
        );
      }
      final movements = await _remote.fetchMovements();
      for (final dto in movements) {
        final localSessionId = await _local.findLocalSessionIdByServerId(
          shopId,
          '${dto.sessionId}',
        );
        if (localSessionId == null) continue;
        await _local.upsertMovementFromRemote(
          shopId: shopId,
          localSessionId: localSessionId,
          json: {
            ...dto.toJson(),
            'serverId': '${dto.id}',
          },
        );
      }
    } on Failure {
      // Offline-first
    } catch (_) {}
  }
}
