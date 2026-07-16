import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/procurement.dart';
import '../../domain/repositories/procurement_repository.dart';
import '../bloc/procurement_bloc.dart';
import '../models/po_form_prefill.dart';
import '../pages/po_form_page.dart';
import '../pages/invoice_detail_page.dart';
import '../pages/direct_receipt_detail_page.dart';
import '../pages/procurement_page.dart';

/// Ouvre le formulaire commande avec bloc dédié (depuis inventaire, alertes, etc.).
Future<T?> openPoFormPage<T>(
  BuildContext context,
  AuthSession session, {
  PurchaseOrder? orderToEdit,
  PoFormPrefill? prefill,
}) {
  ensureProcurementDependencies();

  return Navigator.of(context).push<T>(
    MaterialPageRoute(
      builder: (_) => BlocProvider(
        create: (_) => ProcurementBloc(
          repository: sl<ProcurementRepository>(),
          session: session,
        )..add(const ProcurementSuppliersLoadRequested()),
        child: PoFormPage(
          orderToEdit: orderToEdit,
          prefill: prefill,
        ),
      ),
    ),
  );
}

/// Ouvre le détail d'une facture fournisseur.
Future<T?> openInvoiceDetailPage<T>(
  BuildContext context,
  AuthSession session, {
  required int invoiceId,
}) {
  ensureProcurementDependencies();

  return Navigator.of(context).push<T>(
    MaterialPageRoute(
      builder: (_) => BlocProvider(
        create: (_) => ProcurementBloc(
          repository: sl<ProcurementRepository>(),
          session: session,
        )..add(ProcurementInvoiceDetailLoadRequested(invoiceId)),
        child: InvoiceDetailPage(invoiceId: invoiceId),
      ),
    ),
  );
}

/// Ouvre le détail d'un approvisionnement direct.
Future<T?> openDirectReceiptDetailPage<T>(
  BuildContext context,
  AuthSession session, {
  required int receiptId,
}) {
  ensureProcurementDependencies();

  return Navigator.of(context).push<T>(
    MaterialPageRoute(
      builder: (_) => BlocProvider(
        create: (_) => ProcurementBloc(
          repository: sl<ProcurementRepository>(),
          session: session,
        )..add(ProcurementDirectReceiptDetailLoadRequested(receiptId)),
        child: DirectReceiptDetailPage(receiptId: receiptId),
      ),
    ),
  );
}

/// Ouvre le module approvisionnement (onglet optionnel : 0 commandes, 1 appro direct, 3 factures, 4 rapports).
Future<T?> openProcurementPage<T>(
  BuildContext context,
  AuthSession session, {
  int initialTab = 0,
}) {
  ensureProcurementDependencies();

  return Navigator.of(context).push<T>(
    MaterialPageRoute(
      builder: (_) => ProcurementPage(
        session: session,
        initialTab: initialTab,
      ),
    ),
  );
}
