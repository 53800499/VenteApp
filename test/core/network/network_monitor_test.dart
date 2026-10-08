import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/network/network_info.dart';
import 'package:venteapp/core/network/network_monitor.dart';
import 'package:venteapp/core/sync/sync_snapshot.dart';

void main() {
  group('NetworkMonitor', () {
    test('fixed constructor sets state and properties accurately', () {
      final offlineMonitor = NetworkMonitor.fixed(NetworkState.offline);
      expect(offlineMonitor.currentState, NetworkState.offline);
      expect(offlineMonitor.isOffline, isTrue);
      expect(offlineMonitor.isOnline, isFalse);
      expect(offlineMonitor.isLocalOnly, isFalse);

      final localOnlyMonitor = NetworkMonitor.fixed(NetworkState.localNetworkOnly);
      expect(localOnlyMonitor.currentState, NetworkState.localNetworkOnly);
      expect(localOnlyMonitor.isLocalOnly, isTrue);
      expect(localOnlyMonitor.isOnline, isFalse);

      final onlineMonitor = NetworkMonitor.fixed(NetworkState.online);
      expect(onlineMonitor.currentState, NetworkState.online);
      expect(onlineMonitor.isOnline, isTrue);
      expect(onlineMonitor.isOffline, isFalse);
    });

    test('NetworkInfo delegates isConnected to NetworkMonitor when provided', () async {
      final onlineMonitor = NetworkMonitor.fixed(NetworkState.online);
      final networkInfoOnline = NetworkInfo(
        Connectivity(),
        networkMonitor: onlineMonitor,
      );
      expect(await networkInfoOnline.isConnected, isTrue);

      final localOnlyMonitor = NetworkMonitor.fixed(NetworkState.localNetworkOnly);
      final networkInfoLocal = NetworkInfo(
        Connectivity(),
        networkMonitor: localOnlyMonitor,
      );
      expect(await networkInfoLocal.isConnected, isFalse);

      final offlineMonitor = NetworkMonitor.fixed(NetworkState.offline);
      final networkInfoOffline = NetworkInfo(
        Connectivity(),
        networkMonitor: offlineMonitor,
      );
      expect(await networkInfoOffline.isConnected, isFalse);
    });

    test('NetworkInfo modes alwaysOnline and alwaysOffline still function', () async {
      const online = NetworkInfo.alwaysOnline();
      expect(await online.isConnected, isTrue);

      const offline = NetworkInfo.alwaysOffline();
      expect(await offline.isConnected, isFalse);
    });
  });

  group('SyncTrigger & SyncIndicatorState', () {
    test('SyncTrigger covers all operational scenarios', () {
      expect(SyncTrigger.values, containsAll([
        SyncTrigger.appStarted,
        SyncTrigger.appResumed,
        SyncTrigger.networkRestored,
        SyncTrigger.shopChanged,
        SyncTrigger.manualRefresh,
        SyncTrigger.outboxEnqueued,
        SyncTrigger.periodicFallback,
      ]));
    });

    test('SyncIndicatorState includes offline and waitingForConnection', () {
      expect(SyncIndicatorState.values, containsAll([
        SyncIndicatorState.disabled,
        SyncIndicatorState.synced,
        SyncIndicatorState.pending,
        SyncIndicatorState.conflict,
        SyncIndicatorState.offline,
        SyncIndicatorState.waitingForConnection,
      ]));
    });
  });
}
