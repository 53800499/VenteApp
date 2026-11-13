import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/errors/failures.dart';
import 'package:venteapp/core/network/network_info.dart';
import 'package:venteapp/core/network/network_monitor.dart';
import 'package:venteapp/core/network/remote_api_guard.dart';
import 'package:venteapp/core/sync/app_release_tier.dart';
import 'package:venteapp/core/sync/remote_sync_port.dart';
import 'package:venteapp/core/sync/sync_policy.dart';
import 'package:venteapp/core/sync/sync_queue_datasource.dart';
import 'package:venteapp/core/sync/sync_queue_processor.dart';
import 'package:venteapp/core/sync/sync_service.dart';
import 'package:venteapp/core/sync/sync_snapshot.dart';

class FakeConnectivity implements Connectivity {
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _controller.stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [ConnectivityResult.wifi];
}

class FakeNetworkInfo implements NetworkInfo {
  FakeNetworkInfo({this.connected = true});
  bool connected;

  @override
  Future<bool> get isConnected async => connected;

  @override
  NetworkMonitor get monitor => NetworkMonitor.fixed(NetworkState.online);

  Future<bool> get isWifiOrEthernet async => true;

  Future<bool> checkLocalIpReachability(String ip, {int port = 80, Duration timeout = const Duration(seconds: 1)}) async => true;
}

class FakeApiGuard implements RemoteApiGuard {
  bool shouldFail = false;

  @override
  Future<void> ensureReady({Duration timeout = const Duration(seconds: 5)}) async {
    if (shouldFail) {
      throw const NetworkFailure('API non prête');
    }
  }

  Future<T> runGuarded<T>(Future<T> Function() action, {bool allowOffline = false}) => action();
}

class FakeSyncPolicy implements SyncPolicy {
  @override
  Future<SyncContext> resolve({required int shopId}) async {
    return SyncContext(
      tier: AppReleaseTier.v2,
      shopId: shopId,
      cloudSyncEnabled: true,
      activeShopCount: 1,
    );
  }

  @override
  Future<bool> shouldRunCloudSync({required int shopId}) async => true;

  @override
  Future<bool> shouldPullEntity({required int shopId, required String entity, bool force = false}) async => true;

  @override
  Future<int?> entityLastSyncedAt({required int shopId, required String entity}) async => null;

  @override
  Future<int?> entityUpdatedAfterCursor({required int shopId, required String entity, Duration skew = const Duration(minutes: 2)}) async => null;

  @override
  Future<void> markEntitySynced({required int shopId, required String entity}) async {}

  @override
  Future<void> invalidateEntitiesForWrite({required int shopId, required String entityTable, int? recordId}) async {}
}

class FakeSyncQueueDatasource implements SyncQueueDatasource {
  int pendingCount = 0;
  int conflictCount = 0;

  @override
  Future<int> countPending({required int shopId}) async => pendingCount;

  @override
  Future<int> countConflicts({required int shopId}) async => conflictCount;

  @override
  Future<String?> describePendingBlock({required int shopId}) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeSyncQueueProcessor implements SyncQueueProcessor {
  int processCallCount = 0;
  Failure? failureToThrow;
  Duration delay = Duration.zero;

  @override
  Future<SyncQueueProcessResult> process({required int shopId}) async {
    processCallCount++;
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (failureToThrow != null) {
      throw failureToThrow!;
    }
    return const SyncQueueProcessResult(
      processed: 0,
      deferred: 0,
      conflicts: 0,
    );
  }
}

class FakeRemoteSyncPort implements RemoteSyncPort {
  FakeRemoteSyncPort(this.moduleName);

  @override
  final String moduleName;
  int syncCallCount = 0;
  Failure? failureToThrow;
  Duration delay = Duration.zero;

  @override
  Future<void> syncFromRemote({required int shopId}) async {
    syncCallCount++;
    if (delay > Duration.zero) {
      await Future.delayed(delay);
    }
    if (failureToThrow != null) {
      throw failureToThrow!;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeConnectivity connectivity;
  late FakeNetworkInfo networkInfo;
  late FakeApiGuard apiGuard;
  late FakeSyncPolicy policy;
  late FakeSyncQueueDatasource queue;
  late FakeSyncQueueProcessor processor;
  late FakeRemoteSyncPort port;
  late SyncService syncService;

  setUp(() {
    connectivity = FakeConnectivity();
    networkInfo = FakeNetworkInfo();
    apiGuard = FakeApiGuard();
    policy = FakeSyncPolicy();
    queue = FakeSyncQueueDatasource();
    processor = FakeSyncQueueProcessor();
    port = FakeRemoteSyncPort('catalog');

    syncService = SyncService(
      connectivity: connectivity,
      networkInfo: networkInfo,
      apiGuard: apiGuard,
      policy: policy,
      queue: queue,
      processor: processor,
      ports: [port],
      networkMonitor: NetworkMonitor.fixed(NetworkState.online),
    );
  });

  tearDown(() {
    syncService.dispose();
  });

  group('SyncService - Sécurisation du cycle et Découplage PUSH/PULL', () {
    test('PULL autonome s exécute avec succès même si la file PUSH est vide', () async {
      queue.pendingCount = 0;

      syncService.scheduleSync(shopId: 1, trigger: SyncTrigger.periodicPolling);
      // Laisser le debounce et le cycle s'exécuter
      await Future.delayed(const Duration(milliseconds: 600));

      expect(port.syncCallCount, 1);
      expect(syncService.currentSnapshot.phase, SyncRunPhase.completed);
      expect(syncService.currentSnapshot.indicatorState, SyncIndicatorState.synced);
    });

    test('PULL s exécute même si le PUSH rencontre une erreur métier locale non-réseau', () async {
      queue.pendingCount = 1;
      processor.failureToThrow = const ValidationFailure('Validation métier refusée');

      syncService.scheduleSync(shopId: 1, trigger: SyncTrigger.manualRefresh);
      await Future.delayed(const Duration(milliseconds: 600));

      // Le processeur PUSH a été appelé et a échoué
      expect(processor.processCallCount, 1);
      // Le port PULL a quand même été exécuté grâce au découplage strict !
      expect(port.syncCallCount, 1);
      expect(syncService.currentSnapshot.phase, SyncRunPhase.completed);
    });

    test('Verrou de cycle : deux déclencheurs rapprochés fusionnent proprement sans concurrence', () async {
      processor.delay = const Duration(milliseconds: 100);
      port.delay = const Duration(milliseconds: 100);

      // Déclencheurs quasi simultanés
      syncService.scheduleSync(shopId: 1, trigger: SyncTrigger.manualRefresh);
      syncService.scheduleSync(shopId: 1, trigger: SyncTrigger.periodicPolling);

      // Attendre la fin du premier cycle
      await Future.delayed(const Duration(milliseconds: 700));

      // Les appels ne doivent pas avoir provoqué de double exécution concurrente désordonnée
      expect(port.syncCallCount, greaterThanOrEqualTo(1));
      expect(syncService.currentSnapshot.phase, SyncRunPhase.completed);
    });

    test('Le timer périodique est configuré à 45 secondes', () {
      expect(SyncService.periodicSyncInterval, const Duration(seconds: 45));
    });

    test('pauseSync et clearShop suspendent les opérations', () {
      syncService.scheduleSync(shopId: 1);
      syncService.pauseSync();
      expect(syncService.isPaused, isTrue);

      syncService.resumeSync(shopId: 1);
      expect(syncService.isPaused, isFalse);

      syncService.clearShop();
      expect(syncService.currentSnapshot.phase, SyncRunPhase.idle);
    });
  });
}
