import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkInfo {
  NetworkInfo(
    Connectivity connectivity, {
    String? Function()? hostProvider,
  })  : _connectivity = connectivity,
        _hostProvider = hostProvider,
        _mode = _NetworkMode.live;

  const NetworkInfo.alwaysOnline()
      : _connectivity = null,
        _hostProvider = null,
        _mode = _NetworkMode.online;

  const NetworkInfo.alwaysOffline()
      : _connectivity = null,
        _hostProvider = null,
        _mode = _NetworkMode.offline;

  final Connectivity? _connectivity;
  // Conservé pour compatibilité DI ; la connectivité radio suffit désormais.
  // ignore: unused_field
  final String? Function()? _hostProvider;
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
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return false;
    }

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return true;
    }

    // Une connectivité radio/Wi‑Fi active suffit ; le DNS peut échouer
    // transitoirement sans bloquer les appels API réels.
    return true;
  }
}

enum _NetworkMode { live, online, offline }
