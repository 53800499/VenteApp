import 'dart:async';

import 'package:dio/dio.dart';

import '../constants/api_config.dart';
import '../storage/auth_credentials_storage.dart';
import '../../features/auth/data/models/auth_api_models.dart';
import 'active_shop_context.dart';

/// Clé de zone servant à épingler l'en-tête `X-Shop-Id` sur une boutique
/// serveur précise pour toutes les requêtes émises dans un contexte donné.
const Object _scopedServerShopIdZoneKey = #venteAppScopedServerShopId;

class ApiClient {
  ApiClient({
    String? baseUrl,
    AuthCredentialsStorage? credentials,
    ActiveShopContext? activeShop,
    Dio? dio,
  })  : _credentials = credentials,
        _activeShop = activeShop,
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl ?? ApiConfig.defaultBaseUrl(),
                connectTimeout: const Duration(seconds: 6),
                receiveTimeout: const Duration(seconds: 10),
                headers: const {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          await _attachBearer(options);
          handler.next(options);
        },
        onError: (error, handler) async {
          final retried = error.requestOptions.extra['_jwtRetried'] == true;
          final isRefresh = error.requestOptions.path.contains('/auth/refresh');

          if (error.response?.statusCode == 401 &&
              !retried &&
              !isRefresh &&
              !_isPublicAuthRequest(error.requestOptions) &&
              _credentials != null) {
            try {
              await _refreshTokens();
              error.requestOptions.extra['_jwtRetried'] = true;
              await _attachBearer(error.requestOptions);
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } on Object {
              if (error.response?.statusCode == 401) {
                unawaited(onRefreshTokenInvalid?.call());
              }
              return handler.next(error);
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final AuthCredentialsStorage? _credentials;
  final ActiveShopContext? _activeShop;
  Future<void>? _refreshInFlight;

  /// Appelé quand le refresh token est rejeté (401) — ne verrouille pas l'app.
  Future<void> Function()? onRefreshTokenInvalid;

  /// Appelé après un refresh JWT réussi.
  Future<void> Function()? onRefreshTokenRestored;

  String get baseUrl => _dio.options.baseUrl;

  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  bool get isConfigured => baseUrl.isNotEmpty;

  /// Exécute [action] en épinglant l'en-tête `X-Shop-Id` à [serverShopId] pour
  /// toutes les requêtes émises (et leurs continuations async) dans ce contexte.
  ///
  /// Cet épinglage est propagé via une [Zone] : il prime sur le contexte global
  /// [ActiveShopContext] uniquement à l'intérieur de [action], et n'affecte donc
  /// pas les requêtes concurrentes (ex. lectures de l'UI) exécutées hors de cette
  /// zone. Cela protège un cycle de synchronisation d'un changement de boutique
  /// concurrent : les écritures/lectures serveur restent liées à la boutique
  /// active au démarrage du cycle. Si [serverShopId] est nul, aucun épinglage
  /// n'est appliqué (comportement global inchangé).
  static Future<T> runScopedToServerShop<T>(
    int? serverShopId,
    Future<T> Function() action,
  ) {
    if (serverShopId == null) return action();
    return runZoned(
      action,
      zoneValues: {_scopedServerShopIdZoneKey: serverShopId},
    );
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) {
    return _dio.get<T>(path, queryParameters: queryParameters, options: options);
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Options? options,
  }) {
    return _dio.post<T>(path, data: data, options: options);
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Options? options,
  }) {
    return _dio.patch<T>(path, data: data, options: options);
  }

  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Options? options,
  }) {
    return _dio.put<T>(path, data: data, options: options);
  }

  Future<Response<T>> delete<T>(
    String path, {
    Options? options,
  }) {
    return _dio.delete<T>(path, options: options);
  }

  static const _publicAuthPathMarkers = [
    '/auth/pin/login',
    '/auth/setup',
    '/auth/setup/validate',
    '/auth/lock-screen',
    '/auth/whatsapp',
  ];

  bool _isPublicAuthRequest(RequestOptions options) {
    final path = options.path;
    return _publicAuthPathMarkers.any(path.contains);
  }

  Future<void> _attachBearer(RequestOptions options) async {
    final credentials = _credentials;
    if (credentials != null && !_isPublicAuthRequest(options)) {
      if (!await credentials.hasValidAccessToken() &&
          await credentials.hasValidRefreshToken()) {
        try {
          await _refreshTokens();
        } on Object {
          // La requête partira sans jeton valide ; l'intercepteur 401 retentera.
        }
      }
      final token = await credentials.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    final scopedShopId = Zone.current[_scopedServerShopIdZoneKey];
    final shopId = scopedShopId is int ? scopedShopId : _activeShop?.serverShopId;
    if (shopId != null) {
      options.headers['X-Shop-Id'] = '$shopId';
    }
  }

  /// Rafraîchit les jetons si l'accès est expiré mais le refresh encore valide.
  Future<void> refreshTokensIfNeeded() async {
    final credentials = _credentials;
    if (credentials == null) return;
    if (await credentials.hasValidAccessToken()) return;
    if (!await credentials.hasValidRefreshToken()) {
      throw DioException(
        requestOptions: RequestOptions(path: '/auth/refresh'),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: '/auth/refresh'),
          statusCode: 401,
        ),
      );
    }
    await _refreshTokens();
  }

  /// Force une tentative de refresh même si l'expiration locale est dépassée,
  /// tant qu'un refresh token est stocké (le serveur reste l'autorité).
  /// Utilisé pendant la fenêtre de grâce pour continuer à viser le serveur.
  Future<void> forceRefreshTokens() async {
    final credentials = _credentials;
    if (credentials == null) return;
    final refreshToken = await credentials.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: '/auth/refresh'),
        type: DioExceptionType.badResponse,
      );
    }
    await _refreshTokens();
  }

  Future<void> _refreshTokens() {
    _refreshInFlight ??= _doRefreshTokens();
    return _refreshInFlight!.whenComplete(() => _refreshInFlight = null);
  }

  Future<void> _doRefreshTokens() async {
    final credentials = _credentials;
    if (credentials == null) return;

    final refreshToken = await credentials.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: '/auth/refresh'),
        type: DioExceptionType.badResponse,
      );
    }

    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );

    final statusCode = response.statusCode;
    if (statusCode == 401 || statusCode == 403) {
      unawaited(onRefreshTokenInvalid?.call());
      throw DioException(
        requestOptions: RequestOptions(path: '/auth/refresh'),
        response: response,
        type: DioExceptionType.badResponse,
      );
    }

    final payload = response.data;
    if (payload == null) {
      throw DioException(
        requestOptions: RequestOptions(path: '/auth/refresh'),
        type: DioExceptionType.badResponse,
      );
    }

    final data = payload['data'] is Map<String, dynamic>
        ? payload['data'] as Map<String, dynamic>
        : payload;

    final tokens = TokenRefreshData.fromJson(data);
    await credentials.updateTokens(
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      accessExpiresAt: tokens.accessExpiresAt,
      refreshExpiresAt: tokens.refreshExpiresAt,
    );
    await onRefreshTokenRestored?.call();
  }
}
