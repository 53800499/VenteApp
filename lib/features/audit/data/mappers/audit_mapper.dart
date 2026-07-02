import 'dart:convert';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_query_limits.dart';
import '../../domain/entities/audit_entities.dart';
import '../../domain/services/audit_label_service.dart';
import '../models/audit_api_models.dart';

class AuditMapper {
  const AuditMapper(this._labels);

  final AuditLabelService _labels;

  AuditLogItem itemFromApi(AuditLogItemApiDto dto) {
    return AuditLogItem(
      id: dto.id,
      action: dto.action,
      actionLabel: dto.actionLabel,
      module: dto.module,
      moduleLabel: dto.moduleLabel,
      userId: dto.userId,
      userName: dto.userName,
      entityId: dto.entityId,
      entityTable: dto.entityTable,
      reason: dto.reason,
      createdAt: dto.createdAt,
      hasDiff: dto.hasDiff,
    );
  }

  AuditLogDetail detailFromApi(AuditLogDetailApiDto dto) {
    return AuditLogDetail(
      id: dto.id,
      action: dto.action,
      actionLabel: dto.actionLabel,
      module: dto.module,
      moduleLabel: dto.moduleLabel,
      userId: dto.userId,
      userName: dto.userName,
      entityId: dto.entityId,
      entityTable: dto.entityTable,
      reason: dto.reason,
      createdAt: dto.createdAt,
      hasDiff: dto.hasDiff,
      oldValue: dto.oldValue,
      newValue: dto.newValue,
    );
  }

  AuditLogListResult listFromApi(AuditLogListApiDto dto) {
    return AuditLogListResult(
      items: dto.items.map(itemFromApi).toList(),
      pagination: AuditLogPagination(
        page: dto.page,
        limit: dto.limit,
        total: dto.total,
        hasMore: dto.hasMore,
      ),
    );
  }

  AuditFilterOptions filtersFromApi(AuditFilterOptionsApiDto dto) {
    return AuditFilterOptions(
      modules: dto.modules
          .map((m) => AuditFilterOption(code: m.code, label: m.label))
          .toList(),
      actions: dto.actions
          .map((a) => AuditFilterOption(code: a.code, label: a.label))
          .toList(),
    );
  }

  AuditExportResult exportFromApi(AuditExportApiDto dto) {
    return AuditExportResult(
      exportedAt: dto.exportedAt,
      shopId: dto.shopId,
      total: dto.total,
      entries: dto.entries.map(detailFromApi).toList(),
      pdfHint: dto.pdfHint,
    );
  }

  AuditEntityHistory entityHistoryFromApi(AuditEntityHistoryApiDto dto) {
    return AuditEntityHistory(
      entityTable: dto.entityTable,
      entityId: dto.entityId,
      timeline: dto.timeline.map(detailFromApi).toList(),
    );
  }

  AuditLogDetail detailFromLocal({
    required int id,
    required String action,
    required String module,
    required int userId,
    String? userName,
    required int entityId,
    required String entityTable,
    String? reason,
    required int createdAt,
    String? oldValueJson,
    String? newValueJson,
  }) {
    final oldValue = _decodeJsonMap(oldValueJson);
    final newValue = _decodeJsonMap(newValueJson);
    return AuditLogDetail(
      id: id,
      action: action,
      actionLabel: _labels.actionLabel(action),
      module: module,
      moduleLabel: _labels.moduleLabel(module),
      userId: userId,
      userName: userName,
      entityId: entityId,
      entityTable: entityTable,
      reason: reason,
      createdAt: createdAt,
      hasDiff: oldValue != null || newValue != null,
      oldValue: oldValue,
      newValue: newValue,
    );
  }

  Map<String, String> queryToApi(AuditListQuery query) {
    final limitMax = query.limit > AppConstants.apiListLimitMax
        ? AppConstants.apiAuditExportLimit
        : AppConstants.apiListLimitMax;
    return {
      if (query.module != null) 'module': query.module!,
      if (query.action != null) 'action': query.action!,
      if (query.userId != null) 'userId': '${query.userId}',
      if (query.entityTable != null) 'entityTable': query.entityTable!,
      if (query.entityId != null) 'entityId': '${query.entityId}',
      if (query.from != null) 'from': '${query.from}',
      if (query.to != null) 'to': '${query.to}',
      'page': '${ApiQueryLimits.clampPage(query.page)}',
      'limit': '${ApiQueryLimits.clampLimit(query.limit, max: limitMax)}',
    };
  }

  Map<String, dynamic>? _decodeJsonMap(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {'raw': raw};
  }
}
