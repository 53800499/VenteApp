import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/network/widgets/offline_mode_banner.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/components/app_desktop_data_table.dart';
import '../../../../shared/components/app_header_actions.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../help/presentation/widgets/module_help_button.dart';
import '../../domain/entities/procurement.dart';
import '../../domain/entities/procurement_sync_entities.dart';
import '../bloc/procurement_bloc.dart';
import '../widgets/procurement_reports_tab.dart';
import '../widgets/procurement_sync_banner.dart';

/// Vue Desktop ERP moderne pour le module Achats & Approvisionnements.
/// Optimisée pour Windows et les écrans larges (>= 600px).
class DesktopProcurementView extends StatefulWidget {
  const DesktopProcurementView({
    super.key,
    required this.state,
    required this.canCreate,
    required this.canReceive,
    required this.syncOverview,
    required this.shopId,
    required this.onRefresh,
    required this.onOpenNewPo,
    required this.onOpenDirectProcurement,
    required this.onOpenNewSupplier,
    required this.onOpenPoDetail,
    required this.onOpenDirectReceiptDetail,
    required this.onOpenInvoiceDetail,
    required this.onOpenSupplierDetail,
  });

  final ProcurementState state;
  final bool canCreate;
  final bool canReceive;
  final ProcurementSyncOverview syncOverview;
  final int shopId;
  final VoidCallback onRefresh;
  final VoidCallback onOpenNewPo;
  final VoidCallback onOpenDirectProcurement;
  final VoidCallback onOpenNewSupplier;
  final ValueChanged<int> onOpenPoDetail;
  final ValueChanged<int> onOpenDirectReceiptDetail;
  final ValueChanged<int> onOpenInvoiceDetail;
  final ValueChanged<Supplier> onOpenSupplierDetail;

  @override
  State<DesktopProcurementView> createState() => _DesktopProcurementViewState();
}

class _DesktopProcurementViewState extends State<DesktopProcurementView> {
  final TextEditingController _searchController = TextEditingController();
  int _activeTabIndex = 0; // 0: Commandes, 1: Appro direct, 2: Fournisseurs, 3: Factures, 4: Rapports

  int _sortColumn = 0;
  bool _sortAscending = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSort(int column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = column == 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final state = widget.state;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f2): () {
          if (widget.canCreate) widget.onOpenNewPo();
        },
        const SingleActivator(LogicalKeyboardKey.f5): widget.onRefresh,
      },
      child: Focus(
        autofocus: true,
        child: Container(
          color: cs.surfaceContainerLowest.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Barre de commande ERP supérieure
                _buildCommandHeader(context, theme, cs),

                const SizedBox(height: AppSpacing.sm),

                const OfflineModeBanner(
                  onlinePreferredMessage: OfflineModeBanner.hybridReadMessage,
                ),
                ProcurementSyncBanner(shopId: widget.shopId),

                if (state.status == ProcurementStatus.loading) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: AppSpacing.xs),
                ],

                // 2. 4 Cartes Stratégiques KPIs
                _buildStrategicKpis(context, theme, cs),

                const SizedBox(height: AppSpacing.md),

                // 3. Barre d'onglets ERP
                _buildTabBar(context, theme, cs),

                const SizedBox(height: AppSpacing.sm),

                // 4. Contenu selon l'onglet
                Expanded(
                  child: switch (_activeTabIndex) {
                    0 => _buildOrdersTab(context, theme, cs),
                    1 => _buildDirectReceiptsTab(context, theme, cs),
                    2 => _buildSuppliersTab(context, theme, cs),
                    3 => _buildInvoicesTab(context, theme, cs),
                    4 => ProcurementReportsTab(
                        onRefresh: () async => widget.onRefresh(),
                      ),
                    _ => _buildOrdersTab(context, theme, cs),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. Barre de commande supérieure ERP Desktop
  // ===========================================================================
  Widget _buildCommandHeader(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1120;

        final titleBlock = Row(
          children: [
            if (Navigator.of(context).canPop()) ...[
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                tooltip: 'Retour',
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: cs.primary.withValues(alpha: 0.25)),
              ),
              child: Icon(
                Icons.local_shipping_outlined,
                color: cs.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Achats & Approvisionnements',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          '${widget.state.purchaseOrders.length} commande(s)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cs.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Commandes d\'achat, réceptions directes en stock, gestion fournisseurs et factures',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );

        final actionButtons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.canCreate) ...[
              FilledButton.icon(
                onPressed: widget.onOpenNewPo,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Commande Fournisseur (F2)'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (widget.canReceive) ...[
              OutlinedButton.icon(
                onPressed: widget.onOpenDirectProcurement,
                icon: const Icon(Icons.inventory_2_outlined, size: 16),
                label: const Text('Appro Direct'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (widget.canCreate) ...[
              OutlinedButton.icon(
                onPressed: widget.onOpenNewSupplier,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
                label: const Text('Fournisseur'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            IconButton.filledTonal(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              tooltip: 'Actualiser (F5)',
              onPressed: widget.onRefresh,
            ),
            const SizedBox(width: AppSpacing.xs),
            const ModuleHelpButton(articleId: 'procurement'),
            const AppHeaderActions(),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleBlock,
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: actionButtons,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: AppSpacing.md),
            actionButtons,
          ],
        );
      },
    );
  }

  // ===========================================================================
  // 2. Les 4 Cartes Stratégiques KPIs
  // ===========================================================================
  Widget _buildStrategicKpis(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
  ) {
    final orders = widget.state.purchaseOrders;
    final activeOrders = orders.where((o) =>
        o.status != PurchaseOrderStatus.received &&
        o.status != PurchaseOrderStatus.cancelled).toList();

    final directReceipts = widget.state.directReceipts;
    final suppliers = widget.state.suppliers;
    final unpaidInvoices = widget.state.invoices.where(
        (i) => i.status != SupplierInvoiceStatus.paid).toList();

    final card1 = _ProcurementKpiCard(
      icon: Icons.shopping_bag_outlined,
      label: 'Commandes En Cours',
      value: '${activeOrders.length}',
      subtitle: '${orders.where((o) => o.status == PurchaseOrderStatus.validated).length} validée(s)',
      accentColor: Colors.blue.shade700,
      backgroundColor: Colors.blue.shade50,
    );

    final card2 = _ProcurementKpiCard(
      icon: Icons.inventory_2_outlined,
      label: 'Réceptions Directes',
      value: '${directReceipts.length}',
      subtitle: 'Entrées stock directes',
      accentColor: Colors.amber.shade800,
      backgroundColor: Colors.amber.shade50,
    );

    final card3 = _ProcurementKpiCard(
      icon: Icons.people_alt_outlined,
      label: 'Fournisseurs Actifs',
      value: '${suppliers.where((s) => s.isActive).length}',
      subtitle: 'Sur ${suppliers.length} répertoriés',
      accentColor: AppColors.success,
      backgroundColor: AppColors.success.withValues(alpha: 0.1),
    );

    final totalUnpaidAmount = unpaidInvoices.fold<int>(0, (sum, i) => sum + i.total);
    final card4 = _ProcurementKpiCard(
      icon: Icons.receipt_long_outlined,
      label: 'Dettes Fournisseurs',
      value: formatFcfa(totalUnpaidAmount),
      subtitle: '${unpaidInvoices.length} facture(s) en attente',
      accentColor: unpaidInvoices.isNotEmpty ? AppColors.danger : cs.primary,
      backgroundColor: (unpaidInvoices.isNotEmpty ? AppColors.danger : cs.primary)
          .withValues(alpha: 0.12),
      highlight: unpaidInvoices.isNotEmpty,
      badgeText: unpaidInvoices.isNotEmpty ? 'À régler' : 'À jour',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 960) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(width: 240, child: card1),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(width: 240, child: card2),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(width: 240, child: card3),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(width: 260, child: card4),
              ],
            ),
          );
        }

        return Row(
          children: [
            Expanded(child: card1),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: card2),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: card3),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: card4),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // 3. Barre d'Onglets ERP
  // ===========================================================================
  Widget _buildTabBar(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
  ) {
    return Row(
      children: [
        _buildTabButton(
          index: 0,
          label: 'Commandes Fournisseurs',
          icon: Icons.shopping_bag_outlined,
          badge: '${widget.state.purchaseOrders.length}',
        ),
        const SizedBox(width: AppSpacing.xs),
        _buildTabButton(
          index: 1,
          label: 'Appro Direct',
          icon: Icons.inventory_2_outlined,
          badge: '${widget.state.directReceipts.length}',
        ),
        const SizedBox(width: AppSpacing.xs),
        _buildTabButton(
          index: 2,
          label: 'Fournisseurs',
          icon: Icons.people_alt_outlined,
          badge: '${widget.state.suppliers.length}',
        ),
        const SizedBox(width: AppSpacing.xs),
        _buildTabButton(
          index: 3,
          label: 'Factures d\'Achat',
          icon: Icons.receipt_long_outlined,
          badge: '${widget.state.invoices.length}',
        ),
        const SizedBox(width: AppSpacing.xs),
        _buildTabButton(
          index: 4,
          label: 'Rapports & Synthèse',
          icon: Icons.analytics_outlined,
        ),
      ],
    );
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required IconData icon,
    String? badge,
  }) {
    final isSelected = _activeTabIndex == index;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: () => setState(() => _activeTabIndex = index),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? cs.primaryContainer : cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.6),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? cs.primary.withValues(alpha: 0.2)
                      : cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? cs.primary : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. Onglet 0 : Commandes Fournisseurs
  // ===========================================================================
  Widget _buildOrdersTab(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
  ) {
    var orders = List<PurchaseOrder>.from(widget.state.purchaseOrders);
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      orders = orders.where((o) {
        final numMatch = o.number.toLowerCase().contains(query);
        final suppMatch = o.supplierName?.toLowerCase().contains(query) ?? false;
        final notesMatch = o.notes?.toLowerCase().contains(query) ?? false;
        return numMatch || suppMatch || notesMatch;
      }).toList();
    }

    orders.sort((a, b) {
      int cmp = 0;
      if (_sortColumn == 0) {
        cmp = a.orderedAt.compareTo(b.orderedAt);
      } else if (_sortColumn == 1) {
        cmp = a.number.toLowerCase().compareTo(b.number.toLowerCase());
      } else {
        cmp = a.total.compareTo(b.total);
      }
      return _sortAscending ? cmp : -cmp;
    });

    final columns = [
      AppTableColumn(
        label: 'Date',
        icon: Icons.calendar_today_rounded,
        minWidth: 130,
        flex: 2,
        isSorted: _sortColumn == 0,
        sortAscending: _sortAscending,
        onSort: () => _toggleSort(0),
      ),
      AppTableColumn(
        label: 'N° Commande',
        icon: Icons.tag_rounded,
        minWidth: 150,
        flex: 2,
        isSorted: _sortColumn == 1,
        sortAscending: _sortAscending,
        onSort: () => _toggleSort(1),
      ),
      const AppTableColumn(
        label: 'Fournisseur',
        icon: Icons.storefront_outlined,
        minWidth: 200,
        flex: 3,
      ),
      const AppTableColumn(
        label: 'Articles',
        icon: Icons.inventory_2_outlined,
        minWidth: 120,
        flex: 1,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
      const AppTableColumn(
        label: 'Statut',
        icon: Icons.verified_outlined,
        minWidth: 140,
        flex: 2,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
      AppTableColumn(
        label: 'Total TTC',
        icon: Icons.payments_outlined,
        minWidth: 140,
        flex: 2,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
        isSorted: _sortColumn == 2,
        sortAscending: _sortAscending,
        onSort: () => _toggleSort(2),
      ),
      const AppTableColumn(
        label: 'Actions',
        minWidth: 90,
        flex: 1,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
    ];

    final rows = orders.map((po) {
      final dt = DateTime.fromMillisecondsSinceEpoch(po.orderedAt);
      final itemCount = po.items?.length ?? 0;
      final totalQty = (po.items ?? []).fold<int>(0, (sum, i) => sum + i.quantityOrdered);

      return AppTableRow(
        onTap: () => widget.onOpenPoDetail(po.id),
        cells: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppDateFormatter.formatDate(dt),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                'à ${AppDateFormatter.formatTime(dt)}',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
          Text(
            '#${po.number}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          Text(
            po.supplierName ?? 'Fournisseur #${po.supplierId}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
          Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '$itemCount réf ($totalQty u.)',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: _buildPoStatusBadge(po.status, cs),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              formatFcfa(po.total),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: OutlinedButton(
              onPressed: () => widget.onOpenPoDetail(po.id),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: const Text('Détails'),
            ),
          ),
        ],
      );
    }).toList();

    return _buildTabContainer(
      searchHint: 'Rechercher commande, fournisseur...',
      countLabel: '${orders.length} commande(s)',
      totalLabel: 'Total : ${formatFcfa(orders.fold<int>(0, (sum, o) => sum + o.total))}',
      table: AppDesktopDataTable(columns: columns, rows: rows, minWidth: 970),
      emptyTitle: 'Aucune commande d\'approvisionnement trouvée',
      emptySubtitle: 'Créez un bon de commande pour commander vos stocks auprès des fournisseurs.',
      canCreate: widget.canCreate,
      createButtonText: 'Créer une commande (F2)',
      onCreateAction: widget.onOpenNewPo,
      isEmpty: orders.isEmpty,
    );
  }

  // ===========================================================================
  // 5. Onglet 1 : Appro Direct
  // ===========================================================================
  Widget _buildDirectReceiptsTab(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
  ) {
    var receipts = List<PurchaseReceipt>.from(widget.state.directReceipts);
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      receipts = receipts.where((r) {
        final numMatch = r.receiptNumber.toLowerCase().contains(query);
        final suppMatch = r.supplierName?.toLowerCase().contains(query) ?? false;
        final notesMatch = r.notes?.toLowerCase().contains(query) ?? false;
        return numMatch || suppMatch || notesMatch;
      }).toList();
    }

    final columns = [
      const AppTableColumn(
        label: 'Date de réception',
        icon: Icons.calendar_today_rounded,
        minWidth: 140,
        flex: 2,
      ),
      const AppTableColumn(
        label: 'N° Réception',
        icon: Icons.receipt_outlined,
        minWidth: 150,
        flex: 2,
      ),
      const AppTableColumn(
        label: 'Fournisseur',
        icon: Icons.storefront_outlined,
        minWidth: 200,
        flex: 3,
      ),
      const AppTableColumn(
        label: 'Articles Réceptionnés',
        icon: Icons.inventory_2_outlined,
        minWidth: 160,
        flex: 2,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
      const AppTableColumn(
        label: 'Réceptionnaire',
        icon: Icons.person_outline_rounded,
        minWidth: 160,
        flex: 2,
      ),
      const AppTableColumn(
        label: 'Actions',
        minWidth: 90,
        flex: 1,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
    ];

    final rows = receipts.map((r) {
      final dt = DateTime.fromMillisecondsSinceEpoch(r.receivedAt);
      final totalQty = (r.items ?? []).fold<int>(0, (sum, i) => sum + i.quantityReceived);

      return AppTableRow(
        onTap: () => widget.onOpenDirectReceiptDetail(r.id),
        cells: [
          Text(AppDateFormatter.formatDate(dt), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text('#${r.receiptNumber}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          Text(r.supplierName ?? 'Fournisseur #${r.supplierId}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '${r.items?.length ?? 0} réf ($totalQty u.)',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          Text(r.receivedByName ?? 'Agent #${r.receivedBy}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          Align(
            alignment: Alignment.center,
            child: OutlinedButton(
              onPressed: () => widget.onOpenDirectReceiptDetail(r.id),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: const Text('Détails'),
            ),
          ),
        ],
      );
    }).toList();

    return _buildTabContainer(
      searchHint: 'Rechercher réception, fournisseur...',
      countLabel: '${receipts.length} réception(s)',
      totalLabel: null,
      table: AppDesktopDataTable(columns: columns, rows: rows, minWidth: 900),
      emptyTitle: 'Aucun approvisionnement direct enregistré',
      emptySubtitle: 'Enregistrez vos réceptions d\'achat immédiates sans commande préalable.',
      canCreate: widget.canReceive,
      createButtonText: 'Nouvel appro direct',
      onCreateAction: widget.onOpenDirectProcurement,
      isEmpty: receipts.isEmpty,
    );
  }

  // ===========================================================================
  // 6. Onglet 2 : Fournisseurs
  // ===========================================================================
  Widget _buildSuppliersTab(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
  ) {
    var suppliers = List<Supplier>.from(widget.state.suppliers);
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      suppliers = suppliers.where((s) {
        final nameMatch = s.name.toLowerCase().contains(query);
        final phoneMatch = s.phone?.toLowerCase().contains(query) ?? false;
        final emailMatch = s.email?.toLowerCase().contains(query) ?? false;
        return nameMatch || phoneMatch || emailMatch;
      }).toList();
    }

    final columns = [
      const AppTableColumn(
        label: 'Fournisseur',
        icon: Icons.storefront_outlined,
        minWidth: 220,
        flex: 3,
      ),
      const AppTableColumn(
        label: 'Téléphone',
        icon: Icons.phone_outlined,
        minWidth: 140,
        flex: 2,
      ),
      const AppTableColumn(
        label: 'Email',
        icon: Icons.email_outlined,
        minWidth: 180,
        flex: 2,
      ),
      const AppTableColumn(
        label: 'Adresse',
        icon: Icons.location_on_outlined,
        minWidth: 180,
        flex: 2,
      ),
      const AppTableColumn(
        label: 'Statut',
        icon: Icons.verified_outlined,
        minWidth: 100,
        flex: 1,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
      const AppTableColumn(
        label: 'Actions',
        minWidth: 90,
        flex: 1,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
    ];

    final rows = suppliers.map((s) {
      return AppTableRow(
        onTap: () => widget.onOpenSupplierDetail(s),
        cells: [
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  s.name.isNotEmpty ? s.name[0].toUpperCase() : 'F',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(s.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
            ],
          ),
          Text(s.phone ?? '—', style: const TextStyle(fontSize: 12)),
          Text(s.email ?? '—', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant), overflow: TextOverflow.ellipsis),
          Text(s.address ?? '—', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant), overflow: TextOverflow.ellipsis),
          Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (s.isActive ? AppColors.success : cs.outline).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                s.isActive ? 'Actif' : 'Inactif',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: s.isActive ? AppColors.success : cs.outline,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: OutlinedButton(
              onPressed: () => widget.onOpenSupplierDetail(s),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: const Text('Modifier'),
            ),
          ),
        ],
      );
    }).toList();

    return _buildTabContainer(
      searchHint: 'Rechercher nom, téléphone...',
      countLabel: '${suppliers.length} fournisseur(s)',
      totalLabel: null,
      table: AppDesktopDataTable(columns: columns, rows: rows, minWidth: 910),
      emptyTitle: 'Aucun fournisseur enregistré',
      emptySubtitle: 'Enregistrez vos fournisseurs pour centraliser vos achats et contacts.',
      canCreate: widget.canCreate,
      createButtonText: 'Ajouter un fournisseur',
      onCreateAction: widget.onOpenNewSupplier,
      isEmpty: suppliers.isEmpty,
    );
  }

  // ===========================================================================
  // 7. Onglet 3 : Factures Fournisseurs
  // ===========================================================================
  Widget _buildInvoicesTab(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
  ) {
    var invoices = List<SupplierInvoice>.from(widget.state.invoices);
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      invoices = invoices.where((i) {
        final numMatch = i.invoiceNumber.toLowerCase().contains(query);
        final suppMatch = i.supplierName?.toLowerCase().contains(query) ?? false;
        return numMatch || suppMatch;
      }).toList();
    }

    final columns = [
      const AppTableColumn(
        label: 'Date Facture',
        icon: Icons.calendar_today_rounded,
        minWidth: 130,
        flex: 2,
      ),
      const AppTableColumn(
        label: 'N° Facture',
        icon: Icons.receipt_outlined,
        minWidth: 150,
        flex: 2,
      ),
      const AppTableColumn(
        label: 'Fournisseur',
        icon: Icons.storefront_outlined,
        minWidth: 200,
        flex: 3,
      ),
      const AppTableColumn(
        label: 'Statut Paiement',
        icon: Icons.payments_outlined,
        minWidth: 140,
        flex: 2,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
      const AppTableColumn(
        label: 'Montant Total',
        icon: Icons.account_balance_wallet_outlined,
        minWidth: 140,
        flex: 2,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Actions',
        minWidth: 90,
        flex: 1,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
    ];

    final rows = invoices.map((i) {
      final dt = DateTime.fromMillisecondsSinceEpoch(i.invoiceDate);

      return AppTableRow(
        onTap: () => widget.onOpenInvoiceDetail(i.id),
        cells: [
          Text(AppDateFormatter.formatDate(dt), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text('#${i.invoiceNumber}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          Text(i.supplierName ?? 'Fournisseur #${i.supplierId}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Align(
            alignment: Alignment.center,
            child: _buildInvoiceStatusBadge(i.status, cs),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              formatFcfa(i.total),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: i.status == SupplierInvoiceStatus.paid ? AppColors.success : AppColors.danger,
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: OutlinedButton(
              onPressed: () => widget.onOpenInvoiceDetail(i.id),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: const Text('Détails'),
            ),
          ),
        ],
      );
    }).toList();

    return _buildTabContainer(
      searchHint: 'Rechercher facture, fournisseur...',
      countLabel: '${invoices.length} facture(s)',
      totalLabel: 'Total facturé : ${formatFcfa(invoices.fold<int>(0, (sum, i) => sum + i.total))}',
      table: AppDesktopDataTable(columns: columns, rows: rows, minWidth: 850),
      emptyTitle: 'Aucune facture d\'achat enregistrée',
      emptySubtitle: 'Les factures fournisseurs vous permettent de suivre vos dettes et échéances.',
      canCreate: false,
      createButtonText: null,
      onCreateAction: null,
      isEmpty: invoices.isEmpty,
    );
  }

  // ===========================================================================
  // Container de Recherche & Table
  // ===========================================================================
  Widget _buildTabContainer({
    required String searchHint,
    required String countLabel,
    required String? totalLabel,
    required Widget table,
    required String emptyTitle,
    required String emptySubtitle,
    required bool canCreate,
    required String? createButtonText,
    required VoidCallback? onCreateAction,
    required bool isEmpty,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 320,
                height: 38,
                child: TextField(
                  controller: _searchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: searchHint,
                    hintStyle: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const Spacer(),
              Text(countLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              if (totalLabel != null) ...[
                const SizedBox(width: 4),
                Text('· $totalLabel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary)),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: isEmpty
              ? Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
                  ),
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          EmptyListPlaceholder(
                            icon: Icons.local_shipping_outlined,
                            title: emptyTitle,
                            subtitle: emptySubtitle,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (canCreate && onCreateAction != null && createButtonText != null)
                            FilledButton.icon(
                              onPressed: onCreateAction,
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: Text(createButtonText),
                            ),
                        ],
                      ),
                    ),
                  ),
                )
              : Card(
                  elevation: 0,
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: table,
                ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================
  Widget _buildPoStatusBadge(PurchaseOrderStatus status, ColorScheme cs) {
    final (label, color, icon) = switch (status) {
      PurchaseOrderStatus.draft => ('Brouillon', cs.outline, Icons.edit_note_rounded),
      PurchaseOrderStatus.validated => ('Validée', Colors.blue.shade700, Icons.thumb_up_alt_outlined),
      PurchaseOrderStatus.sent => ('Envoyée', Colors.indigo.shade700, Icons.send_rounded),
      PurchaseOrderStatus.partiallyReceived => ('Part. reçue', Colors.orange.shade800, Icons.hourglass_bottom_rounded),
      PurchaseOrderStatus.received => ('Reçue', AppColors.success, Icons.check_circle_outline_rounded),
      PurchaseOrderStatus.cancelled => ('Annulée', AppColors.danger, Icons.cancel_outlined),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildInvoiceStatusBadge(SupplierInvoiceStatus status, ColorScheme cs) {
    final (label, color) = switch (status) {
      SupplierInvoiceStatus.paid => ('Payée', AppColors.success),
      SupplierInvoiceStatus.partiallyPaid => ('Part. payée', Colors.orange.shade800),
      SupplierInvoiceStatus.unpaid => ('Impayée', AppColors.danger),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

class _ProcurementKpiCard extends StatelessWidget {
  const _ProcurementKpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.accentColor,
    required this.backgroundColor,
    this.highlight = false,
    this.badgeText,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color accentColor;
  final Color backgroundColor;
  final bool highlight;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: highlight
              ? accentColor.withValues(alpha: 0.5)
              : cs.outlineVariant.withValues(alpha: 0.6),
          width: highlight ? 1.5 : 1.0,
        ),
      ),
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, size: 16, color: accentColor),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badgeText != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      badgeText!,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
                color: highlight ? accentColor : cs.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
