import 'package:dio/dio.dart';

import '../../../../../core/errors/exception_mapper.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
import '../../models/auth_api_models.dart';

class AuthRemoteDatasource {
  AuthRemoteDatasource(this._client);

  final ApiClient _client;

  Future<LockScreenDataDto> getLockScreen(int shopId) async {
    final data = await _getData('/auth/lock-screen/$shopId');
    return LockScreenDataDto.fromJson(data);
  }

  Future<LoginSuccessData> loginWithPin({
    required String pin,
    required int shopId,
    required String deviceId,
    int? userId,
    String? deviceLabel,
  }) async {
    final data = await _postData(
      '/auth/pin/login',
      {
        'pin': pin,
        'shopId': shopId,
        'deviceId': deviceId,
        if (userId != null) 'userId': userId,
        if (deviceLabel != null) 'deviceLabel': deviceLabel,
      },
    );
    return LoginSuccessData.fromJson(data);
  }

  Future<SetupOwnerData> setupOwner({
    required String ownerName,
    required String shopName,
    required String pin,
    String? shopAddress,
    String? shopPhone,
  }) async {
    final data = await _postData(
      '/auth/setup',
      {
        'ownerName': ownerName,
        'shopName': shopName,
        'pin': pin,
        if (shopAddress != null) 'shopAddress': shopAddress,
        if (shopPhone != null) 'shopPhone': shopPhone,
      },
    );
    return SetupOwnerData.fromJson(data);
  }

  Future<LoginSuccessData> emergencyUnlock({
    required String recoveryToken,
    required int shopId,
    required String deviceId,
    int? userId,
    String? deviceLabel,
  }) async {
    final data = await _postData(
      '/auth/emergency-unlock',
      {
        'recoveryToken': recoveryToken,
        'shopId': shopId,
        'deviceId': deviceId,
        if (userId != null) 'userId': userId,
        if (deviceLabel != null) 'deviceLabel': deviceLabel,
      },
    );
    return LoginSuccessData.fromJson(data);
  }

  Future<void> touchSession() async {
    await _postData('/auth/session/touch', {});
  }

  Future<TokenRefreshData> refreshTokens(String refreshToken) async {
    final data = await _postData(
      '/auth/refresh',
      {'refreshToken': refreshToken},
    );
    return TokenRefreshData.fromJson(data);
  }

  Future<void> logout() async {
    await _postData('/auth/logout', {});
  }

  Future<OwnedShopListDto> listOwnedShops() async {
    final data = await _getData('/shops');
    return OwnedShopListDto.fromJson(data);
  }

  Future<SwitchShopDataDto> switchShop({required int shopId}) async {
    final data = await _postData(
      '/auth/switch-shop',
      {'shopId': shopId},
    );
    return SwitchShopDataDto.fromJson(data);
  }

  Future<Map<String, dynamic>> _getData(String path) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(path);
      return _unwrap(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<Map<String, dynamic>> _postData(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(path, data: body);
      return _unwrap(response.data);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Map<String, dynamic> _unwrap(Map<String, dynamic>? payload) {
    if (payload == null) {
      throw const NetworkFailure('Réponse serveur vide.');
    }
    if (payload['success'] == true && payload['data'] is Map<String, dynamic>) {
      return payload['data'] as Map<String, dynamic>;
    }
    if (payload['data'] is Map<String, dynamic>) {
      return payload['data'] as Map<String, dynamic>;
    }
    return payload;
  }
}
