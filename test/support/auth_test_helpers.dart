import 'package:drift/native.dart';
import 'package:venteapp/core/database/app_database.dart';
import 'package:venteapp/core/security/lockout_policy.dart';
import 'package:venteapp/core/security/pin_hasher.dart';
import 'package:venteapp/core/security/recovery_token_service.dart';
import 'package:venteapp/core/storage/auth_credentials_storage.dart';
import 'package:venteapp/core/storage/session_storage.dart';
import 'package:venteapp/features/auth/data/repositories/auth_repository_impl.dart';

AppDatabase createTestDatabase() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}

AuthRepositoryImpl createAuthRepository({
  AppDatabase? database,
  PinHasher? pinHasher,
  LockoutPolicy? lockoutPolicy,
}) {
  final db = database ?? createTestDatabase();
  final hasher = pinHasher ?? PinHasher(cost: 4);
  return AuthRepositoryImpl(
    database: db,
    pinHasher: hasher,
    lockoutPolicy: lockoutPolicy ?? LockoutPolicy(),
    recoveryTokenService: RecoveryTokenService(hasher),
    sessionStorage: SessionStorage.inMemory(),
    credentialsStorage: AuthCredentialsStorage.inMemory(),
  );
}
