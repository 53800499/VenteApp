import 'dart:async';



import 'package:connectivity_plus/connectivity_plus.dart';



import '../errors/failures.dart';

import '../network/network_info.dart';

import '../network/remote_api_guard.dart';

import '../../features/settings/data/datasources/local/settings_local_datasource.dart';
import 'remote_sync_port.dart';

import 'sync_policy.dart';

import 'sync_queue_datasource.dart';

import 'sync_queue_processor.dart';

import 'sync_snapshot.dart';



/// Synchronisation cloud asynchrone — 3 couches (BDD §3.2) :

///

/// 1. **V1** : écriture locale Drift uniquement (`cloudSyncEnabled = false`)

/// 2. **V2** : + file `sync_queue` + pull/push cloud parallèle si réseau

/// 3. **V3** : + scope `shop_id` par boutique active (multi-boutiques)

///

/// [RG-SYNC-02] : jamais bloquant pour l'UI.

class SyncService {

  SyncService({

    required Connectivity connectivity,

    required NetworkInfo networkInfo,

    required RemoteApiGuard apiGuard,

    required SyncPolicy policy,

    required SyncQueueDatasource queue,

    required SyncQueueProcessor processor,

    required List<RemoteSyncPort> ports,

    SettingsLocalDatasource? settingsLocal,

  })  : _connectivity = connectivity,

        _networkInfo = networkInfo,

        _apiGuard = apiGuard,

        _policy = policy,

        _queue = queue,

        _processor = processor,

        _ports = ports,

        _settingsLocal = settingsLocal;



  final Connectivity _connectivity;

  final NetworkInfo _networkInfo;

  final RemoteApiGuard _apiGuard;

  final SyncPolicy _policy;

  final SyncQueueDatasource _queue;

  final SyncQueueProcessor _processor;

  final List<RemoteSyncPort> _ports;
  final SettingsLocalDatasource? _settingsLocal;



  final _snapshotController = StreamController<SyncSnapshot>.broadcast();

  Stream<SyncSnapshot> get snapshots => _snapshotController.stream;



  SyncSnapshot _snapshot = const SyncSnapshot.idle();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  Timer? _debounce;

  int? _shopId;

  var _running = false;

  var _started = false;



  SyncSnapshot get currentSnapshot => _snapshot;



  void start() {

    if (_started) return;

    _started = true;

    _emit(_snapshot);

    _connectivitySub = _connectivity.onConnectivityChanged.listen((_) {

      _scheduleSync();

    });

    _scheduleSync();

  }



  void scheduleSync({required int shopId}) {

    _shopId = shopId;

    _scheduleSync();

  }



  void clearShop() {

    _shopId = null;

    _emit(const SyncSnapshot.idle());

  }



  void dispose() {

    _debounce?.cancel();

    _connectivitySub?.cancel();

    _snapshotController.close();

  }



  void _scheduleSync() {

    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () {

      unawaited(_runSyncCycle());

    });

  }



  Future<void> _runSyncCycle() async {
    if (_running) return;

    final shopId = _shopId;
    if (shopId == null) return;

    final context = await _policy.resolve(shopId: shopId);
    var pendingCount = await _queue.countPending(shopId: shopId);
    final conflictCount = await _queue.countConflicts(shopId: shopId);

    if (!context.shouldRunCloudPull) {
      _emit(
        SyncSnapshot(
          phase: SyncRunPhase.idle,
          tier: context.tier,
          cloudSyncEnabled: context.cloudSyncEnabled,
          indicatorState: SyncIndicatorState.disabled,
          pendingQueueCount: pendingCount,
          shopId: shopId,
        ),
      );
      return;
    }

    var indicator = _resolveIndicator(
      pendingCount: pendingCount,
      conflictCount: conflictCount,
    );

    if (!await _networkInfo.isConnected) {
      _emit(
        SyncSnapshot(
          phase: SyncRunPhase.idle,
          tier: context.tier,
          cloudSyncEnabled: true,
          indicatorState: indicator,
          pendingQueueCount: pendingCount,
          shopId: shopId,
          blockReason: 'Hors ligne — synchronisation à la reconnexion.',
        ),
      );
      return;
    }

    Failure? apiFailure;
    try {
      await _apiGuard.ensureReady();
    } on Failure catch (error) {
      apiFailure = error;
    } catch (error) {
      apiFailure = NetworkFailure('$error');
    }

    if (_ports.isEmpty && apiFailure != null) {
      _emit(
        SyncSnapshot(
          phase: SyncRunPhase.idle,
          tier: context.tier,
          cloudSyncEnabled: true,
          indicatorState: indicator,
          pendingQueueCount: pendingCount,
          shopId: shopId,
          blockReason: apiFailure.message,
        ),
      );
      return;
    }

    _running = true;
    _emit(
      _snapshot.copyWith(
        phase: SyncRunPhase.running,
        tier: context.tier,
        cloudSyncEnabled: true,
        shopId: shopId,
        pendingQueueCount: pendingCount,
        indicatorState: indicator,
        blockReason: apiFailure?.message,
        clearBlockReason: apiFailure == null,
      ),
    );

    var results = const <SyncModuleResult>[];
    if (apiFailure == null && _ports.isNotEmpty) {
      results = await Future.wait(
        _ports.map((port) async {
          try {
            await port.syncFromRemote(shopId: shopId);
            return SyncModuleResult(module: port.moduleName, success: true);
          } on Failure catch (error) {
            return SyncModuleResult(
              module: port.moduleName,
              success: false,
              errorMessage: error.message,
            );
          } catch (error) {
            return SyncModuleResult(
              module: port.moduleName,
              success: false,
              errorMessage: error.toString(),
            );
          }
        }),
      );
    }

    SyncQueueProcessResult? queueResult;
    if (context.shouldUseSyncQueue && apiFailure == null) {
      try {
        queueResult = await _processor.process(shopId: shopId);
      } on Failure catch (error) {
        apiFailure = error;
      }
    }

    pendingCount = await _queue.countPending(shopId: shopId);
    final conflictsAfter = await _queue.countConflicts(shopId: shopId);
    final hasFailures = results.any((r) => !r.success);

    String? blockReason = apiFailure?.message;
    if (blockReason == null &&
        (queueResult != null && queueResult.deferred > 0 || pendingCount > 0)) {
      blockReason = await _queue.describePendingBlock(shopId: shopId) ??
          '${pendingCount > 0 ? pendingCount : queueResult?.deferred ?? 0} '
              'élément(s) en attente (dépendances ou données serveur manquantes).';
    }
    if (blockReason == null && hasFailures) {
      final failedModules = results
          .where((r) => !r.success)
          .map((r) => r.errorMessage ?? r.module)
          .join(' · ');
      blockReason = failedModules.isEmpty
          ? 'Échec de synchronisation sur un ou plusieurs modules.'
          : failedModules;
    }

    _running = false;
    if (apiFailure == null &&
        !hasFailures &&
        pendingCount == 0 &&
        conflictsAfter == 0) {
      await _settingsLocal?.touchCloudLastSyncAt(shopId);
    }

    _emit(
      SyncSnapshot(
        phase: SyncRunPhase.completed,
        tier: context.tier,
        cloudSyncEnabled: true,
        indicatorState: _resolveIndicator(
          pendingCount: pendingCount,
          conflictCount: conflictsAfter,
          hasPullFailures: hasFailures,
        ),
        pendingQueueCount: pendingCount,
        shopId: shopId,
        results: results,
        lastCompletedAt: DateTime.now(),
        blockReason: blockReason,
      ),
    );
  }



  SyncIndicatorState _resolveIndicator({

    required int pendingCount,

    required int conflictCount,

    bool hasPullFailures = false,

  }) {

    if (conflictCount > 0) return SyncIndicatorState.conflict;

    if (pendingCount > 0 || hasPullFailures) {

      return SyncIndicatorState.pending;

    }

    return SyncIndicatorState.synced;

  }



  void _emit(SyncSnapshot snapshot) {

    _snapshot = snapshot;

    if (!_snapshotController.isClosed) {

      _snapshotController.add(snapshot);

    }

  }



  /// Couche 2 → 3 : envoi FIFO des écritures locales (V2/V3, `sync_queue`).

  Future<void> processQueue({
    required int shopId,
    SyncContext? context,
  }) async {
    final ctx = context ?? await _policy.resolve(shopId: shopId);
    if (!ctx.shouldUseSyncQueue) return;

    await _processor.process(shopId: shopId);
  }

}


