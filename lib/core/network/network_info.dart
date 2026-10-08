import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'network_monitor.dart';

class NetworkInfo {
  NetworkInfo(
    Connectivity connectivity, {
    NetworkMonitor? networkMonitor,
    String? Function()? hostProvider,
  })  : _connectivity = connectivity,
        _networkMonitor = networkMonitor,
        _hostProvider = hostProvider,
        _mode = _NetworkMode.live;

  const NetworkInfo.alwaysOnline()
      : _connectivity = null,
        _networkMonitor = null,
        _hostProvider = null,
        _mode = _NetworkMode.online;

  const NetworkInfo.alwaysOffline()
      : _connectivity = null,
        _networkMonitor = null,
        _hostProvider = null,
        _mode = _NetworkMode.offline;

  final Connectivity? _connectivity;
  final NetworkMonitor? _networkMonitor;
  // Conservé pour compatibilité DI.
  // ignore: unused_field
  final String? Function()? _hostProvider;
  final _NetworkMode _mode;

  NetworkMonitor? get monitor => _networkMonitor;

  Future<bool> get isConnected async {
    return switch (_mode) {
      _NetworkMode.online => true,
      _NetworkMode.offline => false,
      _NetworkMode.live => _hasLiveConnection(),
    };
  }

  Future<bool> _hasLiveConnection() async {
    final monitor = _networkMonitor;
    if (monitor != null) {
      return monitor.isOnline;
    }

    final results = await _connectivity!.checkConnectivity();
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return false;
    }

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return true;
    }

    return true;
  }
}

enum _NetworkMode { live, online, offline }
