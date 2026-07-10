import 'package:shared_preferences/shared_preferences.dart';
import 'package:venteapp/core/database/app_database.dart';
import 'package:venteapp/core/database/encrypted_database_opener.dart';
import 'package:venteapp/core/security/lockout_policy.dart';
import 'package:venteapp/core/security/pin_hasher.dart';
import 'package:venteapp/core/security/recovery_token_service.dart';
import 'package:venteapp/core/storage/auth_credentials_storage.dart';
import 'package:venteapp/core/storage/session_storage.dart';
import 'package:venteapp/core/sync/cloud_sync_enabler.dart';
import 'package:venteapp/core/sync/cloud_sync_preferences.dart';
import 'package:venteapp/core/sync/sync_policy.dart';
import 'package:venteapp/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:venteapp/features/settings/data/datasources/local/settings_local_datasource.dart';

AppDatabase createTestDatabase() {
  return AppDatabase.forTesting(openEncryptedTestConnection());
}

Future<SyncPolicy> createTestSyncPolicy(AppDatabase database) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return SyncPolicy(
    database,
    CloudSyncEnabler(
      settingsLocal: SettingsLocalDatasource(database),
      preferences: CloudSyncPreferences(prefs),
    ),
  );
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
