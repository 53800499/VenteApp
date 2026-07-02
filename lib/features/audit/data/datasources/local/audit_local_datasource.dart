import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart';
import '../../../domain/entities/audit_entities.dart';
import '../../mappers/audit_mapper.dart';

class AuditLocalDatasource {
  AuditLocalDatasource(this._db, this._mapper);

  final AppDatabase _db;
  final AuditMapper _mapper;

  static const exportMaxEntries = 5000;

  Future<AuditLogListResult> list({
    required int shopId,
    required AuditListQuery query,
  }) async {
    final rows = await _fetchRows(shopId: shopId, query: query);
    final total = rows.length;
    final offset = (query.page - 1) * query.limit;
    final pageRows = rows.skip(offset).take(query.limit).toList();
    final userNames = await _userNamesFor(
      pageRows.map((r) => r.userId).toSet(),
    );

    return AuditLogListResult(
      items: pageRows
          .map(
            (row) => _mapper
                .detailFromLocal(
                  id: row.id,
                  action: row.action,
                  module: row.module,
                  userId: row.userId,
                  userName: userNames[row.userId],
                  entityId: row.entityId,
                  entityTable: row.entityTable,
                  reason: row.reason,
                  createdAt: row.createdAt,
                  oldValueJson: row.oldValue,
                  newValueJson: row.newValue,
                )
                .copyAsItem(),
          )
          .toList(),
      pagination: AuditLogPagination(
        page: query.page,
        limit: query.limit,
        total: total,
        hasMore: offset + pageRows.length < total,
      ),
    );
  }

  Future<AuditLogDetail?> findById({
    required int shopId,
    required int id,
  }) async {
    final row = await (_db.select(_db.auditLogs)
          ..where((a) => a.shopId.equals(shopId) & a.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;

    final userName = await _userName(row.userId);
    return _mapper.detailFromLocal(
      id: row.id,
      action: row.action,
      module: row.module,
      userId: row.userId,
      userName: userName,
      entityId: row.entityId,
      entityTable: row.entityTable,
      reason: row.reason,
      createdAt: row.createdAt,
      oldValueJson: row.oldValue,
      newValueJson: row.newValue,
    );
  }

  Future<List<AuditLogDetail>> listByEntity({
    required int shopId,
    required String entityTable,
    required int entityId,
  }) async {
    final rows = await (_db.select(_db.auditLogs)
          ..where(
            (a) =>
                a.shopId.equals(shopId) &
                a.entityTable.equals(entityTable) &
                a.entityId.equals(entityId),
          )
          ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
        .get();

    final userNames = await _userNamesFor(rows.map((r) => r.userId).toSet());
    return rows
        .map(
          (row) => _mapper.detailFromLocal(
            id: row.id,
            action: row.action,
            module: row.module,
            userId: row.userId,
            userName: userNames[row.userId],
            entityId: row.entityId,
            entityTable: row.entityTable,
            reason: row.reason,
            createdAt: row.createdAt,
            oldValueJson: row.oldValue,
            newValueJson: row.newValue,
          ),
        )
        .toList();
  }

  Future<AuditExportResult> export({
    required int shopId,
    required AuditListQuery query,
  }) async {
    final rows = await _fetchRows(
      shopId: shopId,
      query: query.copyWith(page: 1, limit: exportMaxEntries),
    );
    final limited = rows.take(exportMaxEntries).toList();
    final userNames = await _userNamesFor(limited.map((r) => r.userId).toSet());

    return AuditExportResult(
      exportedAt: DateTime.now().millisecondsSinceEpoch,
      shopId: shopId,
      total: limited.length,
      entries: limited
          .map(
            (row) => _mapper.detailFromLocal(
              id: row.id,
              action: row.action,
              module: row.module,
              userId: row.userId,
              userName: userNames[row.userId],
              entityId: row.entityId,
              entityTable: row.entityTable,
              reason: row.reason,
              createdAt: row.createdAt,
              oldValueJson: row.oldValue,
              newValueJson: row.newValue,
            ),
          )
          .toList(),
      pdfHint:
          'Export local — générez un PDF ou partagez le JSON depuis l\'application.',
    );
  }

  Future<List<AuditLog>> _fetchRows({
    required int shopId,
    required AuditListQuery query,
  }) async {
    final q = _db.select(_db.auditLogs)
      ..where((a) {
        Expression<bool> expr = a.shopId.equals(shopId);
        if (query.module != null) {
          expr = expr & a.module.equals(query.module!);
        }
        if (query.action != null) {
          expr = expr & a.action.equals(query.action!);
        }
        if (query.userId != null) {
          expr = expr & a.userId.equals(query.userId!);
        }
        if (query.entityTable != null) {
          expr = expr & a.entityTable.equals(query.entityTable!);
        }
        if (query.entityId != null) {
          expr = expr & a.entityId.equals(query.entityId!);
        }
        if (query.from != null) {
          expr = expr & a.createdAt.isBiggerOrEqualValue(query.from!);
        }
        if (query.to != null) {
          expr = expr & a.createdAt.isSmallerOrEqualValue(query.to!);
        }
        return expr;
      })
      ..orderBy([(a) => OrderingTerm.desc(a.createdAt)]);

    return q.get();
  }

  Future<String?> _userName(int userId) async {
    final row = await (_db.select(_db.users)
          ..where((u) => u.id.equals(userId)))
        .getSingleOrNull();
    return row?.name;
  }

  Future<Map<int, String>> _userNamesFor(Set<int> userIds) async {
    if (userIds.isEmpty) return {};
    final rows = await (_db.select(_db.users)
          ..where((u) => u.id.isIn(userIds.toList())))
        .get();
    return {for (final u in rows) u.id: u.name};
  }
}

extension on AuditLogDetail {
  AuditLogItem copyAsItem() {
    return AuditLogItem(
      id: id,
      action: action,
      actionLabel: actionLabel,
      module: module,
      moduleLabel: moduleLabel,
      userId: userId,
      userName: userName,
      entityId: entityId,
      entityTable: entityTable,
      reason: reason,
      createdAt: createdAt,
      hasDiff: hasDiff,
    );
  }
}