import '../../../../core/utils/benin_day_range.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/time.dart';
import '../entities/notification_entities.dart';
import '../../data/datasources/local/notifications_local_datasource.dart';

/// Agrégation locale du feed — miroir backend `NotificationFeedService`.
class NotificationFeedBuilder {
  const NotificationFeedBuilder(this._local);

  final NotificationsLocalDatasource _local;

  Future<NotificationFeed> build({required int shopId, int? atMs}) async {
    final now = atMs ?? nowMs();
    final dayKey = beninDayKey(now);
    final preferences = await _local.loadPreferences(shopId);
    final quota = await _local.getDebtReminderQuota(shopId, dayKey);

    final lowStock = preferences.enableStockAlerts
        ? await _local.loadLowStockProducts(
            shopId,
            preferences.defaultAlertThreshold,
          )
        : <LowStockProduct>[];

    final debtCandidates = preferences.enableDebtReminders && quota.remaining > 0
        ? await _local.loadDebtReminderCandidates(
            shopId: shopId,
            minDaysWithoutPayment: preferences.debtReminderDays,
            limit: quota.remaining,
          )
        : <DebtReminderCandidate>[];

    final dayBounds = getBeninDayBounds(now);
    final todayStats = await _local.loadTodaySalesStats(
      shopId: shopId,
      fromMs: dayBounds.dayStartMs,
      toMs: dayBounds.dayEndMs,
    );

    final monthBest = preferences.enableGoodDayAlert
        ? await _local.loadMonthBestDayRevenue(
            shopId: shopId,
            monthStartMs: beninMonthStartMs(now),
            todayStartMs: dayBounds.dayStartMs,
          )
        : 0;

    final syncConflicts = await _local.loadSyncConflicts(shopId);
    final dailySummary = _buildDailySummary(preferences, todayStats);
    final items = <NotificationItem>[];

    if (preferences.enableStockAlerts && lowStock.isNotEmpty) {
      final names = lowStock.take(3).map((p) => p.name).join(', ');
      final extra =
          lowStock.length > 3 ? ' et ${lowStock.length - 3} autre(s)' : '';
      items.add(
        NotificationItem(
          code: NotificationCode.stockLow.label,
          channel: 'stock',
          title: 'Stock faible',
          body: '${lowStock.length} produit(s) sous le seuil : $names$extra.',
          deepLink: '/products/low-stock',
          configurable: true,
          alwaysOn: false,
          payload: {
            'productIds': lowStock.map((p) => p.id).toList(),
            'count': lowStock.length,
          },
        ),
      );
    }

    if (preferences.enableStockAlerts) {
      final overdueOrders =
          await _local.loadOverduePurchaseOrders(shopId);
      if (overdueOrders.isNotEmpty) {
        final preview = overdueOrders
            .take(2)
            .map((o) => '#${o.number}')
            .join(', ');
        final extra = overdueOrders.length > 2
            ? ' et ${overdueOrders.length - 2} autre(s)'
            : '';
        items.add(
          NotificationItem(
            code: NotificationCode.procurementOverdue.label,
            channel: 'procurement',
            title: 'Commandes en retard',
            body:
                '${overdueOrders.length} commande(s) dépassent la date prévue : $preview$extra.',
            deepLink: '/procurement',
            configurable: true,
            alwaysOn: false,
            payload: {
              'poIds': overdueOrders.map((o) => o.poId).toList(),
              'count': overdueOrders.length,
            },
          ),
        );
      }

      final overdueInvoices =
          await _local.loadOverdueSupplierInvoices(shopId);
      if (overdueInvoices.isNotEmpty) {
        final preview = overdueInvoices
            .take(2)
            .map((i) => '#${i.invoiceNumber}')
            .join(', ');
        items.add(
          NotificationItem(
            code: NotificationCode.procurementInvoiceDue.label,
            channel: 'procurement',
            title: 'Factures fournisseur échues',
            body:
                '${overdueInvoices.length} facture(s) impayée(s) après échéance : $preview.',
            deepLink: '/procurement/invoices',
            configurable: true,
            alwaysOn: false,
            payload: {
              'invoiceIds': overdueInvoices.map((i) => i.invoiceId).toList(),
              'count': overdueInvoices.length,
            },
          ),
        );
      }
    }

    if (preferences.enableStockAlerts) {
      final pendingTransfers = await _local.loadPendingStockTransfers(shopId);
      for (final transfer in pendingTransfers.take(3)) {
        items.add(
          NotificationItem(
            code: NotificationCode.stockTransferIncoming.label,
            channel: 'stock',
            title: 'Transfert entrant',
            body:
                '${transfer.reference} depuis '
                '${transfer.sourceShopName ?? 'une autre boutique'} '
                '(${transfer.pendingUnits} u à recevoir).',
            deepLink: '/stock-transfers/${transfer.transferId}',
            configurable: true,
            alwaysOn: false,
            payload: {
              'transferId': transfer.transferId,
              'pendingUnits': transfer.pendingUnits,
            },
          ),
        );
      }
    }

    for (final debt in debtCandidates) {
      items.add(
        NotificationItem(
          code: NotificationCode.debtReminder.label,
          channel: 'debt',
          title: 'Rappel dette',
          body:
              '${debt.customerName} doit ${formatFcfa(debt.amountRemaining)} '
              '(${debt.daysWithoutPayment} j. sans paiement).',
          deepLink: '/customers/${debt.customerId}',
          configurable: true,
          alwaysOn: false,
          payload: {
            'debtId': debt.debtId,
            'customerId': debt.customerId,
            'amountRemaining': debt.amountRemaining,
            'daysWithoutPayment': debt.daysWithoutPayment,
          },
        ),
      );
    }

    if (preferences.enableBackupReminder &&
        _isBackupOverdue(preferences.backupLastAt, now)) {
      items.add(
        NotificationItem(
          code: NotificationCode.backupReminder.label,
          channel: 'system',
          title: 'Sauvegarde recommandée',
          body:
              'Votre dernière sauvegarde date de plus de 7 jours. '
              'Pensez à exporter vos données.',
          deepLink: '/settings/backup',
          configurable: true,
          alwaysOn: false,
          payload: {'backupLastAt': preferences.backupLastAt},
        ),
      );
    }

    if (preferences.enableGoodDayAlert &&
        todayStats.saleCount > 0 &&
        todayStats.totalRevenue > monthBest) {
      items.add(
        NotificationItem(
          code: NotificationCode.goodDay.label,
          channel: 'summary',
          title: 'Bonne journée !',
          body:
              'Record du mois : ${formatFcfa(todayStats.totalRevenue)} de CA aujourd\'hui.',
          deepLink: '/reports?period=today',
          configurable: true,
          alwaysOn: false,
          payload: {
            'todayRevenue': todayStats.totalRevenue,
            'previousBest': monthBest,
          },
        ),
      );
    }

    if (syncConflicts.count > 0) {
      items.add(
        NotificationItem(
          code: NotificationCode.syncConflict.label,
          channel: 'sync',
          title: 'Conflit de synchronisation',
          body:
              '${syncConflicts.count} enregistrement(s) en conflit — résolution requise.',
          deepLink: '/sync/conflicts',
          configurable: false,
          alwaysOn: true,
          payload: {
            'count': syncConflicts.count,
            'entities': syncConflicts.entities
                .map((e) => {'table': e.table, 'id': e.id})
                .toList(),
          },
        ),
      );
    }

    return NotificationFeed(
      preferences: preferences,
      debtReminderQuota: quota,
      dailySummary: dailySummary,
      syncConflicts: syncConflicts,
      items: items,
      generatedAt: now,
    );
  }

  DailySummaryPreview _buildDailySummary(
    NotificationPreferences preferences,
    TodaySalesStats todayStats,
  ) {
    if (!preferences.enableDailySummary) {
      return DailySummaryPreview(
        eligible: false,
        scheduledTime: preferences.dailySummaryTime,
        saleCount: todayStats.saleCount,
        totalRevenue: todayStats.totalRevenue,
        reason: 'Résumé journalier désactivé',
      );
    }
    if (todayStats.saleCount == 0) {
      return DailySummaryPreview(
        eligible: false,
        scheduledTime: preferences.dailySummaryTime,
        saleCount: 0,
        totalRevenue: 0,
        reason: 'Aucune vente aujourd\'hui (RG-NOTIF-04)',
      );
    }
    return DailySummaryPreview(
      eligible: true,
      scheduledTime: preferences.dailySummaryTime,
      saleCount: todayStats.saleCount,
      totalRevenue: todayStats.totalRevenue,
    );
  }

  bool _isBackupOverdue(int? backupLastAt, int now) {
    if (backupLastAt == null) return true;
    return now - backupLastAt >= backupReminderAgeMs;
  }
}
