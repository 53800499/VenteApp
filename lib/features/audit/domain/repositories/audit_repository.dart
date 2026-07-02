import '../entities/audit_entities.dart';

abstract class AuditRepository {
  Future<AuditLogListResult> listLogs({
    required int shopId,
    required AuditListQuery query,
  });

  Future<AuditLogDetail> getLogDetail({
    required int shopId,
    required int id,
  });

  Future<AuditFilterOptions> getFilterOptions();

  Future<AuditExportResult> exportLogs({
    required int shopId,
    required AuditListQuery query,
  });

  Future<AuditEntityHistory> getEntityHistory({
    required int shopId,
    required String entityTable,
    required int entityId,
  });
}
