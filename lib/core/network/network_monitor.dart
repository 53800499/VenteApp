import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// États de connectivité réseau pour ARIKE.
///
/// Distingue la simple présence d'une interface radio (Wi-Fi/4G)
/// de l'accès effectif au serveur et à Internet.
enum NetworkState {
  /// Aucune interface réseau active.
  offline,

  /// Wi-Fi ou données mobiles actives, mais serveur/Internet injoignable
  /// (portail captif, crédit épuisé, panne DNS ou serveur indisponible).
  localNetworkOnly,

  /// Internet et serveur ARIKE réellement accessibles.
  online,

  /// Sonde en cours d'évaluation.
  checking,
}

class NetworkMonitor {
  NetworkMonitor({
    Connectivity? connectivity,
    Dio? dio,
    String Function()? baseUrlProvider,
    Duration probeTimeout = const Duration(seconds: 4),
  })  : _connectivity = connectivity ?? Connectivity(),
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: probeTimeout,
                receiveTimeout: probeTimeout,
              ),
            ),
        _baseUrlProvider = baseUrlProvider,
        _probeTimeout = probeTimeout,
        _isMock = false,
        stateNotifier = ValueNotifier<NetworkState>(NetworkState.checking);

  /// Constructeur pour tests / mocks fixés sur un état donné.
  NetworkMonitor.fixed(NetworkState state)
      : _connectivity = null,
        _dio = null,
        _baseUrlProvider = null,
        _probeTimeout = Duration.zero,
        _isMock = true,
        _currentState = state,
        stateNotifier = ValueNotifier<NetworkState>(state);

  final Connectivity? _connectivity;
  final Dio? _dio;
  final String Function()? _baseUrlProvider;
  final Duration _probeTimeout;
  final bool _isMock;

  /// Notifier réactif pour synchroniser les composants UI (cadenas, bandeau, etc.).
  final ValueNotifier<NetworkState> stateNotifier;

  final _stateController = StreamController<NetworkState>.broadcast();
  Stream<NetworkState> get onStateChanged => _stateController.stream;

  NetworkState _currentState = NetworkState.checking;
  NetworkState get currentState => _currentState;

  bool get isOnline => _currentState == NetworkState.online;
  bool get isOffline => _currentState == NetworkState.offline;
  bool get isLocalOnly => _currentState == NetworkState.localNetworkOnly;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Future<NetworkState>? _probeInFlight;
  Timer? _recheckTimer;
  var _backoffSeconds = 4;

  void start() {
    if (_isMock || _connectivity == null) return;

    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      unawaited(_onConnectivityChanged(results));
    });

    unawaited(checkNow(force: true));
  }

  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    final hasRadio = results.isNotEmpty &&
        results.any((r) => r != ConnectivityResult.none);

    if (!hasRadio) {
      _recheckTimer?.cancel();
      _backoffSeconds = 4;
      _updateState(NetworkState.offline);
      return;
    }

    // Une interface est apparue : sonder la disponibilité réelle.
    await checkNow(force: true);
  }

  /// Déclenche une vérification immédiate de joignabilité.
  Future<NetworkState> checkNow({bool force = false}) async {
    if (_isMock) return _currentState;

    final inFlight = _probeInFlight;
    if (inFlight != null && !force) {
      return inFlight;
    }

    final future = _runProbe();
    _probeInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_probeInFlight, future)) {
        _probeInFlight = null;
      }
    }
  }

  Future<NetworkState> _runProbe() async {
    if (Platform.environment.containsKey('FLUTTER_TEST') &&
        (_dio == null || _baseUrlProvider == null)) {
      _updateState(NetworkState.online);
      return NetworkState.online;
    }

    final connectivity = _connectivity;
    if (connectivity != null) {
      final results = await connectivity.checkConnectivity();
      final hasRadio = results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);
      if (!hasRadio) {
        _updateState(NetworkState.offline);
        return NetworkState.offline;
      }
    }

    if (_currentState != NetworkState.online &&
        _currentState != NetworkState.localNetworkOnly) {
      _updateState(NetworkState.checking);
    }

    final healthy = await _probeBackendHealth();
    if (healthy) {
      _backoffSeconds = 4;
      _recheckTimer?.cancel();
      _updateState(NetworkState.online);
      return NetworkState.online;
    }

    // Le réseau est actif mais le backend ne répond pas : localNetworkOnly.
    _updateState(NetworkState.localNetworkOnly);
    _scheduleBackoffRecheck();
    return NetworkState.localNetworkOnly;
  }

  Future<bool> _probeBackendHealth() async {
    final dio = _dio;
    if (dio == null) return true;

    final provider = _baseUrlProvider;
    final base = provider != null ? provider().trim() : null;
    final url = (base != null && base.isNotEmpty)
        ? (base.endsWith('/') ? '${base}health' : '$base/health')
        : null;

    if (url != null) {
      try {
        final response = await dio.get<dynamic>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            sendTimeout: _probeTimeout,
            receiveTimeout: _probeTimeout,
            validateStatus: (status) => status != null && status < 500,
          ),
        );
        if (response.statusCode != null && response.statusCode! < 500) {
          return true;
        }
      } catch (_) {
        // En cas d'échec sur l'URL du backend, on tente un fallback DNS.
      }
    }

    // Fallback DNS pour déterminer si internet général est présent.
    try {
      final lookup = await InternetAddress.lookup('google.com')
          .timeout(_probeTimeout);
      if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) {
        if (url == null) return true;
      }
    } catch (_) {}

    return false;
  }

  void _scheduleBackoffRecheck() {
    _recheckTimer?.cancel();
    _recheckTimer = Timer(Duration(seconds: _backoffSeconds), () {
      if (_currentState == NetworkState.localNetworkOnly) {
        _backoffSeconds = (_backoffSeconds * 2).clamp(4, 60);
        unawaited(checkNow(force: true));
      }
    });
  }

  void _updateState(NetworkState newState) {
    if (_currentState == newState) return;
    _currentState = newState;
    stateNotifier.value = newState;
    if (!_stateController.isClosed) {
      _stateController.add(newState);
    }
  }

  void dispose() {
    _recheckTimer?.cancel();
    _connectivitySub?.cancel();
    _stateController.close();
    stateNotifier.dispose();
  }
}
