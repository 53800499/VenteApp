import 'package:flutter_test/flutter_test.dart';
import 'package:venteapp/core/network/api_client.dart';
import 'package:venteapp/core/network/network_info.dart';
import 'package:venteapp/core/security/lockout_policy.dart';
import 'package:venteapp/core/security/pin_hasher.dart';
import 'package:venteapp/core/security/recovery_token_service.dart';
import 'package:venteapp/core/storage/auth_credentials_storage.dart';
import 'package:venteapp/core/storage/device_id_storage.dart';
import 'package:venteapp/core/storage/session_storage.dart';
import 'package:venteapp/core/utils/time.dart';
import 'package:venteapp/features/auth/data/datasources/remote/auth_remote_datasource.dart';
import 'package:venteapp/features/auth/data/models/auth_api_models.dart';
import 'package:venteapp/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:uuid/uuid.dart';

import '../../../../support/auth_test_helpers.dart';

class _FakeAuthRemote extends AuthRemoteDatasource {
  _FakeAuthRemote() : super(ApiClient());

  @override
  Future<LoginSuccessData> completeWhatsappLogin({
    required String verificationToken,
    required int shopId,
    required int userId,
    required String deviceId,
    String? deviceLabel,
  }) async {
    final now = nowMs();
    return LoginSuccessData(
      accessToken: 'access-$verificationToken',
      refreshToken: 'refresh-$verificationToken',
      tokenType: 'Bearer',
      accessExpiresAt: now + 3600000,
      refreshExpiresAt: now + 86400000,
      user: AuthUserData(
        id: userId,
        name: 'Awa Mensah',
        role: 'owner',
        roleLabel: 'Patron',
        shopId: shopId,
        biometricEnabled: false,
        lastLoginAt: now,
        permissions: const ['*'],
      ),
      shop: AuthShopData(id: shopId, name: 'Boutique Ganhi'),
      autoLockMinutes: 5,
      expiresAt: now + 300000,
    );
  }
}

void main() {
  test(
    'completeWhatsappLogin crée boutique, utilisateur et JWT sur appareil vierge',
    () async {
      final database = createTestDatabase();
      final credentials = AuthCredentialsStorage.inMemory();
      final repository = AuthRepositoryImpl(
        database: database,
        pinHasher: PinHasher(cost: 4),
        lockoutPolicy: LockoutPolicy(),
        recoveryTokenService: RecoveryTokenService(PinHasher(cost: 4)),
        sessionStorage: SessionStorage.inMemory(),
        credentialsStorage: credentials,
        deviceIdStorage: DeviceIdStorage.inMemory(),
        remote: _FakeAuthRemote(),
        networkInfo: const NetworkInfo.alwaysOnline(),
        uuid: const Uuid(),
      );

      final session = await repository.completeWhatsappLogin(
        verificationToken: 'otp-verification-token',
        shopId: 42,
        userId: 7,
      );

      expect(session.token, isNotEmpty);
      expect(session.shop.name, 'Boutique Ganhi');
      expect(session.user.name, 'Awa Mensah');
      expect(await credentials.hasCredentials(), isTrue);
      expect(await repository.isSetupComplete(), isTrue);

      final shops = await database.select(database.shops).get();
      expect(shops, hasLength(1));
      expect(shops.single.serverId, '42');

      final users = await database.select(database.users).get();
      expect(users, hasLength(1));
      expect(users.single.serverId, '7');
      expect(users.single.name, 'Awa Mensah');

      await database.close();
    },
  );
}
