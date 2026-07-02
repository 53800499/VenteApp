class AuditLogItemApiDto {
  const AuditLogItemApiDto({
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

  factory AuditLogItemApiDto.fromJson(Map<String, dynamic> json) {
    return AuditLogItemApiDto(
      id: json['id'] as int,
      action: json['action'] as String,
      actionLabel: json['actionLabel'] as String,
      module: json['module'] as String,
      moduleLabel: json['moduleLabel'] as String,
      userId: json['userId'] as int,
      userName: json['userName'] as String?,
      entityId: json['entityId'] as int,
      entityTable: json['entityTable'] as String,
      reason: json['reason'] as String?,
      createdAt: json['createdAt'] as int,
      hasDiff: json['hasDiff'] as bool? ?? false,
    );
  }
}

class AuditLogDetailApiDto extends AuditLogItemApiDto {
  const AuditLogDetailApiDto({
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

  factory AuditLogDetailApiDto.fromJson(Map<String, dynamic> json) {
    return AuditLogDetailApiDto(
      id: json['id'] as int,
      action: json['action'] as String,
      actionLabel: json['actionLabel'] as String,
      module: json['module'] as String,
      moduleLabel: json['moduleLabel'] as String,
      userId: json['userId'] as int,
      userName: json['userName'] as String?,
      entityId: json['entityId'] as int,
      entityTable: json['entityTable'] as String,
      reason: json['reason'] as String?,
      createdAt: json['createdAt'] as int,
      hasDiff: json['hasDiff'] as bool? ?? false,
      oldValue: _parseJsonMap(json['oldValue']),
      newValue: _parseJsonMap(json['newValue']),
    );
  }
}

class AuditLogListApiDto {
  const AuditLogListApiDto({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.hasMore,
  });

  final List<AuditLogItemApiDto> items;
  final int page;
  final int limit;
  final int total;
  final bool hasMore;

  factory AuditLogListApiDto.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'] as Map<String, dynamic>? ?? json;
    return AuditLogListApiDto(
      items: (json['items'] as List<dynamic>)
          .map(
            (e) => AuditLogItemApiDto.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      page: pagination['page'] as int? ?? 1,
      limit: pagination['limit'] as int? ?? 50,
      total: pagination['total'] as int? ?? 0,
      hasMore: pagination['hasMore'] as bool? ?? false,
    );
  }
}

class AuditFilterOptionApiDto {
  const AuditFilterOptionApiDto({required this.code, required this.label});

  final String code;
  final String label;

  factory AuditFilterOptionApiDto.fromJson(Map<String, dynamic> json) {
    return AuditFilterOptionApiDto(
      code: json['code'] as String,
      label: json['label'] as String,
    );
  }
}

class AuditFilterOptionsApiDto {
  const AuditFilterOptionsApiDto({
    required this.modules,
    required this.actions,
  });

  final List<AuditFilterOptionApiDto> modules;
  final List<AuditFilterOptionApiDto> actions;

  factory AuditFilterOptionsApiDto.fromJson(Map<String, dynamic> json) {
    return AuditFilterOptionsApiDto(
      modules: (json['modules'] as List<dynamic>)
          .map(
            (e) => AuditFilterOptionApiDto.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      actions: (json['actions'] as List<dynamic>)
          .map(
            (e) => AuditFilterOptionApiDto.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class AuditExportApiDto {
  const AuditExportApiDto({
    required this.exportedAt,
    required this.shopId,
    required this.total,
    required this.entries,
    required this.pdfHint,
  });

  final int exportedAt;
  final int shopId;
  final int total;
  final List<AuditLogDetailApiDto> entries;
  final String pdfHint;

  factory AuditExportApiDto.fromJson(Map<String, dynamic> json) {
    return AuditExportApiDto(
      exportedAt: json['exportedAt'] as int,
      shopId: json['shopId'] as int,
      total: json['total'] as int,
      entries: (json['entries'] as List<dynamic>)
          .map(
            (e) => AuditLogDetailApiDto.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      pdfHint: json['pdfHint'] as String? ?? '',
    );
  }
}

class AuditEntityHistoryApiDto {
  const AuditEntityHistoryApiDto({
    required this.entityTable,
    required this.entityId,
    required this.timeline,
  });

  final String entityTable;
  final int entityId;
  final List<AuditLogDetailApiDto> timeline;

  factory AuditEntityHistoryApiDto.fromJson(Map<String, dynamic> json) {
    return AuditEntityHistoryApiDto(
      entityTable: json['entityTable'] as String,
      entityId: json['entityId'] as int,
      timeline: (json['timeline'] as List<dynamic>)
          .map(
            (e) => AuditLogDetailApiDto.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

Map<String, dynamic>? _parseJsonMap(Object? value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  return null;
}
