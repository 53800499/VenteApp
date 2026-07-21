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
    final row = await _findModuleRow(shopId);
    return row?.enabled ?? false;
  }

  Future<void> saveModuleStatus(int shopId, bool enabled) async {
    final timestamp = nowMs();
    final existing = await _findModuleRow(shopId);

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
      // Met à jour toutes les lignes (évite les activations fantômes).
      await (_db.update(_db.tenantModules)
            ..where(
              (m) =>
                  m.shopId.equals(shopId) & m.moduleCode.equals(fxModuleCode),
            ))
          .write(db.TenantModulesCompanion(enabled: Value(enabled)));
      await _dedupeModuleRows(shopId, keepId: existing.id);
    }

    if (enabled) {
      await _ensureDefaultShopCurrencies(shopId);
    }
  }

  Future<db.TenantModule?> _findModuleRow(int shopId) async {
    final rows = await (_db.select(_db.tenantModules)
          ..where(
            (m) =>
                m.shopId.equals(shopId) & m.moduleCode.equals(fxModuleCode),
          )
          ..orderBy([(m) => OrderingTerm.desc(m.id)]))
        .get();
    if (rows.isEmpty) return null;
    if (rows.length > 1) {
      await _dedupeModuleRows(shopId, keepId: rows.first.id);
    }
    return rows.first;
  }

  Future<void> _dedupeModuleRows(int shopId, {required int keepId}) async {
    final extras = await (_db.select(_db.tenantModules)
          ..where(
            (m) =>
                m.shopId.equals(shopId) & m.moduleCode.equals(fxModuleCode),
          ))
        .get();
    for (final row in extras) {
      if (row.id == keepId) continue;
      await (_db.delete(_db.tenantModules)..where((m) => m.id.equals(row.id)))
          .go();
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
            )
            ..orderBy([(c) => OrderingTerm.desc(c.id)])
            ..limit(1))
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

    if (input.applyMode == FxRateApplyMode.now) {
      final open = await findOpenSession(shopId);
      if (open != null) {
        await _pinSessionRate(
          shopId: shopId,
          sessionId: open.id,
          quoteCurrency: input.quoteCurrency,
          rateSnapshotId: id,
          appliedAt: timestamp,
        );
      }
    }

    return (await findRateById(shopId, id))!;
  }

  Future<void> _pinSessionRate({
    required int shopId,
    required int sessionId,
    required String quoteCurrency,
    required int rateSnapshotId,
    required int appliedAt,
  }) async {
    final existing = await (_db.select(_db.fxSessionRates)
          ..where(
            (r) =>
                r.shopId.equals(shopId) &
                r.sessionId.equals(sessionId) &
                r.quoteCurrency.equals(quoteCurrency),
          )
          ..limit(1))
        .getSingleOrNull();

    if (existing == null) {
      await _db.into(_db.fxSessionRates).insert(
            db.FxSessionRatesCompanion.insert(
              shopId: shopId,
              sessionId: sessionId,
              quoteCurrency: quoteCurrency,
              rateSnapshotId: rateSnapshotId,
              appliedAt: appliedAt,
              syncStatus: const Value('pending'),
            ),
          );
    } else {
      await (_db.update(_db.fxSessionRates)
            ..where((r) => r.id.equals(existing.id)))
          .write(
        db.FxSessionRatesCompanion(
          rateSnapshotId: Value(rateSnapshotId),
          appliedAt: Value(appliedAt),
          syncStatus: const Value('pending'),
        ),
      );
    }
  }

  /// Taux actif pour les opérations d'une session (gelé / MAJ contrôlée).
  Future<FxRateSnapshot?> findSessionRate(
    int shopId,
    int sessionId,
    String quoteCurrency,
  ) async {
    final pinned = await (_db.select(_db.fxSessionRates)
          ..where(
            (r) =>
                r.shopId.equals(shopId) &
                r.sessionId.equals(sessionId) &
                r.quoteCurrency.equals(quoteCurrency),
          )
          ..limit(1))
        .getSingleOrNull();

    if (pinned != null) {
      return findRateById(shopId, pinned.rateSnapshotId);
    }

    // Backfill sessions ouvertes avant migration v36.
    final latest = await findLatestRate(shopId, quoteCurrency);
    if (latest != null) {
      await _pinSessionRate(
        shopId: shopId,
        sessionId: sessionId,
        quoteCurrency: quoteCurrency,
        rateSnapshotId: latest.id,
        appliedAt: nowMs(),
      );
    }
    return latest;
  }

  Future<List<FxRateSnapshot>> listSessionRates(
    int shopId,
    int sessionId,
  ) async {
    final rows = await (_db.select(_db.fxSessionRates)
          ..where(
            (r) => r.shopId.equals(shopId) & r.sessionId.equals(sessionId),
          ))
        .get();

    if (rows.isEmpty) {
      // Backfill : pin tous les latest puis relire.
      final latest = await listLatestRates(shopId);
      for (final rate in latest) {
        await _pinSessionRate(
          shopId: shopId,
          sessionId: sessionId,
          quoteCurrency: rate.quoteCurrency,
          rateSnapshotId: rate.id,
          appliedAt: nowMs(),
        );
      }
      return latest;
    }

    final rates = <FxRateSnapshot>[];
    for (final row in rows) {
      final rate = await findRateById(shopId, row.rateSnapshotId);
      if (rate != null) rates.add(rate);
    }
    return rates;
  }

  Future<void> upsertSessionRateFromRemote({
    required int shopId,
    required int localSessionId,
    required String quoteCurrency,
    required int localRateSnapshotId,
    required int appliedAt,
    String? serverId,
  }) async {
    final existing = await (_db.select(_db.fxSessionRates)
          ..where(
            (r) =>
                r.shopId.equals(shopId) &
                r.sessionId.equals(localSessionId) &
                r.quoteCurrency.equals(quoteCurrency),
          )
          ..limit(1))
        .getSingleOrNull();

    final companion = db.FxSessionRatesCompanion(
      shopId: Value(shopId),
      sessionId: Value(localSessionId),
      quoteCurrency: Value(quoteCurrency),
      rateSnapshotId: Value(localRateSnapshotId),
      appliedAt: Value(appliedAt),
      serverId: Value(serverId),
      syncedAt: Value(nowMs()),
      syncStatus: const Value('synced'),
    );

    if (existing == null) {
      await _db.into(_db.fxSessionRates).insert(companion);
    } else {
      await (_db.update(_db.fxSessionRates)
            ..where((r) => r.id.equals(existing.id)))
          .write(companion);
    }
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
    // Session active du jour : ouverte ou en attente de validation.
    final row = await (_db.select(_db.fxSessions)
          ..where(
            (s) =>
                s.shopId.equals(shopId) &
                s.status.isIn(['open', 'pending_close']),
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
      throw ConflictFailure(
        existing.isPendingClose
            ? 'Une clôture est en attente de validation.'
            : 'Une session FX est déjà ouverte.',
      );
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

    // Gel des taux du jour pour toute la durée de la session.
    for (final rate in rates) {
      await _pinSessionRate(
        shopId: shopId,
        sessionId: sessionId,
        quoteCurrency: rate.quoteCurrency,
        rateSnapshotId: rate.id,
        appliedAt: timestamp,
      );
    }

    return getSession(shopId, sessionId);
  }

  /// Étape 1 : comptage → statut `pending_close` (ops bloquées).
  Future<FxSession> submitCloseSession({
    required int shopId,
    required int userId,
    required int sessionId,
    required CloseFxSessionInput input,
  }) async {
    final session = await getSession(shopId, sessionId);
    if (!session.isOpen) {
      throw ConflictFailure(
        session.isPendingClose
            ? 'Le comptage a déjà été soumis.'
            : 'Cette session FX est déjà clôturée.',
      );
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

    await (_db.update(_db.fxSessions)..where((s) => s.id.equals(sessionId)))
        .write(
      db.FxSessionsCompanion(
        status: const Value('pending_close'),
        closingNote: Value(input.closingNote),
        updatedAt: Value(timestamp),
        syncStatus: const Value('pending'),
      ),
    );

    return getSession(shopId, sessionId);
  }

  /// Étape 2 : validation définitive → `closed`.
  Future<FxSession> confirmCloseSession({
    required int shopId,
    required int userId,
    required int sessionId,
  }) async {
    final session = await getSession(shopId, sessionId);
    if (!session.isPendingClose) {
      throw ConflictFailure(
        session.isOpen
            ? 'Soumettez d\'abord le comptage.'
            : 'Cette session FX est déjà clôturée.',
      );
    }

    final timestamp = nowMs();
    await (_db.update(_db.fxSessions)..where((s) => s.id.equals(sessionId)))
        .write(
      db.FxSessionsCompanion(
        closedBy: Value(userId),
        closedAt: Value(timestamp),
        status: const Value('closed'),
        updatedAt: Value(timestamp),
        syncStatus: const Value('pending'),
      ),
    );

    return getSession(shopId, sessionId);
  }

  /// Annule un comptage en attente → retour à `open`.
  Future<FxSession> cancelPendingClose({
    required int shopId,
    required int sessionId,
  }) async {
    final session = await getSession(shopId, sessionId);
    if (!session.isPendingClose) {
      throw const ConflictFailure(
        'Aucune clôture en attente de validation.',
      );
    }

    final timestamp = nowMs();
    for (final balance in session.balances) {
      await (_db.update(_db.fxSessionBalances)
            ..where((b) => b.id.equals(balance.id)))
          .write(
        const db.FxSessionBalancesCompanion(
          expectedBalance: Value(null),
          countedBalance: Value(null),
          difference: Value(null),
        ),
      );
    }

    await (_db.update(_db.fxSessions)..where((s) => s.id.equals(sessionId)))
        .write(
      db.FxSessionsCompanion(
        status: const Value('open'),
        closingNote: const Value(null),
        updatedAt: Value(timestamp),
        syncStatus: const Value('pending'),
      ),
    );

    return getSession(shopId, sessionId);
  }

  @Deprecated('Utiliser submitCloseSession')
  Future<FxSession> closeSession({
    required int shopId,
    required int userId,
    required int sessionId,
    required CloseFxSessionInput input,
  }) =>
      submitCloseSession(
        shopId: shopId,
        userId: userId,
        sessionId: sessionId,
        input: input,
      );

  Future<FxOperationPreview> previewOperation({
    required int shopId,
    required CreateFxOperationInput input,
    int? sessionId,
  }) async {
    _assertFcfaPair(input.fromCurrency, input.toCurrency);

    final quoteCurrency = input.fromCurrency == fxBaseCurrency
        ? input.toCurrency
        : input.fromCurrency;

    final rate = sessionId != null
        ? await findSessionRate(shopId, sessionId, quoteCurrency)
        : await findLatestRate(shopId, quoteCurrency);
    if (rate == null) {
      throw ValidationFailure(
        sessionId != null
            ? 'Aucun taux de session pour $quoteCurrency.'
            : 'Aucun taux défini pour $quoteCurrency.',
      );
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

    final preview = await previewOperation(
      shopId: shopId,
      input: input,
      sessionId: sessionId,
    );
    final toAmount = input.toAmount > 0 ? input.toAmount : preview.toAmount;

    await _assertCustomerRequirement(
      shopId: shopId,
      input: input,
      toAmount: toAmount,
    );

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
            customerId: Value(input.customerId),
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

  // --- Sync helpers (push / pull) ---

  Future<String?> findRateServerId(int shopId, int rateId) async {
    final row = await (_db.select(_db.fxRateSnapshots)
          ..where((r) => r.shopId.equals(shopId) & r.id.equals(rateId)))
        .getSingleOrNull();
    return row?.serverId;
  }

  Future<void> updateRateServerSync({
    required int rateId,
    required String serverId,
  }) async {
    await (_db.update(_db.fxRateSnapshots)..where((r) => r.id.equals(rateId)))
        .write(
      db.FxRateSnapshotsCompanion(
        serverId: Value(serverId),
        syncedAt: Value(nowMs()),
        syncStatus: const Value('synced'),
      ),
    );
  }

  Future<int?> findLocalCustomerIdByServerId(int shopId, String serverId) async {
    final row = await (_db.select(_db.customers)
          ..where(
            (c) => c.shopId.equals(shopId) & c.serverId.equals(serverId),
          ))
        .getSingleOrNull();
    return row?.id;
  }

  Future<int?> findLocalRateIdByServerId(int shopId, String serverId) async {
    final row = await (_db.select(_db.fxRateSnapshots)
          ..where(
            (r) => r.shopId.equals(shopId) & r.serverId.equals(serverId),
          ))
        .getSingleOrNull();
    return row?.id;
  }

  Future<void> upsertRateFromRemote({
    required int shopId,
    required Map<String, dynamic> json,
  }) async {
    final serverId = json['serverId']?.toString() ?? json['id']?.toString();
    if (serverId == null) return;

    final quoteCurrency = json['quoteCurrency'] as String? ??
        json['quote_currency'] as String?;
    if (quoteCurrency == null) return;

    final buyNum = (json['buyRateNumerator'] as num?)?.toInt() ??
        (json['buy_rate_numerator'] as num?)?.toInt();
    final buyDen = (json['buyRateDenominator'] as num?)?.toInt() ??
        (json['buy_rate_denominator'] as num?)?.toInt();
    final sellNum = (json['sellRateNumerator'] as num?)?.toInt() ??
        (json['sell_rate_numerator'] as num?)?.toInt();
    final sellDen = (json['sellRateDenominator'] as num?)?.toInt() ??
        (json['sell_rate_denominator'] as num?)?.toInt();
    if (buyNum == null || buyDen == null || sellNum == null || sellDen == null) {
      return;
    }

    final existing = await (_db.select(_db.fxRateSnapshots)
          ..where(
            (r) => r.shopId.equals(shopId) & r.serverId.equals(serverId),
          ))
        .getSingleOrNull();

    db.FxRateSnapshot? pendingMatch;
    if (existing == null) {
      pendingMatch = await (_db.select(_db.fxRateSnapshots)
            ..where(
              (r) =>
                  r.shopId.equals(shopId) &
                  r.quoteCurrency.equals(quoteCurrency) &
                  r.buyRateNumerator.equals(buyNum) &
                  r.buyRateDenominator.equals(buyDen) &
                  r.sellRateNumerator.equals(sellNum) &
                  r.sellRateDenominator.equals(sellDen) &
                  r.serverId.isNull(),
            )
            ..orderBy([(r) => OrderingTerm.desc(r.effectiveAt)])
            ..limit(1))
          .getSingleOrNull();
    }

    final companion = db.FxRateSnapshotsCompanion(
      shopId: Value(shopId),
      baseCurrency: Value(
        json['baseCurrency'] as String? ??
            json['base_currency'] as String? ??
            fxBaseCurrency,
      ),
      quoteCurrency: Value(quoteCurrency),
      buyRateNumerator: Value(buyNum),
      buyRateDenominator: Value(buyDen),
      sellRateNumerator: Value(sellNum),
      sellRateDenominator: Value(sellDen),
      effectiveAt: Value(
        (json['effectiveAt'] as num?)?.toInt() ??
            (json['effective_at'] as num?)?.toInt() ??
            nowMs(),
      ),
      createdBy: Value(
        (json['createdBy'] as num?)?.toInt() ??
            (json['created_by'] as num?)?.toInt() ??
            1,
      ),
      createdAt: Value(
        (json['createdAt'] as num?)?.toInt() ??
            (json['created_at'] as num?)?.toInt() ??
            nowMs(),
      ),
      serverId: Value(serverId),
      syncedAt: Value(nowMs()),
      syncStatus: const Value('synced'),
    );

    if (existing != null) {
      await (_db.update(_db.fxRateSnapshots)
            ..where((r) => r.id.equals(existing.id)))
          .write(companion);
    } else if (pendingMatch != null) {
      await (_db.update(_db.fxRateSnapshots)
            ..where((r) => r.id.equals(pendingMatch!.id)))
          .write(companion);
    } else {
      await _db.into(_db.fxRateSnapshots).insert(companion);
    }
  }

  Future<void> upsertCurrencyFromRemote({
    required String code,
    required String label,
    required String symbol,
    required int minorUnit,
    required int sortOrder,
  }) async {
    await _db.into(_db.fxCurrencies).insertOnConflictUpdate(
          db.FxCurrenciesCompanion.insert(
            code: code,
            label: label,
            symbol: symbol,
            minorUnit: Value(minorUnit),
            sortOrder: Value(sortOrder),
          ),
        );
  }

  Future<void> upsertShopCurrencyFromRemote({
    required int shopId,
    required String currencyCode,
    required bool enabled,
    required int sortOrder,
    String? serverId,
  }) async {
    final existing = await (_db.select(_db.fxShopCurrencies)
          ..where(
            (c) =>
                c.shopId.equals(shopId) & c.currencyCode.equals(currencyCode),
          )
          ..orderBy([(c) => OrderingTerm.desc(c.id)])
          ..limit(1))
        .getSingleOrNull();
    final timestamp = nowMs();
    if (existing == null) {
      await _db.into(_db.fxShopCurrencies).insert(
            db.FxShopCurrenciesCompanion.insert(
              shopId: shopId,
              currencyCode: currencyCode,
              enabled: Value(enabled),
              sortOrder: Value(sortOrder),
              createdAt: timestamp,
              updatedAt: timestamp,
              serverId: Value(serverId),
              syncedAt: Value(timestamp),
              syncStatus: const Value('synced'),
            ),
          );
    } else {
      await (_db.update(_db.fxShopCurrencies)
            ..where((c) => c.id.equals(existing.id)))
          .write(
        db.FxShopCurrenciesCompanion(
          enabled: Value(enabled),
          sortOrder: Value(sortOrder),
          updatedAt: Value(timestamp),
          serverId: Value(serverId ?? existing.serverId),
          syncedAt: Value(timestamp),
          syncStatus: const Value('synced'),
        ),
      );
    }
  }

  Future<String?> findSessionServerId(int shopId, int sessionId) async {
    final row = await (_db.select(_db.fxSessions)
          ..where((s) => s.shopId.equals(shopId) & s.id.equals(sessionId)))
        .getSingleOrNull();
    return row?.serverId;
  }

  Future<void> updateSessionServerSync({
    required int sessionId,
    required String serverId,
  }) async {
    await (_db.update(_db.fxSessions)..where((s) => s.id.equals(sessionId)))
        .write(
      db.FxSessionsCompanion(
        serverId: Value(serverId),
        syncedAt: Value(nowMs()),
        syncStatus: const Value('synced'),
      ),
    );
  }

  Future<int?> findLocalSessionIdByServerId(
    int shopId,
    String serverSessionId,
  ) async {
    final row = await (_db.select(_db.fxSessions)
          ..where(
            (s) =>
                s.shopId.equals(shopId) & s.serverId.equals(serverSessionId),
          ))
        .getSingleOrNull();
    return row?.id;
  }

  Future<FxSession?> findSessionForSync(int shopId, int sessionId) async {
    try {
      return await getSession(shopId, sessionId);
    } catch (_) {
      return null;
    }
  }

  Future<void> upsertSessionFromRemote({
    required int shopId,
    required Map<String, dynamic> json,
  }) async {
    final serverId = json['serverId']?.toString() ?? json['id']?.toString();
    if (serverId == null) return;

    final status = json['status'] as String? ?? 'closed';
    final existing = await (_db.select(_db.fxSessions)
          ..where(
            (s) => s.shopId.equals(shopId) & s.serverId.equals(serverId),
          ))
        .getSingleOrNull();

    db.FxSession? pendingOpen;
    if (existing == null && status == 'open') {
      pendingOpen = await (_db.select(_db.fxSessions)
            ..where(
              (s) =>
                  s.shopId.equals(shopId) &
                  s.status.isIn(['open', 'pending_close']) &
                  s.serverId.isNull(),
            )
            ..orderBy([(s) => OrderingTerm.desc(s.openedAt)])
            ..limit(1))
          .getSingleOrNull();
    }

    final openedAt = (json['openedAt'] as num?)?.toInt() ??
        (json['opened_at'] as num?)?.toInt() ??
        nowMs();
    final closedAt = (json['closedAt'] as num?)?.toInt() ??
        (json['closed_at'] as num?)?.toInt();

    final companion = db.FxSessionsCompanion(
      shopId: Value(shopId),
      openedBy: Value(
        (json['openedBy'] as num?)?.toInt() ??
            (json['opened_by'] as num?)?.toInt() ??
            1,
      ),
      closedBy: Value(
        (json['closedBy'] as num?)?.toInt() ??
            (json['closed_by'] as num?)?.toInt(),
      ),
      openedAt: Value(openedAt),
      closedAt: Value(closedAt),
      status: Value(status),
      closingNote: Value(
        json['closingNote'] as String? ?? json['closing_note'] as String?,
      ),
      totalMarginFcfa: Value(
        (json['totalMarginFcfa'] as num?)?.toInt() ??
            (json['total_margin_fcfa'] as num?)?.toInt() ??
            0,
      ),
      operationCount: Value(
        (json['operationCount'] as num?)?.toInt() ??
            (json['operation_count'] as num?)?.toInt() ??
            0,
      ),
      createdAt: Value(openedAt),
      updatedAt: Value(closedAt ?? openedAt),
      serverId: Value(serverId),
      syncedAt: Value(nowMs()),
      syncStatus: const Value('synced'),
    );

    late final int localSessionId;
    if (existing != null) {
      await (_db.update(_db.fxSessions)..where((s) => s.id.equals(existing.id)))
          .write(companion);
      localSessionId = existing.id;
    } else if (pendingOpen != null) {
      await (_db.update(_db.fxSessions)
            ..where((s) => s.id.equals(pendingOpen!.id)))
          .write(companion);
      localSessionId = pendingOpen.id;
    } else {
      localSessionId = await _db.into(_db.fxSessions).insert(companion);
    }

    final balancesJson = json['balances'] as List<dynamic>? ?? const [];
    for (final raw in balancesJson) {
      if (raw is! Map<String, dynamic>) continue;
      final currencyCode = raw['currencyCode'] as String? ??
          raw['currency_code'] as String?;
      if (currencyCode == null) continue;

      final existingBalance = await (_db.select(_db.fxSessionBalances)
            ..where(
              (b) =>
                  b.shopId.equals(shopId) &
                  b.sessionId.equals(localSessionId) &
                  b.currencyCode.equals(currencyCode),
            )
            ..limit(1))
          .getSingleOrNull();
      final balanceCompanion = db.FxSessionBalancesCompanion(
        shopId: Value(shopId),
        sessionId: Value(localSessionId),
        currencyCode: Value(currencyCode),
        openingBalance: Value(
          (raw['openingBalance'] as num?)?.toInt() ??
              (raw['opening_balance'] as num?)?.toInt() ??
              0,
        ),
        expectedBalance: Value(
          (raw['expectedBalance'] as num?)?.toInt() ??
              (raw['expected_balance'] as num?)?.toInt(),
        ),
        countedBalance: Value(
          (raw['countedBalance'] as num?)?.toInt() ??
              (raw['counted_balance'] as num?)?.toInt(),
        ),
        difference: Value(
          (raw['difference'] as num?)?.toInt(),
        ),
        syncStatus: const Value('synced'),
        syncedAt: Value(nowMs()),
      );
      if (existingBalance == null) {
        await _db.into(_db.fxSessionBalances).insert(balanceCompanion);
      } else {
        await (_db.update(_db.fxSessionBalances)
              ..where((b) => b.id.equals(existingBalance.id)))
            .write(balanceCompanion);
      }
    }

    final ratesJson = json['sessionRates'] as List<dynamic>? ??
        json['session_rates'] as List<dynamic>? ??
        const [];
    for (final raw in ratesJson) {
      if (raw is! Map<String, dynamic>) continue;
      final quoteCurrency = raw['quoteCurrency'] as String? ??
          raw['quote_currency'] as String?;
      final remoteRateId = raw['rateSnapshotId']?.toString() ??
          raw['rate_snapshot_id']?.toString();
      if (quoteCurrency == null || remoteRateId == null) continue;

      final localRateId =
          await findLocalRateIdByServerId(shopId, remoteRateId);
      if (localRateId == null) continue;

      await upsertSessionRateFromRemote(
        shopId: shopId,
        localSessionId: localSessionId,
        quoteCurrency: quoteCurrency,
        localRateSnapshotId: localRateId,
        appliedAt: (raw['appliedAt'] as num?)?.toInt() ??
            (raw['applied_at'] as num?)?.toInt() ??
            nowMs(),
        serverId: raw['id']?.toString(),
      );
    }
  }

  Future<String?> findOperationServerId(int shopId, int operationId) async {
    final row = await (_db.select(_db.fxOperations)
          ..where(
            (o) => o.shopId.equals(shopId) & o.id.equals(operationId),
          ))
        .getSingleOrNull();
    return row?.serverId;
  }

  Future<void> updateOperationServerSync({
    required int operationId,
    required String serverId,
  }) async {
    await (_db.update(_db.fxOperations)
          ..where((o) => o.id.equals(operationId)))
        .write(
      db.FxOperationsCompanion(
        serverId: Value(serverId),
        syncedAt: Value(nowMs()),
        syncStatus: const Value('synced'),
      ),
    );
  }

  Future<void> upsertOperationFromRemote({
    required int shopId,
    required int localSessionId,
    required Map<String, dynamic> json,
    int? localRateSnapshotId,
  }) async {
    final serverId = json['serverId']?.toString() ?? json['id']?.toString();
    if (serverId == null) return;

    final fromCurrency = json['fromCurrency'] as String? ??
        json['from_currency'] as String?;
    final toCurrency =
        json['toCurrency'] as String? ?? json['to_currency'] as String?;
    final fromAmount = (json['fromAmount'] as num?)?.toInt() ??
        (json['from_amount'] as num?)?.toInt();
    final toAmount = (json['toAmount'] as num?)?.toInt() ??
        (json['to_amount'] as num?)?.toInt();
    if (fromCurrency == null ||
        toCurrency == null ||
        fromAmount == null ||
        toAmount == null) {
      return;
    }

    final existing = await (_db.select(_db.fxOperations)
          ..where(
            (o) => o.shopId.equals(shopId) & o.serverId.equals(serverId),
          ))
        .getSingleOrNull();

    final companion = db.FxOperationsCompanion(
      shopId: Value(shopId),
      sessionId: Value(localSessionId),
      operationType: Value(
        json['operationType'] as String? ??
            json['operation_type'] as String? ??
            'buy',
      ),
      fromCurrency: Value(fromCurrency),
      fromAmount: Value(fromAmount),
      toCurrency: Value(toCurrency),
      toAmount: Value(toAmount),
      rateSnapshotId: Value(localRateSnapshotId),
      marginFcfa: Value(
        (json['marginFcfa'] as num?)?.toInt() ??
            (json['margin_fcfa'] as num?)?.toInt() ??
            0,
      ),
      customerId: Value(
        (json['localCustomerId'] as num?)?.toInt(),
      ),
      note: Value(json['note'] as String?),
      createdBy: Value(
        (json['createdBy'] as num?)?.toInt() ??
            (json['created_by'] as num?)?.toInt() ??
            1,
      ),
      createdAt: Value(
        (json['createdAt'] as num?)?.toInt() ??
            (json['created_at'] as num?)?.toInt() ??
            nowMs(),
      ),
      serverId: Value(serverId),
      syncedAt: Value(nowMs()),
      syncStatus: const Value('synced'),
    );

    if (existing == null) {
      final pending = await (_db.select(_db.fxOperations)
            ..where(
              (o) =>
                  o.shopId.equals(shopId) &
                  o.sessionId.equals(localSessionId) &
                  o.fromCurrency.equals(fromCurrency) &
                  o.fromAmount.equals(fromAmount) &
                  o.toCurrency.equals(toCurrency) &
                  o.toAmount.equals(toAmount) &
                  o.serverId.isNull(),
            )
            ..limit(1))
          .getSingleOrNull();
      if (pending != null) {
        await (_db.update(_db.fxOperations)
              ..where((o) => o.id.equals(pending.id)))
            .write(companion);
      } else {
        await _db.into(_db.fxOperations).insert(companion);
      }
    } else {
      await (_db.update(_db.fxOperations)
            ..where((o) => o.id.equals(existing.id)))
          .write(companion);
    }
  }

  Future<String?> findMovementServerId(int shopId, int movementId) async {
    final row = await (_db.select(_db.fxMovements)
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
    await (_db.update(_db.fxMovements)..where((m) => m.id.equals(movementId)))
        .write(
      db.FxMovementsCompanion(
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

    final currencyCode = json['currencyCode'] as String? ??
        json['currency_code'] as String?;
    final movementType = json['movementType'] as String? ??
        json['movement_type'] as String?;
    final amount = (json['amount'] as num?)?.toInt();
    if (currencyCode == null || movementType == null || amount == null) {
      return;
    }

    final existing = await (_db.select(_db.fxMovements)
          ..where(
            (m) => m.shopId.equals(shopId) & m.serverId.equals(serverId),
          ))
        .getSingleOrNull();

    final companion = db.FxMovementsCompanion(
      shopId: Value(shopId),
      sessionId: Value(localSessionId),
      currencyCode: Value(currencyCode),
      movementType: Value(movementType),
      amount: Value(amount),
      note: Value(json['note'] as String?),
      createdBy: Value(
        (json['createdBy'] as num?)?.toInt() ??
            (json['created_by'] as num?)?.toInt() ??
            1,
      ),
      createdAt: Value(
        (json['createdAt'] as num?)?.toInt() ??
            (json['created_at'] as num?)?.toInt() ??
            nowMs(),
      ),
      serverId: Value(serverId),
      syncedAt: Value(nowMs()),
      syncStatus: const Value('synced'),
    );

    if (existing == null) {
      final pending = await (_db.select(_db.fxMovements)
            ..where(
              (m) =>
                  m.shopId.equals(shopId) &
                  m.sessionId.equals(localSessionId) &
                  m.currencyCode.equals(currencyCode) &
                  m.movementType.equals(movementType) &
                  m.amount.equals(amount) &
                  m.serverId.isNull(),
            )
            ..limit(1))
          .getSingleOrNull();
      if (pending != null) {
        await (_db.update(_db.fxMovements)
              ..where((m) => m.id.equals(pending.id)))
            .write(companion);
      } else {
        await _db.into(_db.fxMovements).insert(companion);
      }
    } else {
      await (_db.update(_db.fxMovements)
            ..where((m) => m.id.equals(existing.id)))
          .write(companion);
    }
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
    String? customerName;
    if (row.customerId != null) {
      final customer = await (_db.select(_db.customers)
            ..where((c) => c.id.equals(row.customerId!)))
          .getSingleOrNull();
      customerName = customer?.name;
    }

    String? quoteCurrency;
    int? sellRateNumerator;
    int? sellRateDenominator;
    int? buyRateNumerator;
    int? buyRateDenominator;
    if (row.rateSnapshotId != null) {
      final rate = await (_db.select(_db.fxRateSnapshots)
            ..where((r) => r.id.equals(row.rateSnapshotId!))
            ..limit(1))
          .getSingleOrNull();
      if (rate != null) {
        quoteCurrency = rate.quoteCurrency;
        sellRateNumerator = rate.sellRateNumerator;
        sellRateDenominator = rate.sellRateDenominator;
        buyRateNumerator = rate.buyRateNumerator;
        buyRateDenominator = rate.buyRateDenominator;
      }
    }

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
      customerId: row.customerId,
      customerName: customerName,
      note: row.note,
      createdBy: row.createdBy,
      createdByName: await _userName(row.createdBy),
      createdAt: row.createdAt,
      quoteCurrency: quoteCurrency,
      sellRateNumerator: sellRateNumerator,
      sellRateDenominator: sellRateDenominator,
      buyRateNumerator: buyRateNumerator,
      buyRateDenominator: buyRateDenominator,
    );
  }

  Future<List<FxOperation>> listOperationsInRange({
    required int shopId,
    required int fromMs,
    required int toMs,
    int limit = 10_000,
  }) async {
    final rows = await (_db.select(_db.fxOperations)
          ..where(
            (o) =>
                o.shopId.equals(shopId) &
                o.createdAt.isBiggerOrEqualValue(fromMs) &
                o.createdAt.isSmallerThanValue(toMs),
          )
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)])
          ..limit(limit))
        .get();
    final result = <FxOperation>[];
    for (final row in rows) {
      result.add(await _mapOperation(row));
    }
    return result;
  }

  Future<List<FxMovement>> listMovementsInRange({
    required int shopId,
    required int fromMs,
    required int toMs,
    int limit = 10_000,
  }) async {
    final rows = await (_db.select(_db.fxMovements)
          ..where(
            (m) =>
                m.shopId.equals(shopId) &
                m.createdAt.isBiggerOrEqualValue(fromMs) &
                m.createdAt.isSmallerThanValue(toMs),
          )
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)])
          ..limit(limit))
        .get();
    return Future.wait(rows.map(_mapMovement));
  }

  Future<int> countSessionsOverlappingRange({
    required int shopId,
    required int fromMs,
    required int toMs,
  }) async {
    final rows = await (_db.select(_db.fxSessions)
          ..where((s) => s.shopId.equals(shopId)))
        .get();
    var count = 0;
    for (final s in rows) {
      final closed = s.closedAt ?? nowMs();
      if (s.openedAt < toMs && closed >= fromMs) count++;
    }
    return count;
  }

  Future<int> getCustomerRequiredAboveFcfa(int shopId) async {
    try {
      final row = await (_db.select(_db.settings)
            ..where((s) => s.shopId.equals(shopId))
            ..orderBy([(s) => OrderingTerm.desc(s.id)])
            ..limit(1))
          .getSingleOrNull();
      return row?.fxCustomerRequiredAboveFcfa ?? 0;
    } catch (_) {
      // Colonne absente tant que le backfill n'a pas tourné.
      return 0;
    }
  }

  Future<void> setCustomerRequiredAboveFcfa(int shopId, int amountFcfa) async {
    if (amountFcfa < 0) {
      throw const ValidationFailure('Le seuil client ne peut pas être négatif.');
    }
    final existing = await (_db.select(_db.settings)
          ..where((s) => s.shopId.equals(shopId))
          ..orderBy([(s) => OrderingTerm.desc(s.id)])
          ..limit(1))
        .getSingleOrNull();
    if (existing == null) {
      throw const ValidationFailure('Paramètres boutique introuvables.');
    }
    await (_db.update(_db.settings)..where((s) => s.id.equals(existing.id)))
        .write(
      db.SettingsCompanion(
        fxCustomerRequiredAboveFcfa: Value(amountFcfa),
        updatedAt: Value(nowMs()),
      ),
    );
  }

  Future<bool> getPrimaryWorkspace(int shopId) async {
    try {
      final row = await (_db.select(_db.settings)
            ..where((s) => s.shopId.equals(shopId))
            ..orderBy([(s) => OrderingTerm.desc(s.id)])
            ..limit(1))
          .getSingleOrNull();
      return row?.fxPrimaryWorkspace ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setPrimaryWorkspace(int shopId, bool enabled) async {
    final existing = await (_db.select(_db.settings)
          ..where((s) => s.shopId.equals(shopId))
          ..orderBy([(s) => OrderingTerm.desc(s.id)])
          ..limit(1))
        .getSingleOrNull();
    if (existing == null) {
      throw const ValidationFailure('Paramètres boutique introuvables.');
    }
    await (_db.update(_db.settings)..where((s) => s.id.equals(existing.id)))
        .write(
      db.SettingsCompanion(
        fxPrimaryWorkspace: Value(enabled),
        updatedAt: Value(nowMs()),
      ),
    );
  }

  Future<void> _assertCustomerRequirement({
    required int shopId,
    required CreateFxOperationInput input,
    required int toAmount,
  }) async {
    final threshold = await getCustomerRequiredAboveFcfa(shopId);
    if (threshold <= 0) return;

    final fcfaAmount = input.fromCurrency == fxBaseCurrency
        ? input.fromAmount
        : toAmount;
    if (fcfaAmount >= threshold && input.customerId == null) {
      throw ValidationFailure(
        'Un client est obligatoire pour les opérations ≥ $threshold FCFA.',
      );
    }
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
    // Ne pas combiner id | serverId : plusieurs users peuvent matcher
    // (ex. id local = 3 et un autre user avec serverId "3").
    final byId = await (_db.select(_db.users)
          ..where((u) => u.id.equals(userId))
          ..limit(1))
        .getSingleOrNull();
    if (byId != null) return byId.name;

    final byServerId = await (_db.select(_db.users)
          ..where((u) => u.serverId.equals('$userId'))
          ..limit(1))
        .getSingleOrNull();
    return byServerId?.name ?? 'Utilisateur #$userId';
  }
}
