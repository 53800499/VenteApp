import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart' as db;
import '../../../../../core/utils/time.dart';
import '../../../domain/entities/debt_entities.dart';
import '../../mappers/debt_mapper.dart';
import '../../models/debt_api_models.dart';

class DebtsLocalDatasource {
  DebtsLocalDatasource(this._db);

  final db.AppDatabase _db;

  Future<List<Debt>> listCustomerDebts({
    required int shopId,
    required int customerId,
    bool openOnly = true,
  }) async {
    final rows = await (_db.select(_db.debts)
          ..where((d) {
            var expr =
                d.shopId.equals(shopId) & d.customerId.equals(customerId);
            if (openOnly) {
              expr = expr &
                  (d.status.equals('open') | d.status.equals('partial'));
            }
            return expr;
          })
          ..orderBy([(d) => OrderingTerm.desc(d.createdAt)]))
        .get();

    final debts = <Debt>[];
    for (final row in rows) {
      final receipt = await _receiptForSale(shopId, row.saleId);
      debts.add(
        DebtMapper.fromRow(
          row,
          receiptNumber: receipt,
          isCritical: _isCritical(row),
        ),
      );
    }
    return debts;
  }

  Future<Debt?> findDebt(int shopId, int debtId) async {
    final row = await (_db.select(_db.debts)
          ..where(
            (d) => d.id.equals(debtId) & d.shopId.equals(shopId),
          ))
        .getSingleOrNull();
    if (row == null) return null;

    final receipt = await _receiptForSale(shopId, row.saleId);
    return DebtMapper.fromRow(
      row,
      receiptNumber: receipt,
      isCritical: _isCritical(row),
    );
  }

  Future<DebtPaymentResult> recordPayment({
    required int shopId,
    required int debtId,
    required int amount,
    required DebtStatus newStatus,
  }) async {
    final row = await (_db.select(_db.debts)
          ..where(
            (d) => d.id.equals(debtId) & d.shopId.equals(shopId),
          ))
        .getSingleOrNull();
    if (row == null) {
      throw StateError('Dette introuvable');
    }

    final newPaid = row.amountPaid + amount;
    final newRemaining = row.amountRemaining - amount;
    final timestamp = nowMs();

    await (_db.update(_db.debts)..where((d) => d.id.equals(debtId))).write(
      db.DebtsCompanion(
        amountPaid: Value(newPaid),
        amountRemaining: Value(newRemaining),
        status: Value(newStatus.code),
        updatedAt: Value(timestamp),
        version: Value(row.version + 1),
      ),
    );

    return DebtPaymentResult(
      debtId: debtId,
      amount: amount,
      amountRemaining: newRemaining,
      status: newStatus,
    );
  }

  Future<DebtPaymentResult> recordPaymentWithAudit({
    required int shopId,
    required int debtId,
    required int userId,
    required int amount,
    required DebtRepaymentMethod method,
    required DebtStatus newStatus,
    String? reference,
    String? note,
  }) async {
    return _db.transaction(() async {
      final row = await (_db.select(_db.debts)
            ..where(
              (d) => d.id.equals(debtId) & d.shopId.equals(shopId),
            ))
          .getSingleOrNull();
      if (row == null) {
        throw StateError('Dette introuvable');
      }

      final newPaid = row.amountPaid + amount;
      final newRemaining = row.amountRemaining - amount;
      final timestamp = nowMs();

      await (_db.update(_db.debts)..where((d) => d.id.equals(debtId))).write(
        db.DebtsCompanion(
          amountPaid: Value(newPaid),
          amountRemaining: Value(newRemaining),
          status: Value(newStatus.code),
          updatedAt: Value(timestamp),
          version: Value(row.version + 1),
        ),
      );

      await _db.into(_db.auditLogs).insert(
            db.AuditLogsCompanion.insert(
              shopId: shopId,
              userId: userId,
              action: 'debt_payment_recorded',
              module: 'debts',
              entityId: debtId,
              entityTable: 'debts',
              oldValue: Value(
                jsonEncode({
                  'amountPaid': row.amountPaid,
                  'amountRemaining': row.amountRemaining,
                  'status': row.status,
                }),
              ),
              newValue: Value(
                jsonEncode({
                  'amount': amount,
                  'method': method.code,
                  if (reference != null && reference.isNotEmpty)
                    'reference': reference,
                  'amountPaid': newPaid,
                  'amountRemaining': newRemaining,
                  'status': newStatus.code,
                }),
              ),
              reason: Value(note ?? 'Remboursement de dette enregistré'),
              createdAt: timestamp,
            ),
          );

      return DebtPaymentResult(
        debtId: debtId,
        amount: amount,
        amountRemaining: newRemaining,
        status: newStatus,
      );
    });
  }

  Future<List<DebtPaymentHistoryItem>> listPaymentHistory({
    required int shopId,
    required int debtId,
  }) async {
    final rows = await (_db.select(_db.auditLogs)
          ..where(
            (a) =>
                a.shopId.equals(shopId) &
                a.entityTable.equals('debts') &
                a.entityId.equals(debtId) &
                a.action.equals('debt_payment_recorded'),
          )
          ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
        .get();

    final userNames = await _userNamesFor(rows.map((r) => r.userId).toSet());
    final items = <DebtPaymentHistoryItem>[];

    for (final row in rows) {
      final newValue = _decodeJson(row.newValue);
      final oldValue = _decodeJson(row.oldValue);
      final amount = (newValue['amount'] as int?) ??
          ((newValue['amountPaid'] as int? ?? 0) -
              (oldValue['amountPaid'] as int? ?? 0));
      if (amount <= 0) continue;

      items.add(
        DebtPaymentHistoryItem(
          id: row.id,
          paymentId: newValue['paymentId'] as int?,
          amount: amount,
          method: DebtRepaymentMethodX.fromCode(
            newValue['method'] as String?,
          ),
          reference: newValue['reference'] as String?,
          userName: userNames[row.userId],
          receiptNumber: newValue['receiptNumber'] as String?,
          createdAt: row.createdAt,
        ),
      );
    }

    return items;
  }

  Map<String, dynamic> _decodeJson(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  Future<Map<int, String>> _userNamesFor(Set<int> userIds) async {
    if (userIds.isEmpty) return {};
    final rows = await (_db.select(_db.users)
          ..where((u) => u.id.isIn(userIds.toList())))
        .get();
    return {for (final row in rows) row.id: row.name};
  }

  Future<Debt> forgiveDebt({
    required int shopId,
    required int debtId,
    required int userId,
    required String reason,
  }) async {
    return _db.transaction(() async {
      final row = await (_db.select(_db.debts)
            ..where(
              (d) => d.id.equals(debtId) & d.shopId.equals(shopId),
            ))
          .getSingleOrNull();
      if (row == null) {
        throw StateError('Dette introuvable');
      }

      final timestamp = nowMs();
      final trimmedReason = reason.trim();

      await (_db.update(_db.debts)..where((d) => d.id.equals(debtId))).write(
        db.DebtsCompanion(
          amountRemaining: const Value(0),
          status: const Value('forgiven'),
          updatedAt: Value(timestamp),
          version: Value(row.version + 1),
        ),
      );

      await _db.into(_db.auditLogs).insert(
            db.AuditLogsCompanion.insert(
              shopId: shopId,
              userId: userId,
              action: 'debt_forgiven',
              module: 'debts',
              entityId: debtId,
              entityTable: 'debts',
              oldValue: Value(
                jsonEncode({
                  'status': row.status,
                  'amountRemaining': row.amountRemaining,
                }),
              ),
              newValue: const Value(
                '{"status":"forgiven","amountRemaining":0}',
              ),
              reason: Value(trimmedReason),
              createdAt: timestamp,
            ),
          );

      final receipt = await _receiptForSale(shopId, row.saleId);
      final updated = await (_db.select(_db.debts)
            ..where(
              (d) => d.id.equals(debtId) & d.shopId.equals(shopId),
            ))
          .getSingleOrNull();
      return DebtMapper.fromRow(
        updated!,
        receiptNumber: receipt,
        isCritical: false,
      );
    });
  }

  Future<void> applyRemotePayment({
    required int shopId,
    required int debtId,
    required int amountPaid,
    required int amountRemaining,
    required String status,
  }) async {
    await (_db.update(_db.debts)..where((d) => d.id.equals(debtId))).write(
      db.DebtsCompanion(
        amountPaid: Value(amountPaid),
        amountRemaining: Value(amountRemaining),
        status: Value(status),
        syncedAt: Value(nowMs()),
        updatedAt: Value(nowMs()),
      ),
    );
  }

  Future<int> upsertFromRemote({
    required int shopId,
    required int localCustomerId,
    required DebtApiDto remote,
    int? localSaleId,
  }) async {
    final existingRows = await (_db.select(_db.debts)
          ..where(
            (d) =>
                d.shopId.equals(shopId) &
                d.serverId.equals('${remote.id}'),
          ))
        .get();
    final existing = existingRows.isEmpty ? null : existingRows.first;

    final timestamp = nowMs();
    late final int localDebtId;
    if (existing != null) {
      localDebtId = existing.id;
      await (_db.update(_db.debts)..where((d) => d.id.equals(existing.id)))
          .write(
        db.DebtsCompanion(
          originalAmount: Value(remote.originalAmount),
          amountPaid: Value(remote.amountPaid),
          amountRemaining: Value(remote.amountRemaining),
          status: Value(remote.status),
          syncedAt: Value(timestamp),
          updatedAt: Value(remote.updatedAt ?? timestamp),
        ),
      );
      if (existingRows.length > 1) {
        final duplicateIds = existingRows.skip(1).map((d) => d.id).toList();
        await (_db.delete(_db.debts)..where((d) => d.id.isIn(duplicateIds))).go();
      }
    } else {
      localDebtId = await _db.into(_db.debts).insert(
            db.DebtsCompanion.insert(
              shopId: shopId,
              customerId: localCustomerId,
              saleId: Value(localSaleId),
              originalAmount: remote.originalAmount,
              amountPaid: Value(remote.amountPaid),
              amountRemaining: remote.amountRemaining,
              status: Value(remote.status),
              createdAt: remote.createdAt,
              dueAt: Value(remote.dueAt),
              serverId: Value('${remote.id}'),
              syncedAt: Value(timestamp),
              updatedAt: Value(remote.updatedAt ?? timestamp),
            ),
          );
    }

    if (remote.status == 'forgiven') {
      await _ensureForgivenessAuditFromRemote(
        shopId: shopId,
        debtId: localDebtId,
        remote: remote,
      );
    }

    return localDebtId;
  }

  Future<void> _ensureForgivenessAuditFromRemote({
    required int shopId,
    required int debtId,
    required DebtApiDto remote,
  }) async {
    final existingAudit = await (_db.select(_db.auditLogs)
          ..where(
            (a) =>
                a.shopId.equals(shopId) &
                a.entityTable.equals('debts') &
                a.entityId.equals(debtId) &
                a.action.equals('debt_forgiven'),
          )
          ..limit(1))
        .get();
    if (existingAudit.isNotEmpty) return;

    final forgivenAt = remote.forgivenAt ?? remote.updatedAt ?? nowMs();
    final forgivenAmount = remote.forgivenAmount ??
        (remote.originalAmount - remote.amountPaid).clamp(0, remote.originalAmount);
    final reason = remote.forgivenReason?.trim().isNotEmpty == true
        ? remote.forgivenReason!.trim()
        : 'Pardon enregistré (sync cloud)';

    final userId = await (_db.select(_db.users)
          ..where((u) => u.shopId.equals(shopId))
          ..limit(1))
        .get()
        .then((rows) => rows.firstOrNull?.id ?? 1);

    await _db.into(_db.auditLogs).insert(
          db.AuditLogsCompanion.insert(
            shopId: shopId,
            userId: userId,
            action: 'debt_forgiven',
            module: 'debts',
            entityId: debtId,
            entityTable: 'debts',
            oldValue: Value(
              jsonEncode({
                'status': 'open',
                'amountRemaining': forgivenAmount,
              }),
            ),
            newValue: const Value(
              '{"status":"forgiven","amountRemaining":0}',
            ),
            reason: Value(reason),
            createdAt: forgivenAt,
          ),
        );
  }

  Future<List<ForgivenDebtEntry>> listForgivenDebts({
    required int shopId,
    int? customerId,
  }) async {
    final rows = await (_db.select(_db.debts)
          ..where((d) {
            var expr =
                d.shopId.equals(shopId) & d.status.equals('forgiven');
            if (customerId != null) {
              expr = expr & d.customerId.equals(customerId);
            }
            return expr;
          })
          ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)]))
        .get();

    final entries = <ForgivenDebtEntry>[];
    for (final row in rows) {
      final forgiveness = await _loadForgivenessInfo(shopId, row.id);
      if (forgiveness == null) continue;

      final receipt = await _receiptForSale(shopId, row.saleId);
      final customer = await (_db.select(_db.customers)
            ..where(
              (c) => c.id.equals(row.customerId) & c.shopId.equals(shopId),
            )
            ..limit(1))
          .get()
          .then((rows) => rows.firstOrNull);

      entries.add(
        ForgivenDebtEntry(
          debt: DebtMapper.fromRow(
            row,
            receiptNumber: receipt,
            isCritical: false,
          ),
          customerName: customer?.name,
          forgiveness: forgiveness,
        ),
      );
    }
    return entries;
  }

  Future<List<Debt>> listPaidDebts({
    required int shopId,
    int? customerId,
  }) async {
    final rows = await (_db.select(_db.debts)
          ..where((d) {
            var expr = d.shopId.equals(shopId) & d.status.equals('paid');
            if (customerId != null) {
              expr = expr & d.customerId.equals(customerId);
            }
            return expr;
          })
          ..orderBy([(d) => OrderingTerm.desc(d.updatedAt)]))
        .get();

    final debts = <Debt>[];
    for (final row in rows) {
      final receipt = await _receiptForSale(shopId, row.saleId);
      final customer = customerId == null
          ? await (_db.select(_db.customers)
                ..where(
                  (c) => c.id.equals(row.customerId) & c.shopId.equals(shopId),
                )
                ..limit(1))
              .get()
              .then((rows) => rows.firstOrNull)
          : null;

      debts.add(
        DebtMapper.fromRow(
          row,
          receiptNumber: receipt,
          customerName: customer?.name,
          isCritical: false,
        ),
      );
    }
    return debts;
  }

  Future<DebtForgivenessInfo?> getDebtForgivenessInfo({
    required int shopId,
    required int debtId,
  }) {
    return _loadForgivenessInfo(shopId, debtId);
  }

  Future<DebtForgivenessInfo?> _loadForgivenessInfo(
    int shopId,
    int debtId,
  ) async {
    final audit = await (_db.select(_db.auditLogs)
          ..where(
            (a) =>
                a.shopId.equals(shopId) &
                a.entityTable.equals('debts') &
                a.entityId.equals(debtId) &
                a.action.equals('debt_forgiven'),
          )
          ..orderBy([(a) => OrderingTerm.desc(a.createdAt)]))
        .getSingleOrNull();
    if (audit == null) return null;

    final oldValue = _decodeJson(audit.oldValue);
    final forgivenAmount = oldValue['amountRemaining'] as int? ?? 0;
    final userName = await _userName(audit.userId);

    return DebtForgivenessInfo(
      forgivenAt: audit.createdAt,
      reason: audit.reason?.trim().isNotEmpty == true
          ? audit.reason!.trim()
          : 'Motif non renseigné',
      forgivenAmount: forgivenAmount,
      forgivenByName: userName,
    );
  }

  Future<String?> _userName(int userId) async {
    final row = await (_db.select(_db.users)
          ..where((u) => u.id.equals(userId)))
        .getSingleOrNull();
    return row?.name;
  }

  Future<String?> _receiptForSale(int shopId, int? saleId) async {
    if (saleId == null) return null;
    final sale = await (_db.select(_db.sales)
          ..where((s) => s.id.equals(saleId) & s.shopId.equals(shopId)))
        .getSingleOrNull();
    return sale?.receiptNumber;
  }

  bool _isCritical(db.Debt row) {
    if (row.amountPaid > 0) return false;
    const thirtyDaysMs = 30 * 24 * 60 * 60 * 1000;
    return nowMs() - row.createdAt >= thirtyDaysMs;
  }
}
