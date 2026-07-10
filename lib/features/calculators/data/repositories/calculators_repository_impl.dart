import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import '../../../../../core/database/app_database.dart' as db;
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/remote_api_guard.dart';
import '../../../../../core/sync/local_write_sync_recorder.dart';
import '../../../../../core/sync/sync_constants.dart';
import '../../../../../core/utils/time.dart';
import '../../domain/entities/calculator_entities.dart';
import '../../domain/repositories/calculators_repository.dart';
import '../datasources/local/calculators_local_datasource.dart';
import '../datasources/remote/calculators_remote_datasource.dart';

class CalculatorsRepositoryImpl implements CalculatorsRepository {
  CalculatorsRepositoryImpl({
    required CalculatorsLocalDatasource local,
    required CalculatorsRemoteDatasource remote,
    required RemoteApiGuard apiGuard,
    required LocalWriteSyncRecorder recorder,
  })  : _local = local,
        _remote = remote,
        _apiGuard = apiGuard,
        _recorder = recorder;

  final CalculatorsLocalDatasource _local;
  final CalculatorsRemoteDatasource _remote;
  final RemoteApiGuard _apiGuard;
  final LocalWriteSyncRecorder _recorder;

  @override
  Future<bool> isModuleEnabled({required int shopId}) async {
    final status = await _local.getModuleStatus(shopId, 'CALCULATORS');
    return status?.enabled ?? false;
  }

  @override
  Future<void> toggleModule({required int shopId, required bool enabled}) async {
    await _local.saveModuleStatus(shopId, 'CALCULATORS', enabled);
    try {
      await _apiGuard.ensureReady();
      await _remote.toggleModule(enabled);
    } catch (_) {
      // Offline-first: on enregistre en local et on laisse la sync synchroniser
      // le statut ou le renvoyer plus tard. Comme c'est un toggle d'activation,
      // on peut aussi le pousser en file de sync si souhaité.
      await _recorder.record(
        shopId: shopId,
        entityTable: SyncEntityTable.tenantModules,
        recordId: 1, // dummy record ID for module activation singleton per shop
        operation: SyncOperation.update,
        payload: {'enabled': enabled},
      );
    }
  }

  @override
  Future<List<CalculatorProductData>> getProductConfigs({required int shopId}) async {
    final list = await _local.getProductConfigs(shopId);
    return list.map(_mapProductConfigRow).toList();
  }

  @override
  Future<CalculatorProductData?> getProductConfig({
    required int shopId,
    required int productId,
  }) async {
    final row = await _local.getProductConfig(shopId, productId);
    return row != null ? _mapProductConfigRow(row) : null;
  }

  @override
  Future<void> saveProductConfig({required CalculatorProductData config}) async {
    final timestamp = nowMs();
    final companion = db.CalculatorProductDataCompanion(
      shopId: drift.Value(config.shopId),
      productId: drift.Value(config.productId),
      calculatorType: drift.Value(config.calculatorType),
      metadata: drift.Value(jsonEncode(config.metadata)),
      createdAt: drift.Value(config.createdAt > 0 ? config.createdAt : timestamp),
      updatedAt: drift.Value(timestamp),
    );

    await _local.saveProductConfig(companion);

    // Fetch the saved ID to record in sync queue
    final saved = await _local.getProductConfig(config.shopId, config.productId);
    if (saved != null) {
      await _recorder.record(
        shopId: config.shopId,
        entityTable: SyncEntityTable.calculatorProductData,
        recordId: saved.id,
        operation: SyncOperation.update,
        payload: {
          'productId': config.productId,
          'calculatorType': config.calculatorType,
          'metadata': config.metadata,
        },
        localVersion: saved.version,
      );
    }
  }

  @override
  Future<List<CalculatorHistoryEntry>> getHistory({required int shopId}) async {
    final list = await _local.getHistory(shopId);
    return list.map(_mapHistoryRow).toList();
  }

  @override
  Future<CalculatorHistoryEntry> saveCalculation({required CalculatorHistoryEntry entry}) async {
    final timestamp = nowMs();
    final companion = db.CalculatorHistoryCompanion.insert(
      shopId: entry.shopId,
      calculatorType: entry.calculatorType,
      inputData: jsonEncode(entry.input),
      resultData: jsonEncode(entry.result),
      isFavorite: drift.Value(entry.isFavorite),
      label: drift.Value(entry.label),
      createdAt: entry.createdAt > 0 ? entry.createdAt : timestamp,
      createdBy: entry.createdBy,
    );

    final row = await _local.insertHistory(companion);
    final savedEntry = _mapHistoryRow(row);

    // Queue in sync_queue for upload
    await _recorder.record(
      shopId: entry.shopId,
      entityTable: SyncEntityTable.calculatorHistory,
      recordId: row.id,
      operation: SyncOperation.create,
      payload: {
        'calculatorType': entry.calculatorType,
        'input': entry.input,
        'result': entry.result,
        'isFavorite': entry.isFavorite,
        'label': entry.label,
        'createdAt': savedEntry.createdAt,
        'createdBy': entry.createdBy,
      },
      localVersion: row.version,
    );

    return savedEntry;
  }

  @override
  Future<void> syncFromRemote({required int shopId}) async {
    try {
      await _apiGuard.ensureReady();

      // Pull status
      final isEnabled = await _remote.fetchModuleStatus();
      await _local.saveModuleStatus(shopId, 'CALCULATORS', isEnabled);

      if (!isEnabled) return;

      // Pull configs
      final remoteConfigs = await _remote.fetchProductConfigs();
      for (final raw in remoteConfigs) {
        final productId = raw['productId'] as int;
        final calculatorType = raw['calculatorType'] as String;
        final metadata = raw['metadata'] as Map<String, dynamic>;
        final serverId = raw['serverId'] as String?;
        final version = raw['version'] as int? ?? 1;
        final createdAt = raw['createdAt'] as int? ?? nowMs();
        final updatedAt = raw['updatedAt'] as int? ?? nowMs();

        await _local.upsertFromRemoteProductConfig(
          db.CalculatorProductDataCompanion(
            shopId: drift.Value(shopId),
            productId: drift.Value(productId),
            calculatorType: drift.Value(calculatorType),
            metadata: drift.Value(jsonEncode(metadata)),
            version: drift.Value(version),
            serverId: drift.Value(serverId),
            createdAt: drift.Value(createdAt),
            updatedAt: drift.Value(updatedAt),
          ),
        );
      }

      // Pull history
      final remoteHistory = await _remote.fetchHistory();
      for (final raw in remoteHistory) {
        final calculatorType = raw['calculatorType'] as String;
        final input = raw['input'] as Map<String, dynamic>;
        final result = raw['result'] as Map<String, dynamic>;
        final isFavorite = raw['isFavorite'] as bool? ?? false;
        final label = raw['label'] as String?;
        final createdAt = raw['createdAt'] as int;
        final createdBy = raw['createdBy'] as int;
        final serverId = raw['serverId'] as String?;
        final version = raw['version'] as int? ?? 1;

        await _local.upsertFromRemoteHistory(
          db.CalculatorHistoryCompanion(
            shopId: drift.Value(shopId),
            calculatorType: drift.Value(calculatorType),
            inputData: drift.Value(jsonEncode(input)),
            resultData: drift.Value(jsonEncode(result)),
            isFavorite: drift.Value(isFavorite),
            label: drift.Value(label),
            createdAt: drift.Value(createdAt),
            createdBy: drift.Value(createdBy),
            version: drift.Value(version),
            serverId: drift.Value(serverId),
          ),
        );
      }
    } catch (_) {
      // Pull asynchrone optionnel
    }
  }

  // --- Mappers ---

  CalculatorProductData _mapProductConfigRow(db.CalculatorProductDataData row) {
    return CalculatorProductData(
      id: row.id,
      shopId: row.shopId,
      productId: row.productId,
      calculatorType: row.calculatorType,
      metadata: jsonDecode(row.metadata) as Map<String, dynamic>,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      version: row.version,
      serverId: row.serverId,
    );
  }

  CalculatorHistoryEntry _mapHistoryRow(db.CalculatorHistoryData row) {
    return CalculatorHistoryEntry(
      id: row.id,
      shopId: row.shopId,
      calculatorType: row.calculatorType,
      input: jsonDecode(row.inputData) as Map<String, dynamic>,
      result: jsonDecode(row.resultData) as Map<String, dynamic>,
      isFavorite: row.isFavorite,
      label: row.label,
      createdAt: row.createdAt,
      createdBy: row.createdBy,
      version: row.version,
      serverId: row.serverId,
    );
  }
}
