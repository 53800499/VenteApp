import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:frontend/core/database/app_database.dart';
import 'package:frontend/shared/enums/user_role.dart';
import 'package:frontend/core/errors/failures.dart';
import 'package:frontend/core/security/lockout_policy.dart';
import 'package:frontend/core/security/pin_hasher.dart';
import 'package:frontend/core/security/recovery_token_service.dart';
import 'package:frontend/core/storage/auth_credentials_storage.dart';
import 'package:frontend/core/storage/session_storage.dart';
import 'package:frontend/core/utils/time.dart';
import 'package:frontend/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../../../../support/auth_test_helpers.dart';

void main() {
  late AppDatabase database;
  late AuthRepositoryImpl repository;
  late String recoveryToken;
  late String recoveryHash;

  setUp(() async {
    database = createTestDatabase();
    final pinHasher = PinHasher(cost: 4);
    repository = AuthRepositoryImpl(
      database: database,
      pinHasher: pinHasher,
      lockoutPolicy: LockoutPolicy(),
      recoveryTokenService: RecoveryTokenService(pinHasher),
      sessionStorage: SessionStorage.inMemory(),
      credentialsStorage: AuthCredentialsStorage.inMemory(),
      uuid: const Uuid(),
    );

    final recovery = RecoveryTokenService(pinHasher).generate();
    recoveryToken = recovery.token;
    recoveryHash = recovery.hash;

    final timestamp = nowMs();
    final shopId = await database.into(database.shops).insert(
          ShopsCompanion.insert(name: const Value('Boutique Test'), createdAt: timestamp),
        );
    final userId = await database.into(database.users).insert(
          UsersCompanion.insert(
            shopId: shopId,
            name: 'Kofi Test',
            pinHash: pinHasher.hash('1234'),
            role: const Value('owner'),
            emergencyRecoveryHash: Value(recoveryHash),
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        );
    await database.into(database.settings).insert(
          SettingsCompanion.insert(
            shopId: shopId,
            shopName: const Value('Boutique Test'),
            autoLockMinutes: const Value(5),
            updatedAt: timestamp,
          ),
        );
    await (database.update(database.shops)..where((s) => s.id.equals(shopId)))
        .write(ShopsCompanion(ownerUserId: Value(userId)));
  });

  tearDown(() async {
    try {
      await database.close();
    } on Object {
      // Base déjà fermée par un test isolé.
    }
  });

  group('isSetupComplete', () {
    test('retourne true après création d\'un utilisateur', () async {
      expect(await repository.isSetupComplete(), isTrue);
    });
  });

  group('getLockScreen', () {
    test('retourne la boutique et les utilisateurs actifs', () async {
      final lockScreen = await repository.getLockScreen(shopId: 1);

      expect(lockScreen.shopId, 1);
      expect(lockScreen.shopName, 'Boutique Test');
      expect(lockScreen.users, hasLength(1));
      expect(lockScreen.users.first.name, 'Kofi Test');
      expect(lockScreen.users.first.role, UserRole.owner);
    });

    test('lève NotFoundFailure si la boutique n\'existe pas', () async {
      expect(
        () => repository.getLockScreen(shopId: 999),
        throwsA(isA<NotFoundFailure>()),
      );
    });
  });

  group('loginWithPin', () {
    test('connecte l\'utilisateur avec un PIN valide', () async {
      final session = await repository.loginWithPin(pin: '1234', shopId: 1);

      expect(session.user.name, 'Kofi Test');
      expect(session.shop.name, 'Boutique Test');
      expect(session.token, isNotEmpty);
      expect(session.autoLockMinutes, 5);
      expect(session.user.permissions, isNotEmpty);
    });

    test('lève InvalidPinFailure avec tentatives restantes', () async {
      try {
        await repository.loginWithPin(pin: '0000', shopId: 1);
        fail('Devait lever InvalidPinFailure');
      } on InvalidPinFailure catch (failure) {
        expect(failure.remainingAttempts, 4);
        expect(failure.message, contains('4 tentatives restantes'));
      }
    });

    test('lève AccountLockedFailure après 5 échecs consécutifs', () async {
      for (var i = 0; i < 4; i++) {
        try {
          await repository.loginWithPin(pin: '0000', shopId: 1);
        } on InvalidPinFailure {
          // attendu
        }
      }

      expect(
        () => repository.loginWithPin(pin: '0000', shopId: 1),
        throwsA(isA<AccountLockedFailure>()),
      );
    });

    test('lève EmergencyRecoveryRequiredFailure après 3 blocages', () async {
      await (database.update(database.users)..where((u) => u.id.equals(1))).write(
        const UsersCompanion(lockoutCount: Value(3)),
      );

      expect(
        () => repository.loginWithPin(pin: '0000', shopId: 1),
        throwsA(isA<EmergencyRecoveryRequiredFailure>()),
      );
    });
  });

  group('setupOwner', () {
    test('crée boutique, utilisateur et paramètres sur base vide', () async {
      await database.close();
      final emptyDb = createTestDatabase();
      final pinHasher = PinHasher(cost: 4);
      final emptyRepo = AuthRepositoryImpl(
        database: emptyDb,
        pinHasher: pinHasher,
        lockoutPolicy: LockoutPolicy(),
        recoveryTokenService: RecoveryTokenService(pinHasher),
        sessionStorage: SessionStorage.inMemory(),
        credentialsStorage: AuthCredentialsStorage.inMemory(),
      );

      final result = await emptyRepo.setupOwner(
        ownerName: 'Awa Mensah',
        shopName: 'Boutique Ganhi',
        pin: '5678',
        shopPhone: '+22990123456',
      );

      expect(result.shopId, greaterThan(0));
      expect(result.userId, greaterThan(0));
      expect(result.recoveryToken, isNotEmpty);
      expect(await emptyRepo.isSetupComplete(), isTrue);

      final lockScreen = await emptyRepo.getLockScreen(shopId: result.shopId);
      expect(lockScreen.shopName, 'Boutique Ganhi');
      expect(lockScreen.users.first.name, 'Awa Mensah');

      await emptyDb.close();
    });

    test('lève ConflictFailure si déjà installé', () async {
      expect(
        () => repository.setupOwner(
          ownerName: 'Autre',
          shopName: 'Autre boutique',
          pin: '5678',
        ),
        throwsA(isA<ConflictFailure>()),
      );
    });
  });

  group('emergencyUnlock', () {
    test('débloque avec un jeton de récupération valide', () async {
      await (database.update(database.users)..where((u) => u.id.equals(1))).write(
        UsersCompanion(
          failedAttempts: const Value(5),
          lockoutCount: const Value(3),
          lockedUntil: Value(nowMs() + 600000),
        ),
      );

      final session = await repository.emergencyUnlock(
        recoveryToken: recoveryToken,
        shopId: 1,
      );

      expect(session.user.name, 'Kofi Test');
      expect(session.token, isNotEmpty);

      final auditLogs = await database.select(database.auditLogs).get();
      expect(auditLogs, hasLength(1));
      expect(auditLogs.first.action, 'emergency_unlock');
    });

    test('lève UnauthorizedFailure avec un jeton invalide', () async {
      expect(
        () => repository.emergencyUnlock(
          recoveryToken: 'jeton-invalide',
          shopId: 1,
        ),
        throwsA(isA<UnauthorizedFailure>()),
      );
    });
  });

  group('restoreSession', () {
    test('restaure une session active après connexion', () async {
      final loginSession = await repository.loginWithPin(pin: '1234', shopId: 1);

      final restored = await repository.restoreSession();

      expect(restored, isNotNull);
      expect(restored!.token, loginSession.token);
      expect(restored.user.id, loginSession.user.id);
    });

    test('retourne null après déconnexion', () async {
      await repository.loginWithPin(pin: '1234', shopId: 1);
      await repository.logout();

      expect(await repository.restoreSession(), isNull);
    });
  });
}
