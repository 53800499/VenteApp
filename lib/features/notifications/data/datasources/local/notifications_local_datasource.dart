import 'package:drift/drift.dart';

import '../../../../../core/database/app_database.dart' as db;
import '../../../../../core/utils/benin_day_range.dart';
import '../../../../../core/utils/time.dart';
import '../../../domain/entities/notification_entities.dart';

class LowStockProduct {
  const LowStockProduct({
    required this.id,
    required this.name,
    required this.quantity,
  });

  final int id;
  final String name;
  final int quantity;
}

class DebtReminderCandidate {
  const DebtReminderCandidate({
    required this.debtId,
    required this.customerId,
    required this.customerName,
    required this.amountRemaining,
    required this.daysWithoutPayment,
  });

  final int debtId;
  final int customerId;
  final String customerName;
  final int amountRemaining;
  final int daysWithoutPayment;
}

class TodaySalesStats {
  const TodaySalesStats({
    required this.saleCount,
    required this.totalRevenue,
  });

  final int saleCount;
  final int totalRevenue;
}

class NotificationsLocalDatasource {
  NotificationsLocalDatasource(this._database);

  final db.AppDatabase _database;

  static const debtReminderDayOptions = [3, 7, 14, 21, 30];

  static int normalizeDebtReminderDays(int days) {
    return debtReminderDayOptions.contains(days) ? days : 7;
  }

  static bool _readSqlBool(Object? value, {bool defaultValue = true}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return defaultValue;
  }

  static int _readSqlInt(Object? value, {required int defaultValue}) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? defaultValue;
    return defaultValue;
  }

  static String _readSqlString(Object? value, {required String defaultValue}) {
    if (value == null) return defaultValue;
    if (value is String && value.isNotEmpty) return value;
    return defaultValue;
  }

  Future<int> _ensureSettingsId(int shopId) async {
    final existing = await _database.customSelect(
      'SELECT id FROM settings WHERE shop_id = ? LIMIT 1',
      variables: [Variable.withInt(shopId)],
      readsFrom: {_database.settings},
    ).getSingleOrNull();

    if (existing != null) {
      return existing.read<int>('id');
    }

    return _database.into(_database.settings).insert(
          db.SettingsCompanion.insert(
            shopId: shopId,
            updatedAt: nowMs(),
          ),
        );
  }

  Future<NotificationPreferences> loadPreferences(int shopId) async {
    await _ensureSettingsId(shopId);

    final row = await _database.customSelect(
      '''
      SELECT
        COALESCE(enable_stock_alerts, 1) AS enable_stock_alerts,
        COALESCE(enable_debt_reminders, 1) AS enable_debt_reminders,
        COALESCE(debt_reminder_days, 7) AS debt_reminder_days,
        COALESCE(enable_daily_summary, 1) AS enable_daily_summary,
        COALESCE(daily_summary_time, '20:00') AS daily_summary_time,
        COALESCE(enable_backup_reminder, 1) AS enable_backup_reminder,
        COALESCE(enable_good_day_alert, 1) AS enable_good_day_alert,
        COALESCE(default_alert_threshold, 5) AS default_alert_threshold,
        backup_last_at
      FROM settings
      WHERE shop_id = ?
      LIMIT 1
      ''',
      variables: [Variable.withInt(shopId)],
      readsFrom: {_database.settings},
    ).getSingleOrNull();

    if (row == null) {
      return const NotificationPreferences(
        enableStockAlerts: true,
        enableDebtReminders: true,
        debtReminderDays: 7,
        enableDailySummary: true,
        dailySummaryTime: '20:00',
        enableBackupReminder: true,
        enableGoodDayAlert: true,
        defaultAlertThreshold: 5,
      );
    }

    final data = row.data;

    return NotificationPreferences(
      enableStockAlerts: _readSqlBool(data['enable_stock_alerts']),
      enableDebtReminders: _readSqlBool(data['enable_debt_reminders']),
      debtReminderDays: normalizeDebtReminderDays(
        _readSqlInt(data['debt_reminder_days'], defaultValue: 7),
      ),
      enableDailySummary: _readSqlBool(data['enable_daily_summary']),
      dailySummaryTime: _readSqlString(
        data['daily_summary_time'],
        defaultValue: '20:00',
      ),
      enableBackupReminder: _readSqlBool(data['enable_backup_reminder']),
      enableGoodDayAlert: _readSqlBool(data['enable_good_day_alert']),
      defaultAlertThreshold: _readSqlInt(
        data['default_alert_threshold'],
        defaultValue: 5,
      ),
      backupLastAt: data['backup_last_at'] == null
          ? null
          : _readSqlInt(data['backup_last_at'], defaultValue: 0),
    );
  }

  Future<NotificationPreferences> updatePreferences({
    required int shopId,
    required UpdateNotificationSettingsInput input,
  }) async {
    final settingsId = await _ensureSettingsId(shopId);

    await (_database.update(_database.settings)
          ..where((s) => s.id.equals(settingsId)))
        .write(
      db.SettingsCompanion(
        enableStockAlerts: input.enableStockAlerts == null
            ? const Value.absent()
            : Value(input.enableStockAlerts!),
        enableDebtReminders: input.enableDebtReminders == null
            ? const Value.absent()
            : Value(input.enableDebtReminders!),
        debtReminderDays: input.debtReminderDays == null
            ? const Value.absent()
            : Value(input.debtReminderDays!),
        enableDailySummary: input.enableDailySummary == null
            ? const Value.absent()
            : Value(input.enableDailySummary!),
        dailySummaryTime: input.dailySummaryTime == null
            ? const Value.absent()
            : Value(input.dailySummaryTime!),
        enableBackupReminder: input.enableBackupReminder == null
            ? const Value.absent()
            : Value(input.enableBackupReminder!),
        enableGoodDayAlert: input.enableGoodDayAlert == null
            ? const Value.absent()
            : Value(input.enableGoodDayAlert!),
        updatedAt: Value(nowMs()),
      ),
    );

    return loadPreferences(shopId);
  }

  Future<DebtReminderQuota> getDebtReminderQuota(
    int shopId,
    String dayKey,
  ) async {
    final row = await (_database.select(_database.notificationDailyStates)
          ..where(
            (s) => s.shopId.equals(shopId) & s.dayKey.equals(dayKey),
          ))
        .getSingleOrNull();

    final sent = row?.debtRemindersSent ?? 0;
    return DebtReminderQuota(
      sent: sent,
      max: maxDebtRemindersPerDay,
      remaining: (maxDebtRemindersPerDay - sent).clamp(0, maxDebtRemindersPerDay),
      dayKey: dayKey,
    );
  }

  Future<DebtReminderQuota> incrementDebtRemindersSent({
    required int shopId,
    required String dayKey,
    required int count,
  }) async {
    final current = await getDebtReminderQuota(shopId, dayKey);
    final nextSent = (current.sent + count).clamp(0, maxDebtRemindersPerDay);
    final timestamp = nowMs();

    await _database.into(_database.notificationDailyStates).insertOnConflictUpdate(
          db.NotificationDailyStatesCompanion.insert(
            shopId: shopId,
            dayKey: dayKey,
            debtRemindersSent: Value(nextSent),
            updatedAt: timestamp,
          ),
        );

    return DebtReminderQuota(
      sent: nextSent,
      max: maxDebtRemindersPerDay,
      remaining: (maxDebtRemindersPerDay - nextSent).clamp(0, maxDebtRemindersPerDay),
      dayKey: dayKey,
    );
  }

  Future<List<LowStockProduct>> loadLowStockProducts(
    int shopId,
    int defaultThreshold,
  ) async {
    final rows = await (_database.select(_database.products)
          ..where(
            (p) => p.shopId.equals(shopId) & p.isArchived.equals(false),
          ))
        .get();

    final low = rows
        .where((p) {
          final threshold = p.alertThreshold ?? defaultThreshold;
          return p.quantityInStock <= threshold;
        })
        .toList()
      ..sort((a, b) => a.quantityInStock.compareTo(b.quantityInStock));

    return low
        .map(
          (p) => LowStockProduct(
            id: p.id,
            name: p.name,
            quantity: p.quantityInStock,
          ),
        )
        .toList();
  }

  Future<List<DebtReminderCandidate>> loadDebtReminderCandidates({
    required int shopId,
    required int minDaysWithoutPayment,
    required int limit,
  }) async {
    if (limit <= 0) return [];

    final debtRows = await (_database.select(_database.debts)
          ..where(
            (d) =>
                d.shopId.equals(shopId) &
                (d.status.equals('open') | d.status.equals('partial')),
          ))
        .get();
    if (debtRows.isEmpty) return [];

    final now = nowMs();
    const dayMs = 24 * 60 * 60 * 1000;
    final candidates = <DebtReminderCandidate>[];

    for (final debt in debtRows) {
      final customer = await (_database.select(_database.customers)
            ..where((c) => c.id.equals(debt.customerId)))
          .getSingleOrNull();

      final lastActivity = debt.amountPaid == 0
          ? debt.createdAt
          : (debt.updatedAt ?? debt.createdAt);
      final days = ((now - lastActivity) / dayMs).floor();

      if (days < minDaysWithoutPayment) continue;

      candidates.add(
        DebtReminderCandidate(
          debtId: debt.id,
          customerId: debt.customerId,
          customerName: customer?.name ?? 'Client',
          amountRemaining: debt.amountRemaining,
          daysWithoutPayment: days,
        ),
      );
    }

    candidates.sort(
      (a, b) => b.daysWithoutPayment.compareTo(a.daysWithoutPayment),
    );
    return candidates.take(limit).toList();
  }

  Future<TodaySalesStats> loadTodaySalesStats({
    required int shopId,
    required int fromMs,
    required int toMs,
  }) async {
    final rows = await (_database.select(_database.sales)
          ..where(
            (s) =>
                s.shopId.equals(shopId) &
                s.status.equals('completed') &
                s.createdAt.isBiggerOrEqualValue(fromMs) &
                s.createdAt.isSmallerOrEqualValue(toMs),
          ))
        .get();

    return TodaySalesStats(
      saleCount: rows.length,
      totalRevenue: rows.fold<int>(0, (sum, s) => sum + s.totalAmount),
    );
  }

  Future<int> loadMonthBestDayRevenue({
    required int shopId,
    required int monthStartMs,
    required int todayStartMs,
  }) async {
    final rows = await (_database.select(_database.sales)
          ..where(
            (s) =>
                s.shopId.equals(shopId) &
                s.status.equals('completed') &
                s.createdAt.isBiggerOrEqualValue(monthStartMs) &
                s.createdAt.isSmallerThanValue(todayStartMs),
          ))
        .get();

    final dailyTotals = <String, int>{};
    for (final sale in rows) {
      final key = beninDayKey(sale.createdAt);
      dailyTotals[key] = (dailyTotals[key] ?? 0) + sale.totalAmount;
    }

    var best = 0;
    for (final total in dailyTotals.values) {
      if (total > best) best = total;
    }
    return best;
  }

  Future<SyncConflictSummary> loadSyncConflicts(int shopId) async {
    final entities = <SyncConflictEntity>[];

    final sales = await (_database.select(_database.sales)
          ..where(
            (s) =>
                s.shopId.equals(shopId) & s.syncStatus.equals('conflict'),
          ))
        .get();
    for (final s in sales) {
      entities.add(SyncConflictEntity(table: 'sales', id: s.id));
    }

    return SyncConflictSummary(count: entities.length, entities: entities);
  }

  Future<List<ProcurementOverdueOrder>> loadOverduePurchaseOrders(int shopId) async {
    final now = nowMs();
    final rows = await _database.customSelect(
      '''
      SELECT po.id, po.number, COALESCE(s.name, 'Fournisseur') AS supplier_name
      FROM purchase_orders po
      LEFT JOIN suppliers s ON s.id = po.supplier_id
      WHERE po.shop_id = ?
        AND po.status IN ('validated', 'sent', 'partially_received')
        AND po.expected_at IS NOT NULL
        AND po.expected_at < ?
      ORDER BY po.expected_at ASC
      LIMIT 10
      ''',
      variables: [Variable.withInt(shopId), Variable.withInt(now)],
      readsFrom: {_database.purchaseOrders, _database.suppliers},
    ).get();

    return rows
        .map(
          (row) => ProcurementOverdueOrder(
            poId: row.read<int>('id'),
            number: row.read<String>('number'),
            supplierName: row.read<String>('supplier_name'),
          ),
        )
        .toList();
  }

  Future<List<ProcurementOverdueInvoice>> loadOverdueSupplierInvoices(
    int shopId,
  ) async {
    final now = nowMs();
    final rows = await _database.customSelect(
      '''
      SELECT i.id, i.invoice_number, i.total,
        COALESCE((
          SELECT SUM(p.amount) FROM supplier_payments p
          WHERE p.invoice_id = i.id AND p.shop_id = i.shop_id
        ), 0) AS paid
      FROM supplier_invoices i
      WHERE i.shop_id = ?
        AND i.status != 'paid'
        AND i.due_date IS NOT NULL
        AND i.due_date < ?
      ORDER BY i.due_date ASC
      LIMIT 10
      ''',
      variables: [Variable.withInt(shopId), Variable.withInt(now)],
      readsFrom: {_database.supplierInvoices, _database.supplierPayments},
    ).get();

    return rows
        .map((row) {
          final total = row.read<int>('total');
          final paid = row.read<int>('paid');
          final due = total - paid;
          if (due <= 0) return null;
          return ProcurementOverdueInvoice(
            invoiceId: row.read<int>('id'),
            invoiceNumber: row.read<String>('invoice_number'),
            amountDue: due,
          );
        })
        .whereType<ProcurementOverdueInvoice>()
        .toList();
  }

  Future<List<PendingStockTransferRow>> loadPendingStockTransfers(int shopId) async {
    final rows = await (_database.select(_database.stockTransfers)
          ..where(
            (t) =>
                t.destinationShopId.equals(shopId) &
                t.status.isIn([
                  'partially_shipped',
                  'shipped',
                  'partially_received',
                ]),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.shippedAt)]))
        .get();

    final result = <PendingStockTransferRow>[];
    for (final row in rows) {
      final itemRows = await (_database.select(_database.stockTransferItems)
            ..where((i) => i.transferId.equals(row.id)))
          .get();

      var pendingUnits = 0;
      for (final item in itemRows) {
        final pending = item.quantityShipped - item.quantityReceived;
        if (pending > 0) pendingUnits += pending;
      }
      if (pendingUnits <= 0) continue;

      final sourceShop = await (_database.select(_database.shops)
            ..where((s) => s.id.equals(row.sourceShopId)))
          .getSingleOrNull();

      result.add(
        PendingStockTransferRow(
          transferId: row.id,
          reference: row.reference,
          sourceShopName: sourceShop?.name,
          pendingUnits: pendingUnits,
        ),
      );
    }
    return result;
  }
}

class ProcurementOverdueOrder {
  const ProcurementOverdueOrder({
    required this.poId,
    required this.number,
    required this.supplierName,
  });

  final int poId;
  final String number;
  final String supplierName;
}

class ProcurementOverdueInvoice {
  const ProcurementOverdueInvoice({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.amountDue,
  });

  final int invoiceId;
  final String invoiceNumber;
  final int amountDue;
}

class PendingStockTransferRow {
  const PendingStockTransferRow({
    required this.transferId,
    required this.reference,
    required this.pendingUnits,
    this.sourceShopName,
  });

  final int transferId;
  final String reference;
  final String? sourceShopName;
  final int pendingUnits;
}
