import 'package:drift/drift.dart';

@DataClassName('LocalLicenseData')
class LocalLicenses extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text()();
  TextColumn get planCode => text()(); // FREE, STANDARD, PRO, ENTERPRISE
  TextColumn get status => text()(); // TRIAL, ACTIVE, GRACE, EXPIRED, RESTRICTED, SUSPENDED
  IntColumn get maxUsers => integer().withDefault(const Constant(1))();
  IntColumn get maxShops => integer().withDefault(const Constant(1))();
  TextColumn get grantedModulesJson => text()(); // e.g. ["sales", "inventory", "expenses"]
  DateTimeColumn get validUntil => dateTime()();
  DateTimeColumn get graceUntil => dateTime()();
  DateTimeColumn get lastKnownTimestamp => dateTime()(); // High-water mark for clock-tampering detection
  TextColumn get signature => text()(); // Cryptographic signature of the payload
  DateTimeColumn get lastSyncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
