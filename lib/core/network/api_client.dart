import 'package:dio/dio.dart';

import '../constants/api_config.dart';
import '../storage/auth_credentials_storage.dart';
import '../../features/auth/data/models/auth_api_models.dart';
import 'active_shop_context.dart';

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
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 30),
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
              _credentials != null) {
            try {
              await _refreshTokens();
              error.requestOptions.extra['_jwtRetried'] = true;
              await _attachBearer(error.requestOptions);
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            } on Object {
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

  String get baseUrl => _dio.options.baseUrl;

  void setBaseUrl(String url) {
    _dio.options.baseUrl = url;
  }

  bool get isConfigured => baseUrl.isNotEmpty;

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

  Future<Response<T>> delete<T>(
    String path, {
    Options? options,
  }) {
    return _dio.delete<T>(path, options: options);
  }

  Future<void> _attachBearer(RequestOptions options) async {
    final credentials = _credentials;
    if (credentials != null) {
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

    final shopId = _activeShop?.serverShopId;
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
  }
}
