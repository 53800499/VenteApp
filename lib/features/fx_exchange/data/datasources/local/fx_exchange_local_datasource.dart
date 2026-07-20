import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart' as db;
import '../../../../../core/errors/failures.dart';
import '../../../../../core/utils/time.dart';
import '../../../domain/entities/fx_exchange_entities.dart';
import '../../../domain/services/fx_calculation_service.dart';

class FxExchangeLocalDatasource {
  FxExchangeLocalDatasource(this._db);

  final db.AppDatabase _db;
  static final _calc = FxCalculationService();

  Future<bool> isModuleEnabled(int shopId) async {
    final row = await (_db.select(_db.tenantModules)
          ..where(
            (m) =>
                m.shopId.equals(shopId) & m.moduleCode.equals(fxModuleCode),
          ))
        .getSingleOrNull();
    return row?.enabled ?? false;
  }

  Future<void> saveModuleStatus(int shopId, bool enabled) async {
    final timestamp = nowMs();
    final existing = await (_db.select(_db.tenantModules)
          ..where(
            (m) =>
                m.shopId.equals(shopId) & m.moduleCode.equals(fxModuleCode),
          ))
        .getSingleOrNull();

    if (existing == null) {
      await _db.into(_db.tenantModules).insert(
            db.TenantModulesCompanion.insert(
              shopId: shopId,
              moduleCode: fxModuleCode,
              enabled: Value(enabled),
              createdAt: timestamp,
            ),
          );
    } else {
      await (_db.update(_db.tenantModules)
            ..where((m) => m.id.equals(existing.id)))
          .write(db.TenantModulesCompanion(enabled: Value(enabled)));
    }

    if (enabled) {
      await _ensureDefaultShopCurrencies(shopId);
    }
  }

  Future<List<FxCurrency>> listCurrencies() async {
    var rows = await (_db.select(_db.fxCurrencies)
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();

    // Auto-réparation si le seed n'a pas tourné (ex. createAll sans seed).
    if (rows.isEmpty) {
      await db.seedFxCurrencies(_db);
      rows = await (_db.select(_db.fxCurrencies)
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .get();
    }

    return rows
        .map(
          (r) => FxCurrency(
            code: r.code,
            label: r.label,
            symbol: r.symbol,
            minorUnit: r.minorUnit,
            sortOrder: r.sortOrder,
          ),
        )
        .toList();
  }

  Future<List<FxShopCurrency>> listShopCurrencies(int shopId) async {
    var rows = await (_db.select(_db.fxShopCurrencies)
          ..where((c) => c.shopId.equals(shopId))
          ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
        .get();

    if (rows.isEmpty) {
      await _ensureDefaultShopCurrencies(shopId);
      rows = await (_db.select(_db.fxShopCurrencies)
            ..where((c) => c.shopId.equals(shopId))
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder)]))
          .get();
    }

    return rows
        .map(
          (r) => FxShopCurrency(
            id: r.id,
            shopId: r.shopId,
            currencyCode: r.currencyCode,
            enabled: r.enabled,
            sortOrder: r.sortOrder,
          ),
        )
        .toList();
  }

  Future<List<FxShopCurrency>> upsertShopCurrencies(
    int shopId,
    List<UpsertFxShopCurrencyInput> items,
  ) async {
    final hasXof = items.any(
      (i) => i.currencyCode == fxBaseCurrency && i.enabled,
    );
    if (!hasXof) {
      throw const ValidationFailure('La devise FCFA (XOF) doit rester active.');
    }

    final foreignEnabled = items.where(
      (i) => i.currencyCode != fxBaseCurrency && i.enabled,
    );
    if (foreignEnabled.isEmpty) {
      throw const ValidationFailure(
        'Au moins une devise étrangère doit être active.',
      );
    }

    final timestamp = nowMs();
    for (final item in items) {
      final existing = await (_db.select(_db.fxShopCurrencies)
            ..where(
              (c) =>
                  c.shopId.equals(shopId) &
                  c.currencyCode.equals(item.currencyCode),
            ))
          .getSingleOrNull();

      if (existing == null) {
        await _db.into(_db.fxShopCurrencies).insert(
              db.FxShopCurrenciesCompanion.insert(
                shopId: shopId,
                currencyCode: item.currencyCode,
                enabled: Value(item.enabled),
                sortOrder: Value(item.sortOrder),
                createdAt: timestamp,
                updatedAt: timestamp,
              ),
            );
      } else {
        await (_db.update(_db.fxShopCurrencies)
              ..where((c) => c.id.equals(existing.id)))
            .write(
          db.FxShopCurrenciesCompanion(
            enabled: Value(item.enabled),
            sortOrder: Value(item.sortOrder),
            updatedAt: Value(timestamp),
          ),
        );
      }
    }

    return listShopCurrencies(shopId);
  }

  Future<FxRateSnapshot> createRate({
    required int shopId,
    required int userId,
    required CreateFxRateInput input,
  }) async {
    if (input.quoteCurrency == fxBaseCurrency) {
      throw const ValidationFailure('Impossible de définir un taux pour FCFA.');
    }

    final timestamp = nowMs();
    final id = await _db.into(_db.fxRateSnapshots).insert(
          db.FxRateSnapshotsCompanion.insert(
            shopId: shopId,
            quoteCurrency: input.quoteCurrency,
            buyRateNumerator: input.buyRateNumerator,
            buyRateDenominator: input.buyRateDenominator,
            sellRateNumerator: input.sellRateNumerator,
            sellRateDenominator: input.sellRateDenominator,
            effectiveAt: timestamp,
            createdBy: userId,
            createdAt: timestamp,
            syncStatus: const Value('pending'),
          ),
        );

    return (await findRateById(shopId, id))!;
  }

  Future<FxRateSnapshot?> findRateById(int shopId, int id) async {
    final row = await (_db.select(_db.fxRateSnapshots)
          ..where((r) => r.shopId.equals(shopId) & r.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _mapRate(row);
  }

  Future<FxRateSnapshot?> findLatestRate(int shopId, String quoteCurrency) async {
    final row = await (_db.select(_db.fxRateSnapshots)
          ..where(
            (r) =>
                r.shopId.equals(shopId) &
                r.quoteCurrency.equals(quoteCurrency),
          )
          ..orderBy([(r) => OrderingTerm.desc(r.effectiveAt)])
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _mapRate(row);
  }

  Future<List<FxRateSnapshot>> listLatestRates(int shopId) async {
    final shopCurrencies = await listShopCurrencies(shopId);
    final quotes = shopCurrencies
        .where((c) => c.enabled && c.currencyCode != fxBaseCurrency)
        .map((c) => c.currencyCode);

    final latest = <FxRateSnapshot>[];
    for (final quote in quotes) {
      final rate = await findLatestRate(shopId, quote);
      if (rate != null) latest.add(rate);
    }
    return latest;
  }

  Future<List<FxRateSnapshot>> listRateHistory({
    required int shopId,
    String? quoteCurrency,
    int limit = 100,
  }) async {
    var query = _db.select(_db.fxRateSnapshots)
      ..where((r) => r.shopId.equals(shopId))
      ..orderBy([(r) => OrderingTerm.desc(r.effectiveAt)])
      ..limit(limit);

    if (quoteCurrency != null) {
      query = _db.select(_db.fxRateSnapshots)
        ..where(
          (r) =>
              r.shopId.equals(shopId) &
              r.quoteCurrency.equals(quoteCurrency),
        )
        ..orderBy([(r) => OrderingTerm.desc(r.effectiveAt)])
        ..limit(limit);
    }

    final rows = await query.get();
    return rows.map(_mapRate).toList();
  }

  Future<FxSession?> findOpenSession(int shopId) async {
    final row = await (_db.select(_db.fxSessions)
          ..where(
            (s) => s.shopId.equals(shopId) & s.status.equals('open'),
          )
          ..orderBy([(s) => OrderingTerm.desc(s.openedAt)])
          ..limit(1))
        .getSingleOrNull();
    if (row == null) return null;
    return _mapSession(row);
  }

  Future<List<FxSessionListRow>> listSessions({
    required int shopId,
    int limit = 50,
  }) async {
    final rows = await (_db.select(_db.fxSessions)
          ..where((s) => s.shopId.equals(shopId))
          ..orderBy([(s) => OrderingTerm.desc(s.openedAt)])
          ..limit(limit))
        .get();

    final result = <FxSessionListRow>[];
    for (final row in rows) {
      result.add(
        FxSessionListRow(
          id: row.id,
          openedAt: row.openedAt,
          closedAt: row.closedAt,
          openedByName: await _userName(row.openedBy),
          status: FxSessionStatus.fromCode(row.status),
          totalMarginFcfa: row.totalMarginFcfa,
          operationCount: row.operationCount,
        ),
      );
    }
    return result;
  }

  Future<FxSession> getSession(int shopId, int sessionId) async {
    final row = await (_db.select(_db.fxSessions)
          ..where(
            (s) => s.shopId.equals(shopId) & s.id.equals(sessionId),
          ))
        .getSingleOrNull();
    if (row == null) {
      throw const NotFoundFailure('Session FX introuvable.');
    }
    return _mapSession(row);
  }

  Future<Map<String, int>> computeLiveBalances(
    int shopId,
    int sessionId,
  ) async {
    final session = await getSession(shopId, sessionId);
    final balances = <String, int>{
      for (final b in session.balances) b.currencyCode: b.openingBalance,
    };

    final operations = await (_db.select(_db.fxOperations)
          ..where(
            (o) => o.shopId.equals(shopId) & o.sessionId.equals(sessionId),
          ))
        .get();

    for (final op in operations) {
      balances[op.fromCurrency] =
          (balances[op.fromCurrency] ?? 0) + op.fromAmount;
      balances[op.toCurrency] =
          (balances[op.toCurrency] ?? 0) - op.toAmount;
    }

    final movements = await (_db.select(_db.fxMovements)
          ..where(
            (m) => m.shopId.equals(shopId) & m.sessionId.equals(sessionId),
          ))
        .get();

    for (final mv in movements) {
      final sign = mv.movementType == 'withdrawal' ? -1 : 1;
      balances[mv.currencyCode] =
          (balances[mv.currencyCode] ?? 0) + sign * mv.amount;
    }

    return balances;
  }

  Future<FxSession> openSession({
    required int shopId,
    required int userId,
    required OpenFxSessionInput input,
  }) async {
    final existing = await findOpenSession(shopId);
    if (existing != null) {
      throw const ConflictFailure('Une session FX est déjà ouverte.');
    }

    final shopCurrencies = await listShopCurrencies(shopId);
    final enabledCodes = shopCurrencies
        .where((c) => c.enabled)
        .map((c) => c.currencyCode)
        .toList();
    final foreignEnabled =
        enabledCodes.where((c) => c != fxBaseCurrency).toList();

    final rates = await listLatestRates(shopId);
    if (rates.length < foreignEnabled.length) {
      throw const ValidationFailure(
        'Les taux du jour doivent être définis pour toutes les devises actives.',
      );
    }

    final timestamp = nowMs();
    final sessionId = await _db.into(_db.fxSessions).insert(
          db.FxSessionsCompanion.insert(
            shopId: shopId,
            openedBy: userId,
            openedAt: timestamp,
            status: const Value('open'),
            createdAt: timestamp,
            updatedAt: timestamp,
            syncStatus: const Value('pending'),
          ),
        );

    for (final code in enabledCodes) {
      final amount = input.openingBalances[code] ?? 0;
      if (amount < 0) {
        throw ValidationFailure('Le solde initial $code ne peut pas être négatif.');
      }
      await _db.into(_db.fxSessionBalances).insert(
            db.FxSessionBalancesCompanion.insert(
              shopId: shopId,
              sessionId: sessionId,
              currencyCode: code,
              openingBalance: Value(amount),
              syncStatus: const Value('pending'),
            ),
          );
    }

    return getSession(shopId, sessionId);
  }

  Future<FxSession> closeSession({
    required int shopId,
    required int userId,
    required int sessionId,
    required CloseFxSessionInput input,
  }) async {
    final session = await getSession(shopId, sessionId);
    if (!session.isOpen) {
      throw const ConflictFailure('Cette session FX est déjà clôturée.');
    }

    final live = await computeLiveBalances(shopId, sessionId);
    final timestamp = nowMs();

    for (final balance in session.balances) {
      final expected = live[balance.currencyCode] ?? 0;
      final counted = input.countedBalances[balance.currencyCode] ?? 0;
      await (_db.update(_db.fxSessionBalances)
            ..where((b) => b.id.equals(balance.id)))
          .write(
        db.FxSessionBalancesCompanion(
          expectedBalance: Value(expected),
          countedBalance: Value(counted),
          difference: Value(counted - expected),
        ),
      );
    }

    await (_db.update(_db.fxSessions)..where((s) => s.id.equals(sessionId))).write(
      db.FxSessionsCompanion(
        closedBy: Value(userId),
        closedAt: Value(timestamp),
        status: const Value('closed'),
        closingNote: Value(input.closingNote),
        updatedAt: Value(timestamp),
        syncStatus: const Value('pending'),
      ),
    );

    return getSession(shopId, sessionId);
  }

  Future<FxOperationPreview> previewOperation({
    required int shopId,
    required CreateFxOperationInput input,
  }) async {
    _assertFcfaPair(input.fromCurrency, input.toCurrency);

    final quoteCurrency = input.fromCurrency == fxBaseCurrency
        ? input.toCurrency
        : input.fromCurrency;

    final rate = await findLatestRate(shopId, quoteCurrency);
    if (rate == null) {
      throw ValidationFailure('Aucun taux défini pour $quoteCurrency.');
    }

    if (input.operationType == FxOperationType.sell) {
      if (input.fromCurrency != fxBaseCurrency) {
        throw const ValidationFailure('Vente : le client doit apporter FCFA.');
      }
      final toAmount = _calc.computeForeignFromFcfa(
        input.fromAmount,
        FxRateFraction(
          numerator: rate.sellRateNumerator,
          denominator: rate.sellRateDenominator,
        ),
      );
      final margin = _calc.computeSellMarginFcfa(
        input.fromAmount,
        toAmount,
        FxRateFraction(
          numerator: rate.buyRateNumerator,
          denominator: rate.buyRateDenominator,
        ),
      );
      return FxOperationPreview(
        toAmount: toAmount,
        marginFcfa: margin,
        rateSnapshotId: rate.id,
        appliedRateNumerator: rate.sellRateNumerator,
        appliedRateDenominator: rate.sellRateDenominator,
        quoteCurrency: quoteCurrency,
      );
    }

    if (input.fromCurrency == fxBaseCurrency) {
      throw const ValidationFailure(
        'Achat : le client doit apporter une devise étrangère.',
      );
    }

    final toAmount = _calc.computeFcfaFromForeign(
      input.fromAmount,
      FxRateFraction(
        numerator: rate.buyRateNumerator,
        denominator: rate.buyRateDenominator,
      ),
    );
    final margin = _calc.computeBuyMarginFcfa(
      input.fromAmount,
      toAmount,
      FxRateFraction(
        numerator: rate.sellRateNumerator,
        denominator: rate.sellRateDenominator,
      ),
    );

    return FxOperationPreview(
      toAmount: toAmount,
      marginFcfa: margin,
      rateSnapshotId: rate.id,
      appliedRateNumerator: rate.buyRateNumerator,
      appliedRateDenominator: rate.buyRateDenominator,
      quoteCurrency: quoteCurrency,
    );
  }

  Future<FxOperation> createOperation({
    required int shopId,
    required int userId,
    required int sessionId,
    required CreateFxOperationInput input,
    required bool allowNegativeBalance,
  }) async {
    final session = await getSession(shopId, sessionId);
    if (!session.isOpen) {
      throw const ConflictFailure('La session FX est clôturée.');
    }

    final preview = await previewOperation(shopId: shopId, input: input);
    final toAmount = input.toAmount > 0 ? input.toAmount : preview.toAmount;

    await _assertBalancesAfterOperation(
      shopId: shopId,
      sessionId: sessionId,
      fromCurrency: input.fromCurrency,
      fromAmount: input.fromAmount,
      toCurrency: input.toCurrency,
      toAmount: toAmount,
      allowNegativeBalance: allowNegativeBalance,
    );

    final timestamp = nowMs();
    final opId = await _db.into(_db.fxOperations).insert(
          db.FxOperationsCompanion.insert(
            shopId: shopId,
            sessionId: sessionId,
            operationType: input.operationType.code,
            fromCurrency: input.fromCurrency,
            fromAmount: input.fromAmount,
            toCurrency: input.toCurrency,
            toAmount: toAmount,
            rateSnapshotId: Value(preview.rateSnapshotId),
            marginFcfa: Value(preview.marginFcfa),
            note: Value(input.note),
            createdBy: userId,
            createdAt: timestamp,
            syncStatus: const Value('pending'),
          ),
        );

    await (_db.update(_db.fxSessions)..where((s) => s.id.equals(sessionId))).write(
      db.FxSessionsCompanion(
        totalMarginFcfa: Value(session.totalMarginFcfa + preview.marginFcfa),
        operationCount: Value(session.operationCount + 1),
        updatedAt: Value(timestamp),
        syncStatus: const Value('pending'),
      ),
    );

    return (await findOperation(shopId, opId))!;
  }

  Future<FxOperation?> findOperation(int shopId, int id) async {
    final row = await (_db.select(_db.fxOperations)
          ..where((o) => o.shopId.equals(shopId) & o.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return _mapOperation(row);
  }

  Future<List<FxOperation>> listOperations({
    required int shopId,
    int? sessionId,
    int limit = 200,
  }) async {
    var query = _db.select(_db.fxOperations)
      ..where((o) => o.shopId.equals(shopId))
      ..orderBy([(o) => OrderingTerm.desc(o.createdAt)])
      ..limit(limit);

    if (sessionId != null) {
      query = _db.select(_db.fxOperations)
        ..where(
          (o) => o.shopId.equals(shopId) & o.sessionId.equals(sessionId),
        )
        ..orderBy([(o) => OrderingTerm.desc(o.createdAt)])
        ..limit(limit);
    }

    final rows = await query.get();
    final result = <FxOperation>[];
    for (final row in rows) {
      result.add(await _mapOperation(row));
    }
    return result;
  }

  Future<FxMovement> createMovement({
    required int shopId,
    required int userId,
    required int sessionId,
    required CreateFxMovementInput input,
    required bool allowNegativeBalance,
  }) async {
    final session = await getSession(shopId, sessionId);
    if (!session.isOpen) {
      throw const ConflictFailure('La session FX est clôturée.');
    }

    if (input.movementType == FxMovementType.adjustment &&
        (input.note == null || input.note!.trim().isEmpty)) {
      throw const ValidationFailure(
        'Une justification est requise pour un ajustement.',
      );
    }

    final live = await computeLiveBalances(shopId, sessionId);
    final current = live[input.currencyCode] ?? 0;
    final delta = input.movementType == FxMovementType.withdrawal
        ? -input.amount
        : input.amount;
    final next = current + delta;

    if (next < 0 && !allowNegativeBalance) {
      throw ValidationFailure(
        'Solde ${input.currencyCode} insuffisant ($current).',
      );
    }

    final timestamp = nowMs();
    final id = await _db.into(_db.fxMovements).insert(
          db.FxMovementsCompanion.insert(
            shopId: shopId,
            sessionId: sessionId,
            currencyCode: input.currencyCode,
            movementType: input.movementType.code,
            amount: input.amount,
            note: Value(input.note),
            createdBy: userId,
            createdAt: timestamp,
            syncStatus: const Value('pending'),
          ),
        );

    return (await findMovement(shopId, id))!;
  }

  Future<FxMovement?> findMovement(int shopId, int id) async {
    final row = await (_db.select(_db.fxMovements)
          ..where((m) => m.shopId.equals(shopId) & m.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    return _mapMovement(row);
  }

  Future<List<FxMovement>> listMovements({
    required int shopId,
    int? sessionId,
    int limit = 200,
  }) async {
    var query = _db.select(_db.fxMovements)
      ..where((m) => m.shopId.equals(shopId))
      ..orderBy([(m) => OrderingTerm.desc(m.createdAt)])
      ..limit(limit);

    if (sessionId != null) {
      query = _db.select(_db.fxMovements)
        ..where(
          (m) => m.shopId.equals(shopId) & m.sessionId.equals(sessionId),
        )
        ..orderBy([(m) => OrderingTerm.desc(m.createdAt)])
        ..limit(limit);
    }

    final rows = await query.get();
    final result = <FxMovement>[];
    for (final row in rows) {
      result.add(await _mapMovement(row));
    }
    return result;
  }

  Future<void> _ensureDefaultShopCurrencies(int shopId) async {
    final existing = await (_db.select(_db.fxShopCurrencies)
          ..where((c) => c.shopId.equals(shopId))
          ..limit(1))
        .get();
    if (existing.isNotEmpty) return;

    final currencies = await listCurrencies();
    final timestamp = nowMs();
    for (final currency in currencies) {
      final enabled =
          currency.code == fxBaseCurrency || currency.code == 'NGN';
      await _db.into(_db.fxShopCurrencies).insert(
            db.FxShopCurrenciesCompanion.insert(
              shopId: shopId,
              currencyCode: currency.code,
              enabled: Value(enabled),
              sortOrder: Value(currency.sortOrder),
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
    }
  }

  Future<void> _assertBalancesAfterOperation({
    required int shopId,
    required int sessionId,
    required String fromCurrency,
    required int fromAmount,
    required String toCurrency,
    required int toAmount,
    required bool allowNegativeBalance,
  }) async {
    final live = await computeLiveBalances(shopId, sessionId);
    final toNext = (live[toCurrency] ?? 0) - toAmount;
    if (toNext < 0 && !allowNegativeBalance) {
      throw ValidationFailure(
        'Solde $toCurrency insuffisant (${live[toCurrency] ?? 0}).',
      );
    }
    final fromNext = (live[fromCurrency] ?? 0) + fromAmount;
    if (fromNext < 0 && !allowNegativeBalance) {
      throw ValidationFailure('Solde $fromCurrency insuffisant.');
    }
  }

  void _assertFcfaPair(String from, String to) {
    if (from != fxBaseCurrency && to != fxBaseCurrency) {
      throw const ValidationFailure(
        'Une opération doit impliquer FCFA (XOF) en V1.',
      );
    }
    if (from == to) {
      throw const ValidationFailure('Les devises doivent être différentes.');
    }
  }

  Future<FxSession> _mapSession(db.FxSession row) async {
    final balanceRows = await (_db.select(_db.fxSessionBalances)
          ..where((b) => b.sessionId.equals(row.id))
          ..orderBy([(b) => OrderingTerm.asc(b.currencyCode)]))
        .get();

    return FxSession(
      id: row.id,
      shopId: row.shopId,
      openedBy: row.openedBy,
      openedByName: await _userName(row.openedBy),
      closedBy: row.closedBy,
      closedByName:
          row.closedBy == null ? null : await _userName(row.closedBy!),
      openedAt: row.openedAt,
      closedAt: row.closedAt,
      status: FxSessionStatus.fromCode(row.status),
      closingNote: row.closingNote,
      totalMarginFcfa: row.totalMarginFcfa,
      operationCount: row.operationCount,
      balances: balanceRows
          .map(
            (b) => FxSessionBalance(
              id: b.id,
              sessionId: b.sessionId,
              shopId: b.shopId,
              currencyCode: b.currencyCode,
              openingBalance: b.openingBalance,
              expectedBalance: b.expectedBalance,
              countedBalance: b.countedBalance,
              difference: b.difference,
            ),
          )
          .toList(),
    );
  }

  FxRateSnapshot _mapRate(db.FxRateSnapshot row) {
    return FxRateSnapshot(
      id: row.id,
      shopId: row.shopId,
      baseCurrency: row.baseCurrency,
      quoteCurrency: row.quoteCurrency,
      buyRateNumerator: row.buyRateNumerator,
      buyRateDenominator: row.buyRateDenominator,
      sellRateNumerator: row.sellRateNumerator,
      sellRateDenominator: row.sellRateDenominator,
      effectiveAt: row.effectiveAt,
      createdBy: row.createdBy,
      createdAt: row.createdAt,
    );
  }

  Future<FxOperation> _mapOperation(db.FxOperation row) async {
    return FxOperation(
      id: row.id,
      shopId: row.shopId,
      sessionId: row.sessionId,
      operationType: FxOperationType.fromCode(row.operationType),
      fromCurrency: row.fromCurrency,
      fromAmount: row.fromAmount,
      toCurrency: row.toCurrency,
      toAmount: row.toAmount,
      rateSnapshotId: row.rateSnapshotId,
      marginFcfa: row.marginFcfa,
      note: row.note,
      createdBy: row.createdBy,
      createdByName: await _userName(row.createdBy),
      createdAt: row.createdAt,
    );
  }

  Future<FxMovement> _mapMovement(db.FxMovement row) async {
    return FxMovement(
      id: row.id,
      shopId: row.shopId,
      sessionId: row.sessionId,
      currencyCode: row.currencyCode,
      movementType: FxMovementType.fromCode(row.movementType),
      amount: row.amount,
      note: row.note,
      createdBy: row.createdBy,
      createdByName: await _userName(row.createdBy),
      createdAt: row.createdAt,
    );
  }

  Future<String> _userName(int userId) async {
    final user = await (_db.select(_db.users)
          ..where((u) => u.id.equals(userId) | u.serverId.equals('$userId')))
        .getSingleOrNull();
    return user?.name ?? 'Utilisateur #$userId';
  }
}
