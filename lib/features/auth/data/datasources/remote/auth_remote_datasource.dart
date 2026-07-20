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
    required String ownerPhone,
    String? shopAddress,
    String? shopPhone,
  }) async {
    final data = await _postData(
      '/auth/setup',
      {
        'ownerName': ownerName,
        'shopName': shopName,
        'pin': pin,
        'ownerPhone': ownerPhone,
        if (shopAddress != null) 'shopAddress': shopAddress,
        if (shopPhone != null) 'shopPhone': shopPhone,
      },
    );
    return SetupOwnerData.fromJson(data);
  }

  Future<Map<String, String>> validateSetupOwner({
    required String ownerName,
    required String shopName,
    required String pin,
    required String ownerPhone,
    String? shopAddress,
    String? shopPhone,
  }) async {
    final data = await _postData(
      '/auth/setup/validate',
      {
        'ownerName': ownerName,
        'shopName': shopName,
        'pin': pin,
        'ownerPhone': ownerPhone,
        if (shopAddress != null) 'shopAddress': shopAddress,
        if (shopPhone != null) 'shopPhone': shopPhone,
      },
    );

    if (data['valid'] == true) return {};

    final conflicts = data['conflicts'];
    if (conflicts is List) {
      final result = <String, String>{};
      for (final item in conflicts) {
        if (item is Map<String, dynamic>) {
          final field = item['field']?.toString();
          final message = item['message']?.toString();
          if (field != null && message != null && message.isNotEmpty) {
            result[field] = message;
          }
        }
      }
      if (result.isNotEmpty) return result;
    }

    final fields = data['fields'];
    if (fields is Map<String, dynamic>) {
      return fields.map((key, value) => MapEntry(key.toString(), '$value'));
    }

    return {};
  }

  Future<WhatsappOtpRequestDataDto> requestWhatsappOtp({
    required String phone,
  }) async {
    final data = await _postData('/auth/whatsapp/otp/request', {'phone': phone});
    return WhatsappOtpRequestDataDto.fromJson(data);
  }

  Future<WhatsappOtpVerifyDataDto> verifyWhatsappOtp({
    required String phone,
    required String code,
  }) async {
    final data = await _postData(
      '/auth/whatsapp/otp/verify',
      {'phone': phone, 'code': code},
    );
    return WhatsappOtpVerifyDataDto.fromJson(data);
  }

  Future<LoginSuccessData> completeWhatsappLogin({
    required String verificationToken,
    required int shopId,
    required int userId,
    required String deviceId,
    String? deviceLabel,
  }) async {
    final data = await _postData(
      '/auth/whatsapp/otp/complete',
      {
        'verificationToken': verificationToken,
        'shopId': shopId,
        'userId': userId,
        'deviceId': deviceId,
        if (deviceLabel != null) 'deviceLabel': deviceLabel,
      },
    );
    return LoginSuccessData.fromJson(data);
  }

  Future<void> resetPinWithWhatsappOtp({
    required String verificationToken,
    required int shopId,
    required int userId,
    required String newPin,
  }) async {
    await _postData(
      '/auth/whatsapp/otp/reset-pin',
      {
        'verificationToken': verificationToken,
        'shopId': shopId,
        'userId': userId,
        'newPin': newPin,
      },
    );
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

  Future<IdentityContextDto> getIdentityContext() async {
    final data = await _getData('/auth/identity');
    return IdentityContextDto.fromJson(data);
  }

  Future<SwitchShopDataDto> switchShop({required int shopId}) async {
    final data = await _postData(
      '/auth/switch-shop',
      {'shopId': shopId},
    );
    return SwitchShopDataDto.fromJson(data);
  }

  Future<bool> enableBiometric({required String pin}) async {
    final data = await _postData('/auth/biometric/enable', {'pin': pin});
    return data['biometricEnabled'] as bool? ?? true;
  }

  Future<List<DeviceSessionDto>> listDevices({bool shopScope = false}) async {
    try {
      final response = await _client.get<Map<String, dynamic>>(
        '/auth/devices',
        queryParameters: shopScope ? {'all': 'true'} : null,
      );
      final payload = response.data;
      if (payload == null) {
        throw const NetworkFailure('Réponse serveur vide.');
      }
      final data = payload['data'] ?? payload;
      if (data is List) {
        return data
            .whereType<Map<String, dynamic>>()
            .map(DeviceSessionDto.fromJson)
            .toList();
      }
      return [];
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  Future<void> revokeDevice(String sessionId) async {
    try {
      await _client.delete('/auth/devices/$sessionId');
    } on DioException catch (error) {
      throw mapDioException(error);
    }
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
