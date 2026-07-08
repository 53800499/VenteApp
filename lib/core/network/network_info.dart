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
    if (results.isEmpty || results.any((r) => r == ConnectivityResult.none)) {
      return false;
    }

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return true;
    }

    try {
      final host = _hostProvider?.call();
      if (host != null && host.isNotEmpty) {
        final lookup = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 2));
        if (lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty) {
          return true;
        }
      }
    } on Object {
      // Ignorer l'erreur et tenter le fallback Google.
    }

    try {
      final lookup = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 2));
      return lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty;
    } on Object {
      return false;
    }
  }
}

enum _NetworkMode { live, online, offline }
