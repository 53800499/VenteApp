import 'dart:async';



import 'package:connectivity_plus/connectivity_plus.dart';



import '../errors/failures.dart';

import '../network/network_info.dart';

import '../network/remote_api_guard.dart';

import '../network/api_client.dart';

import '../network/active_shop_context.dart';

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

    ActiveShopContext? activeShop,

    Future<void> Function()? onServerContact,

  })  : _connectivity = connectivity,

        _networkInfo = networkInfo,

        _apiGuard = apiGuard,

        _policy = policy,

        _queue = queue,

        _processor = processor,

        _ports = ports,

        _settingsLocal = settingsLocal,

        _activeShop = activeShop,

        _onServerContact = onServerContact;



  final Connectivity _connectivity;

  final NetworkInfo _networkInfo;

  final RemoteApiGuard _apiGuard;

  final SyncPolicy _policy;

  final SyncQueueDatasource _queue;

  final SyncQueueProcessor _processor;

  final List<RemoteSyncPort> _ports;
  final SettingsLocalDatasource? _settingsLocal;
  final ActiveShopContext? _activeShop;

  /// Notifié à chaque cycle ayant réellement joint le serveur (pull/push OK).
  final Future<void> Function()? _onServerContact;



  final _snapshotController = StreamController<SyncSnapshot>.broadcast();

  Stream<SyncSnapshot> get snapshots => _snapshotController.stream;



  SyncSnapshot _snapshot = const SyncSnapshot.idle();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  Timer? _debounce;

  int? _shopId;

  var _running = false;

  var _started = false;

  var _paused = false;



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
    _paused = false;

    _emit(const SyncSnapshot.idle());

  }

  /// Suspend les cycles de synchronisation (changement de boutique, déconnexion…).
  void pauseSync() {
    _paused = true;
    _debounce?.cancel();
  }

  /// Relance la synchronisation après une pause.
  void resumeSync({int? shopId}) {
    if (shopId != null) _shopId = shopId;
    _paused = false;
    _scheduleSync();
  }

  bool get isPaused => _paused;



  void dispose() {

    _debounce?.cancel();

    _connectivitySub?.cancel();

    _snapshotController.close();

  }



  void _scheduleSync() {

    if (_paused) return;

    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 400), () {

      unawaited(_runSyncCycle());

    });

  }



  Future<void> _runSyncCycle() async {
    if (_paused || _running) return;

    final shopId = _shopId;
    if (shopId == null) return;

    // Épingle tout le cycle (pull des ports + push de la file) sur la boutique
    // serveur active au démarrage. Un changement de boutique concurrent ne peut
    // plus détourner l'en-tête X-Shop-Id : les données restent liées à la bonne
    // boutique côté serveur, même si le contexte global bascule en cours de route.
    await ApiClient.runScopedToServerShop(
      _activeShop?.serverShopId,
      () => _runSyncCycleBody(shopId),
    );
  }

  Future<void> _runSyncCycleBody(int shopId) async {
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

    // Contact serveur avéré (au moins un pull réussi ou file traitée sans échec
    // réseau) : réinitialise l'ancienneté qui pilote la politique 3 niveaux.
    final reachedServer = apiFailure == null &&
        (results.any((r) => r.success) || queueResult != null);
    final onServerContact = _onServerContact;
    if (reachedServer && onServerContact != null) {
      await onServerContact();
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

  /// Flush « best effort » de la file d'attente avant un changement de boutique.
  ///
  /// Tente d'envoyer les écritures en attente de [shopId] pendant au plus
  /// [timeout], en épinglant les requêtes sur la boutique serveur active. Ne
  /// bloque jamais indéfiniment : si le réseau est absent, si le délai est
  /// dépassé ou si aucun progrès n'est possible (dépendances manquantes), la
  /// méthode rend la main en indiquant le nombre d'éléments restants pour que
  /// l'appelant informe l'utilisateur (ces éléments partiront plus tard via la
  /// synchronisation de fond).
  Future<ShopFlushOutcome> flushPendingBeforeSwitch({
    required int shopId,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final pendingBefore = await _queue.countPending(shopId: shopId);
    if (pendingBefore == 0) {
      return const ShopFlushOutcome(
        pendingBefore: 0,
        pendingAfter: 0,
        wasOffline: false,
        timedOut: false,
      );
    }

    final context = await _policy.resolve(shopId: shopId);
    if (!context.shouldUseSyncQueue) {
      return ShopFlushOutcome(
        pendingBefore: pendingBefore,
        pendingAfter: pendingBefore,
        wasOffline: false,
        timedOut: false,
      );
    }

    if (!await _networkInfo.isConnected) {
      return ShopFlushOutcome(
        pendingBefore: pendingBefore,
        pendingAfter: pendingBefore,
        wasOffline: true,
        timedOut: false,
      );
    }

    final deadline = DateTime.now().add(timeout);
    var pendingAfter = pendingBefore;
    var timedOut = false;

    // Empêche un nouveau cycle de fond de démarrer pendant le flush.
    final wasRunning = _running;
    _running = true;
    try {
      await ApiClient.runScopedToServerShop(_activeShop?.serverShopId, () async {
        var lastPending = pendingBefore;
        while (true) {
          try {
            await _processor.process(shopId: shopId);
          } on Failure {
            break;
          } catch (_) {
            break;
          }

          pendingAfter = await _queue.countPending(shopId: shopId);
          if (pendingAfter == 0) break;
          if (pendingAfter >= lastPending) break; // aucun progrès : inutile d'insister
          lastPending = pendingAfter;

          if (DateTime.now().isAfter(deadline)) {
            timedOut = true;
            break;
          }
        }
      });
    } finally {
      _running = wasRunning;
    }

    return ShopFlushOutcome(
      pendingBefore: pendingBefore,
      pendingAfter: pendingAfter,
      wasOffline: false,
      timedOut: timedOut,
    );
  }

}

/// Résultat d'un flush « best effort » de la file avant un changement de
/// boutique (voir [SyncService.flushPendingBeforeSwitch]).
class ShopFlushOutcome {
  const ShopFlushOutcome({
    required this.pendingBefore,
    required this.pendingAfter,
    required this.wasOffline,
    required this.timedOut,
  });

  /// Nombre d'éléments en attente avant la tentative de flush.
  final int pendingBefore;

  /// Nombre d'éléments encore en attente après la tentative.
  final int pendingAfter;

  /// Vrai si le flush n'a pas pu s'exécuter faute de réseau.
  final bool wasOffline;

  /// Vrai si le délai imparti a été atteint avant de vider la file.
  final bool timedOut;

  /// Y avait-il des écritures en attente au départ ?
  bool get hadPending => pendingBefore > 0;

  /// Toutes les écritures ont-elles été envoyées ?
  bool get fullyFlushed => pendingAfter == 0;
}


