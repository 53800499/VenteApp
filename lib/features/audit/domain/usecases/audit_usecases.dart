import '../entities/audit_entities.dart';
import '../repositories/audit_repository.dart';

class ListAuditLogs {
  const ListAuditLogs(this._repository);

  final AuditRepository _repository;

  Future<AuditLogListResult> call({
    required int shopId,
    required AuditListQuery query,
  }) =>
      _repository.listLogs(shopId: shopId, query: query);
}

class GetAuditLogDetail {
  const GetAuditLogDetail(this._repository);

  final AuditRepository _repository;

  Future<AuditLogDetail> call({
    required int shopId,
    required int id,
  }) =>
      _repository.getLogDetail(shopId: shopId, id: id);
}

class GetAuditFilterOptions {
  const GetAuditFilterOptions(this._repository);

  final AuditRepository _repository;

  Future<AuditFilterOptions> call() => _repository.getFilterOptions();
}

class ExportAuditLogs {
  const ExportAuditLogs(this._repository);

  final AuditRepository _repository;

  Future<AuditExportResult> call({
    required int shopId,
    required AuditListQuery query,
  }) =>
      _repository.exportLogs(shopId: shopId, query: query);
}

class GetEntityAuditHistory {
  const GetEntityAuditHistory(this._repository);

  final AuditRepository _repository;

  Future<AuditEntityHistory> call({
    required int shopId,
    required String entityTable,
    required int entityId,
  }) =>
      _repository.getEntityHistory(
        shopId: shopId,
        entityTable: entityTable,
        entityId: entityId,
      );
}
