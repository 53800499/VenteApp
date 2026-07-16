import 'package:flutter/material.dart';

import '../../features/procurement/presentation/utils/procurement_navigation.dart';
import '../../features/auth/domain/entities/auth_entities.dart';
import '../../features/customers/presentation/pages/customer_detail_page.dart';
import '../../features/inventory/presentation/pages/product_list_page.dart';
import '../../features/reports/presentation/pages/reports_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/sync/presentation/pages/sync_conflicts_page.dart';

/// Gestion des deep links notification — RG-NOTIF-05.
class NotificationDeepLinkHandler {
  NotificationDeepLinkHandler();

  String? _pendingDeepLink;

  String? consumePending() {
    final link = _pendingDeepLink;
    _pendingDeepLink = null;
    return link;
  }

  void store(String deepLink) {
    _pendingDeepLink = deepLink;
  }

  void handle(BuildContext context, String deepLink, AuthSession session) {
    if (!context.mounted) {
      store(deepLink);
      return;
    }

    if (deepLink.startsWith('/customers/')) {
      final id = int.tryParse(deepLink.split('/').last);
      if (id != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CustomerDetailPage(
              session: session,
              customerId: id,
            ),
          ),
        );
      }
      return;
    }

    if (deepLink.startsWith('/procurement/invoices/')) {
      final id = int.tryParse(deepLink.split('/').last);
      if (id != null) {
        openInvoiceDetailPage(context, session, invoiceId: id);
      }
      return;
    }

    if (deepLink.startsWith('/procurement/invoices')) {
      openProcurementPage(context, session, initialTab: 3);
      return;
    }

    if (deepLink.startsWith('/procurement')) {
      openProcurementPage(context, session);
      return;
    }

    if (deepLink.startsWith('/products/low-stock')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductListPage(
            session: session,
            initialLowStockOnly: true,
          ),
        ),
      );
      return;
    }

    if (deepLink.startsWith('/reports')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ReportsPage(session: session),
        ),
      );
      return;
    }

    if (deepLink.startsWith('/settings/backup') ||
        deepLink.startsWith('/settings')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SettingsPage(session: session),
        ),
      );
      return;
    }

    if (deepLink.startsWith('/sync/conflicts')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SyncConflictsPage(session: session),
        ),
      );
      return;
    }
  }
}
