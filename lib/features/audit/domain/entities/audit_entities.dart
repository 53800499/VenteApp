import 'package:equatable/equatable.dart';

class AuditLogItem extends Equatable {
  const AuditLogItem({
    required this.id,
    required this.action,
    required this.actionLabel,
    required this.module,
    required this.moduleLabel,
    required this.userId,
    this.userName,
    required this.entityId,
    required this.entityTable,
    this.reason,
    required this.createdAt,
    required this.hasDiff,
  });

  final int id;
  final String action;
  final String actionLabel;
  final String module;
  final String moduleLabel;
  final int userId;
  final String? userName;
  final int entityId;
  final String entityTable;
  final String? reason;
  final int createdAt;
  final bool hasDiff;

  @override
  List<Object?> get props => [
        id,
        action,
        actionLabel,
        module,
        moduleLabel,
        userId,
        userName,
        entityId,
        entityTable,
        reason,
        createdAt,
        hasDiff,
      ];
}

class AuditLogDetail extends AuditLogItem {
  const AuditLogDetail({
    required super.id,
    required super.action,
    required super.actionLabel,
    required super.module,
    required super.moduleLabel,
    required super.userId,
    super.userName,
    required super.entityId,
    required super.entityTable,
    super.reason,
    required super.createdAt,
    required super.hasDiff,
    this.oldValue,
    this.newValue,
  });

  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;

  @override
  List<Object?> get props => [...super.props, oldValue, newValue];
}

class AuditLogPagination extends Equatable {
  const AuditLogPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.hasMore,
  });

  final int page;
  final int limit;
  final int total;
  final bool hasMore;

  @override
  List<Object?> get props => [page, limit, total, hasMore];
}

class AuditLogListResult extends Equatable {
  const AuditLogListResult({
    required this.items,
    required this.pagination,
  });

  final List<AuditLogItem> items;
  final AuditLogPagination pagination;

  @override
  List<Object?> get props => [items, pagination];
}

class AuditFilterOption extends Equatable {
  const AuditFilterOption({required this.code, required this.label});

  final String code;
  final String label;

  @override
  List<Object?> get props => [code, label];
}

class AuditFilterOptions extends Equatable {
  const AuditFilterOptions({
    required this.modules,
    required this.actions,
  });

  final List<AuditFilterOption> modules;
  final List<AuditFilterOption> actions;

  @override
  List<Object?> get props => [modules, actions];
}

class AuditExportResult extends Equatable {
  const AuditExportResult({
    required this.exportedAt,
    required this.shopId,
    required this.total,
    required this.entries,
    required this.pdfHint,
  });

  final int exportedAt;
  final int shopId;
  final int total;
  final List<AuditLogDetail> entries;
  final String pdfHint;

  @override
  List<Object?> get props =>
      [exportedAt, shopId, total, entries, pdfHint];
}

class AuditEntityHistory extends Equatable {
  const AuditEntityHistory({
    required this.entityTable,
    required this.entityId,
    required this.timeline,
  });

  final String entityTable;
  final int entityId;
  final List<AuditLogDetail> timeline;

  @override
  List<Object?> get props => [entityTable, entityId, timeline];
}

class AuditListQuery extends Equatable {
  const AuditListQuery({
    this.module,
    this.action,
    this.userId,
    this.entityTable,
    this.entityId,
    this.from,
    this.to,
    this.page = 1,
    this.limit = 50,
  });

  final String? module;
  final String? action;
  final int? userId;
  final String? entityTable;
  final int? entityId;
  final int? from;
  final int? to;
  final int page;
  final int limit;

  AuditListQuery copyWith({
    String? module,
    String? action,
    int? userId,
    String? entityTable,
    int? entityId,
    int? from,
    int? to,
    int? page,
    int? limit,
    bool clearModule = false,
    bool clearAction = false,
    bool clearUserId = false,
    bool clearEntityTable = false,
    bool clearEntityId = false,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return AuditListQuery(
      module: clearModule ? null : (module ?? this.module),
      action: clearAction ? null : (action ?? this.action),
      userId: clearUserId ? null : (userId ?? this.userId),
      entityTable:
          clearEntityTable ? null : (entityTable ?? this.entityTable),
      entityId: clearEntityId ? null : (entityId ?? this.entityId),
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }

  @override
 List<Object?> get props =>
      [module, action, userId, entityTable, entityId, from, to, page, limit];
}
