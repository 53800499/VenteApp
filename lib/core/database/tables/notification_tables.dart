import 'package:drift/drift.dart';

import 'auth_tables.dart';

/// Quota journalier des rappels dette — RG-NOTIF-03.
class NotificationDailyStates extends Table {
  IntColumn get shopId => integer().references(Shops, #id)();
  TextColumn get dayKey => text()();
  IntColumn get debtRemindersSent =>
      integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column> get primaryKey => {shopId, dayKey};
}
