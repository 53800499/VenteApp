import '../../../../core/errors/failures.dart';
import '../../../../core/network/remote_api_runner.dart';
import '../../domain/entities/audit_entities.dart';
import '../../domain/repositories/audit_repository.dart';
import '../../domain/services/audit_label_service.dart';
import '../datasources/local/audit_local_datasource.dart';
import '../datasources/remote/audit_remote_datasource.dart';
import '../mappers/audit_mapper.dart';

class AuditRepositoryImpl implements AuditRepository {
  AuditRepositoryImpl({
    required AuditLocalDatasource local,
    required AuditRemoteDatasource remote,
    required RemoteApiRunner apiRunner,
    required AuditMapper mapper,
    required AuditLabelService labels,
  })  : _local = local,
        _remote = remote,
        _apiRunner = apiRunner,
        _mapper = mapper,
        _labels = labels;

  final AuditLocalDatasource _local;
  final AuditRemoteDatasource _remote;
  final RemoteApiRunner _apiRunner;
  final AuditMapper _mapper;
  final AuditLabelService _labels;

  @override
  Future<AuditLogListResult> listLogs({
    required int shopId,
    required AuditListQuery query,
  }) {
    return _apiRunner.runOnlinePreferredRead(
      remote: () async {
        final dto = await _remote.listLogs(query);
        return _mapper.listFromApi(dto);
      },
      localFallback: () => _local.list(shopId: shopId, query: query),
    );
  }

  @override
  Future<AuditLogDetail> getLogDetail({
    required int shopId,
    required int id,
  }) {
    return _apiRunner.runOnlinePreferredRead(
      remote: () async {
        final dto = await _remote.getDetail(id);
        return _mapper.detailFromApi(dto);
      },
      localFallback: () async {
        final detail = await _local.findById(shopId: shopId, id: id);
        if (detail == null) {
          throw const NotFoundFailure('Entrée d\'audit introuvable.');
        }
        return detail;
      },
    );
  }

  @override
  Future<AuditFilterOptions> getFilterOptions() {
    return _apiRunner.runOnlinePreferredRead(
      remote: () async {
        final dto = await _remote.getFilterOptions();
        return _mapper.filtersFromApi(dto);
      },
      localFallback: () async => _labels.listFilterOptions(),
    );
  }

  @override
  Future<AuditExportResult> exportLogs({
    required int shopId,
    required AuditListQuery query,
  }) {
    return _apiRunner.runOnlinePreferredRead(
      remote: () async {
        final dto = await _remote.exportLogs(query);
        return _mapper.exportFromApi(dto);
      },
      localFallback: () => _local.export(shopId: shopId, query: query),
    );
  }

  @override
  Future<AuditEntityHistory> getEntityHistory({
    required int shopId,
    required String entityTable,
    required int entityId,
  }) {
    return _apiRunner.runOnlinePreferredRead(
      remote: () async {
        final dto = await _remote.getEntityHistory(
          entityTable: entityTable,
          entityId: entityId,
        );
        return _mapper.entityHistoryFromApi(dto);
      },
      localFallback: () async {
        final timeline = await _local.listByEntity(
          shopId: shopId,
          entityTable: entityTable,
          entityId: entityId,
        );
        return AuditEntityHistory(
          entityTable: entityTable,
          entityId: entityId,
          timeline: timeline,
        );
      },
    );
  }
}
