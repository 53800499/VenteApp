import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkInfo {
  NetworkInfo(Connectivity connectivity)
      : _connectivity = connectivity,
        _mode = _NetworkMode.live;

  const NetworkInfo.alwaysOnline() : _connectivity = null, _mode = _NetworkMode.online;

  const NetworkInfo.alwaysOffline() : _connectivity = null, _mode = _NetworkMode.offline;

  final Connectivity? _connectivity;
  final _NetworkMode _mode;

  Future<bool> get isConnected async {
    return switch (_mode) {
      _NetworkMode.online => true,
      _NetworkMode.offline => false,
      _NetworkMode.live => _hasLiveConnection(),
    };
  }

  Future<bool> _hasLiveConnection() async {
    final results = await _connectivity!.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}

enum _NetworkMode { live, online, offline }
