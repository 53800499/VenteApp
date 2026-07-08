import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart' as db;
import '../../../../../core/errors/failures.dart';
import '../../../../../core/utils/time.dart';
import '../../../domain/entities/cash_session_entities.dart';

class CashSessionsLocalDatasource {
  CashSessionsLocalDatasource(this._db);

  final db.AppDatabase _db;

  Future<CashSession?> findOpenSession(int shopId) async {
    final row = await (_db.select(_db.cashSessions)
          ..where(
            (s) => s.shopId.equals(shopId) & s.status.equals('open'),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.openedAt)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return _mapSession(row);
  }

  Future<List<CashSessionListRow>> listSessions({
    required int shopId,
    int limit = 50,
  }) async {
    final rows = await (_db.select(_db.cashSessions)
          ..where((s) => s.shopId.equals(shopId))
          ..orderBy([(s) => OrderingTerm.desc(s.openedAt)])
          ..limit(limit))
        .get();

    final result = <CashSessionListRow>[];
    for (final row in rows) {
      final opener = await _userName(row.openedBy);
      result.add(
        CashSessionListRow(
          id: row.id,
          openedAt: row.openedAt,
          closedAt: row.closedAt,
          openedByName: opener,
          status: CashSessionStatus.fromCode(row.status),
          differenceCash: row.differenceCash ?? 0,
          differenceMomo: row.differenceMomo ?? 0,
          saleCount: row.saleCount,
        ),
      );
    }
    return result;
  }

  Future<CashSession> getSession(int shopId, int sessionId) async {
    final row = await (_db.select(_db.cashSessions)
          ..where(
            (s) => s.shopId.equals(shopId) & s.id.equals(sessionId),
          ))
        .getSingleOrNull();
    if (row == null) {
      throw const NotFoundFailure('Session introuvable.');
    }
    return _mapSession(row);
  }

  Future<CashSessionLiveTotals> computeLiveTotals({
    required int shopId,
    required int openedAt,
    int? closedAt,
    required int sessionId,
  }) async {
    final toMs = closedAt ?? nowMs();

    final sales = await (_db.select(_db.sales)
          ..where(
            (s) =>
                s.shopId.equals(shopId) &
                s.status.equals('completed') &
                s.createdAt.isBiggerOrEqualValue(openedAt) &
                s.createdAt.isSmallerOrEqualValue(toMs),
          ))
        .get();

    var salesCash = 0;
    var salesMomo = 0;
    for (final sale in sales) {
      salesCash += sale.amountCash;
      salesMomo += sale.amountMomo;
    }

    const cashMethods = ['cash'];
    const momoMethods = ['mtn_momo', 'moov_money'];

    final expenses = await (_db.select(_db.expenses)
          ..where(
            (e) =>
                e.shopId.equals(shopId) &
                e.deletedAt.isNull() &
                e.status.equals('validated') &
                e.expenseDate.isBiggerOrEqualValue(openedAt) &
                e.expenseDate.isSmallerOrEqualValue(toMs),
          ))
        .get();

    var expensesCash = 0;
    var expensesMomo = 0;
    for (final expense in expenses) {
      if (cashMethods.contains(expense.paymentMethod)) {
        expensesCash += expense.amount;
      } else if (momoMethods.contains(expense.paymentMethod)) {
        expensesMomo += expense.amount;
      }
    }

    final movements = await (_db.select(_db.cashMovements)
          ..where((m) => m.shopId.equals(shopId) & m.sessionId.equals(sessionId)))
        .get();

    var depositsCash = 0;
    var depositsMomo = 0;
    var withdrawalsCash = 0;
    var withdrawalsMomo = 0;
    for (final movement in movements) {
      final isCash = movement.registerType == 'cash';
      final isDeposit = movement.movementType == 'deposit';
      if (isCash) {
        if (isDeposit) {
          depositsCash += movement.amount;
        } else {
          withdrawalsCash += movement.amount;
        }
      } else {
        if (isDeposit) {
          depositsMomo += movement.amount;
        } else {
          withdrawalsMomo += movement.amount;
        }
      }
    }

    return CashSessionLiveTotals(
      salesCash: salesCash,
      salesMomo: salesMomo,
      expensesCash: expensesCash,
      expensesMomo: expensesMomo,
      depositsCash: depositsCash,
      depositsMomo: depositsMomo,
      withdrawalsCash: withdrawalsCash,
      withdrawalsMomo: withdrawalsMomo,
      saleCount: sales.length,
    );
  }

  Future<List<CashMovement>> listMovements(int shopId, int sessionId) async {
    final rows = await (_db.select(_db.cashMovements)
          ..where(
            (m) => m.shopId.equals(shopId) & m.sessionId.equals(sessionId),
          )
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .get();

    final result = <CashMovement>[];
    for (final row in rows) {
      result.add(
        CashMovement(
          id: row.id,
          shopId: row.shopId,
          sessionId: row.sessionId,
          movementType: CashMovementType.fromCode(row.movementType),
          registerType: CashRegisterType.fromCode(row.registerType),
          amount: row.amount,
          note: row.note,
          createdBy: row.createdBy,
          createdByName: await _userName(row.createdBy),
          createdAt: row.createdAt,
        ),
      );
    }
    return result;
  }

  Future<CashSession> openSession({
    required int shopId,
    required int userId,
    required OpenCashSessionInput input,
  }) async {
    final existing = await findOpenSession(shopId);
    if (existing != null) {
      throw const ConflictFailure('Une session de caisse est déjà ouverte.');
    }

    final timestamp = nowMs();
    final id = await _db.into(_db.cashSessions).insert(
          db.CashSessionsCompanion.insert(
            shopId: shopId,
            openedBy: userId,
            openedAt: timestamp,
            openingCash: Value(input.openingCash),
            openingMomo: Value(input.openingMomo),
            createdAt: timestamp,
            updatedAt: timestamp,
            syncStatus: const Value('pending'),
          ),
        );
    return getSession(shopId, id);
  }

  Future<CashSession> closeSession({
    required int shopId,
    required int userId,
    required int sessionId,
    required CloseCashSessionInput input,
    required CashSessionLiveTotals totals,
    required int expectedCash,
    required int expectedMomo,
    required int differenceCash,
    required int differenceMomo,
  }) async {
    final timestamp = nowMs();
    await (_db.update(_db.cashSessions)
          ..where((s) => s.shopId.equals(shopId) & s.id.equals(sessionId)))
        .write(
      db.CashSessionsCompanion(
        closedBy: Value(userId),
        closedAt: Value(timestamp),
        salesCash: Value(totals.salesCash),
        salesMomo: Value(totals.salesMomo),
        expensesCash: Value(totals.expensesCash),
        expensesMomo: Value(totals.expensesMomo),
        depositsCash: Value(totals.depositsCash),
        depositsMomo: Value(totals.depositsMomo),
        withdrawalsCash: Value(totals.withdrawalsCash),
        withdrawalsMomo: Value(totals.withdrawalsMomo),
        expectedCash: Value(expectedCash),
        expectedMomo: Value(expectedMomo),
        countedCash: Value(input.countedCash),
        countedMomo: Value(input.countedMomo),
        differenceCash: Value(differenceCash),
        differenceMomo: Value(differenceMomo),
        saleCount: Value(totals.saleCount),
        status: const Value('closed'),
        closingNote: Value(input.closingNote),
        updatedAt: Value(timestamp),
        syncStatus: const Value('pending'),
        version: const Value(2),
      ),
    );
    return getSession(shopId, sessionId);
  }

  Future<CashMovement> recordMovement({
    required int shopId,
    required int userId,
    required int sessionId,
    required RecordCashMovementInput input,
  }) async {
    final session = await getSession(shopId, sessionId);
    if (!session.isOpen) {
      throw const ConflictFailure('Cette session est déjà clôturée.');
    }

    final timestamp = nowMs();
    final id = await _db.into(_db.cashMovements).insert(
          db.CashMovementsCompanion.insert(
            shopId: shopId,
            sessionId: sessionId,
            movementType: input.movementType.code,
            registerType: Value(input.registerType.code),
            amount: input.amount,
            note: Value(input.note),
            createdBy: userId,
            createdAt: timestamp,
            syncStatus: const Value('pending'),
          ),
        );

    final rows = await (_db.select(_db.cashMovements)
          ..where((m) => m.id.equals(id)))
        .getSingle();
    return CashMovement(
      id: rows.id,
      shopId: rows.shopId,
      sessionId: rows.sessionId,
      movementType: CashMovementType.fromCode(rows.movementType),
      registerType: CashRegisterType.fromCode(rows.registerType),
      amount: rows.amount,
      note: rows.note,
      createdBy: rows.createdBy,
      createdByName: await _userName(rows.createdBy),
      createdAt: rows.createdAt,
    );
  }

  Future<String?> findSessionServerId(int shopId, int sessionId) async {
    final row = await (_db.select(_db.cashSessions)
          ..where((s) => s.shopId.equals(shopId) & s.id.equals(sessionId)))
        .getSingleOrNull();
    return row?.serverId;
  }

  Future<void> updateSessionServerSync({
    required int sessionId,
    required String serverId,
  }) async {
    await (_db.update(_db.cashSessions)..where((s) => s.id.equals(sessionId)))
        .write(
      db.CashSessionsCompanion(
        serverId: Value(serverId),
        syncedAt: Value(nowMs()),
        syncStatus: const Value('synced'),
      ),
    );
  }

  Future<CashSession?> findSessionForSync(int shopId, int sessionId) async {
    try {
      return await getSession(shopId, sessionId);
    } catch (_) {
      return null;
    }
  }

  Future<CashMovement?> findMovementForSync(int shopId, int movementId) async {
    final row = await (_db.select(_db.cashMovements)
          ..where(
            (m) => m.shopId.equals(shopId) & m.id.equals(movementId),
          ))
        .getSingleOrNull();
    if (row == null) return null;
    return CashMovement(
      id: row.id,
      shopId: row.shopId,
      sessionId: row.sessionId,
      movementType: CashMovementType.fromCode(row.movementType),
      registerType: CashRegisterType.fromCode(row.registerType),
      amount: row.amount,
      note: row.note,
      createdBy: row.createdBy,
      createdByName: await _userName(row.createdBy),
      createdAt: row.createdAt,
    );
  }

  Future<String?> findMovementServerId(int shopId, int movementId) async {
    final row = await (_db.select(_db.cashMovements)
          ..where(
            (m) => m.shopId.equals(shopId) & m.id.equals(movementId),
          ))
        .getSingleOrNull();
    return row?.serverId;
  }

  Future<void> updateMovementServerSync({
    required int movementId,
    required String serverId,
  }) async {
    await (_db.update(_db.cashMovements)..where((m) => m.id.equals(movementId)))
        .write(
      db.CashMovementsCompanion(
        serverId: Value(serverId),
        syncedAt: Value(nowMs()),
        syncStatus: const Value('synced'),
      ),
    );
  }

  Future<void> upsertMovementFromRemote({
    required int shopId,
    required int localSessionId,
    required Map<String, dynamic> json,
  }) async {
    final serverId = json['serverId']?.toString() ?? json['id']?.toString();
    if (serverId == null) return;

    final existing = await (_db.select(_db.cashMovements)
          ..where(
            (m) => m.shopId.equals(shopId) & m.serverId.equals(serverId),
          ))
        .getSingleOrNull();

    final companion = db.CashMovementsCompanion(
      shopId: Value(shopId),
      sessionId: Value(localSessionId),
      movementType: Value(
        json['movementType'] as String? ??
            json['movement_type'] as String? ??
            'deposit',
      ),
      registerType: Value(
        json['registerType'] as String? ??
            json['register_type'] as String? ??
            'cash',
      ),
      amount: Value((json['amount'] as num).toInt()),
      note: Value(json['note'] as String?),
      createdBy: Value((json['createdBy'] as num?)?.toInt() ?? 1),
      createdAt: Value((json['createdAt'] as num?)?.toInt() ?? nowMs()),
      serverId: Value(serverId),
      syncedAt: Value(nowMs()),
      syncStatus: const Value('synced'),
    );

    if (existing == null) {
      await _db.into(_db.cashMovements).insert(companion);
    } else {
      await (_db.update(_db.cashMovements)
            ..where((m) => m.id.equals(existing.id)))
          .write(companion);
    }
  }

  Future<int?> findLocalSessionIdByServerId(int shopId, String serverSessionId) async {
    final rows = await (_db.select(_db.cashSessions)
          ..where(
            (s) => s.shopId.equals(shopId) & s.serverId.equals(serverSessionId),
          ))
        .get();
    final row = rows.isEmpty ? null : rows.first;
    return row?.id;
  }

  Future<void> upsertFromRemote({
    required int shopId,
    required Map<String, dynamic> json,
  }) async {
    final serverId = json['serverId']?.toString() ?? json['id']?.toString();
    if (serverId == null) return;

    final existingRows = await (_db.select(_db.cashSessions)
          ..where(
            (s) => s.shopId.equals(shopId) & s.serverId.equals(serverId),
          ))
        .get();
    final existing = existingRows.isEmpty ? null : existingRows.first;

    final companion = db.CashSessionsCompanion(
      shopId: Value(shopId),
      openedBy: Value(json['openedBy'] as int? ?? 1),
      closedBy: Value(json['closedBy'] as int?),
      openedAt: Value((json['openedAt'] as num).toInt()),
      closedAt: Value((json['closedAt'] as num?)?.toInt()),
      openingCash: Value((json['openingCash'] as num?)?.toInt() ?? 0),
      openingMomo: Value((json['openingMomo'] as num?)?.toInt() ?? 0),
      salesCash: Value((json['salesCash'] as num?)?.toInt() ?? 0),
      salesMomo: Value((json['salesMomo'] as num?)?.toInt() ?? 0),
      expensesCash: Value((json['expensesCash'] as num?)?.toInt() ?? 0),
      expensesMomo: Value((json['expensesMomo'] as num?)?.toInt() ?? 0),
      depositsCash: Value((json['depositsCash'] as num?)?.toInt() ?? 0),
      depositsMomo: Value((json['depositsMomo'] as num?)?.toInt() ?? 0),
      withdrawalsCash: Value((json['withdrawalsCash'] as num?)?.toInt() ?? 0),
      withdrawalsMomo: Value((json['withdrawalsMomo'] as num?)?.toInt() ?? 0),
      expectedCash: Value((json['expectedCash'] as num?)?.toInt()),
      expectedMomo: Value((json['expectedMomo'] as num?)?.toInt()),
      countedCash: Value((json['countedCash'] as num?)?.toInt()),
      countedMomo: Value((json['countedMomo'] as num?)?.toInt()),
      differenceCash: Value((json['differenceCash'] as num?)?.toInt()),
      differenceMomo: Value((json['differenceMomo'] as num?)?.toInt()),
      saleCount: Value((json['saleCount'] as num?)?.toInt() ?? 0),
      status: Value(json['status'] as String? ?? 'closed'),
      closingNote: Value(json['closingNote'] as String?),
      createdAt: Value((json['createdAt'] as num).toInt()),
      updatedAt: Value((json['updatedAt'] as num).toInt()),
      serverId: Value(serverId),
      syncedAt: Value(nowMs()),
      syncStatus: const Value('synced'),
    );

    if (existing == null) {
      await _db.into(_db.cashSessions).insert(companion);
    } else {
      await (_db.update(_db.cashSessions)
            ..where((s) => s.id.equals(existing.id)))
          .write(companion);
      if (existingRows.length > 1) {
        final duplicateIds = existingRows.skip(1).map((s) => s.id).toList();
        await (_db.delete(_db.cashSessions)..where((s) => s.id.isIn(duplicateIds))).go();
      }
    }
  }

  Future<CashSession> _mapSession(db.CashSession row) async {
    return CashSession(
      id: row.id,
      shopId: row.shopId,
      openedBy: row.openedBy,
      openedByName: await _userName(row.openedBy),
      closedBy: row.closedBy,
      closedByName:
          row.closedBy != null ? await _userName(row.closedBy!) : null,
      openedAt: row.openedAt,
      closedAt: row.closedAt,
      openingCash: row.openingCash,
      openingMomo: row.openingMomo,
      salesCash: row.salesCash,
      salesMomo: row.salesMomo,
      expensesCash: row.expensesCash,
      expensesMomo: row.expensesMomo,
      depositsCash: row.depositsCash,
      depositsMomo: row.depositsMomo,
      withdrawalsCash: row.withdrawalsCash,
      withdrawalsMomo: row.withdrawalsMomo,
      expectedCash: row.expectedCash,
      expectedMomo: row.expectedMomo,
      countedCash: row.countedCash,
      countedMomo: row.countedMomo,
      differenceCash: row.differenceCash,
      differenceMomo: row.differenceMomo,
      saleCount: row.saleCount,
      status: CashSessionStatus.fromCode(row.status),
      closingNote: row.closingNote,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Future<String> _userName(int userId) async {
    final user = await (_db.select(_db.users)..where((u) => u.id.equals(userId)))
        .getSingleOrNull();
    return user?.name ?? 'Utilisateur #$userId';
  }
}
