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
import '../../../../shared/components/skeleton_loaders.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../help/presentation/widgets/module_help_button.dart';
import '../../domain/entities/sales_order.dart';
import '../bloc/sales_order_bloc.dart';

/// Vue Desktop ERP moderne pour le module Commandes Clients & Livraisons.
/// Optimisée pour Windows et les écrans larges (>= 600px).
class DesktopSalesOrdersView extends StatefulWidget {
  const DesktopSalesOrdersView({
    super.key,
    required this.session,
    required this.state,
    required this.canWrite,
    required this.onRefresh,
    required this.onOpenCreate,
    required this.onOpenDetail,
    required this.onStatusFilterChanged,
    required this.onSearchChanged,
    required this.onPeriodChanged,
    required this.activePeriodDays,
  });

  final AuthSession session;
  final SalesOrderState state;
  final bool canWrite;
  final VoidCallback onRefresh;
  final VoidCallback onOpenCreate;
  final ValueChanged<SalesOrder> onOpenDetail;
  final ValueChanged<SalesOrderStatus?> onStatusFilterChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onPeriodChanged;
  final int activePeriodDays;

  @override
  State<DesktopSalesOrdersView> createState() => _DesktopSalesOrdersViewState();
}

class _DesktopSalesOrdersViewState extends State<DesktopSalesOrdersView> {
  final TextEditingController _searchController = TextEditingController();
  int _activeTabIndex = 0; // 0: Commandes, 1: Rapports & Livraisons
  SalesOrderStatus? _statusFilter;

  // Tri des colonnes : 0 = Date, 1 = N°, 2 = Client, 3 = Total
  int _sortColumn = 0;
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.state.filterStatus;
    _searchController.text = widget.state.search;
  }

  @override
  void didUpdateWidget(DesktopSalesOrdersView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.filterStatus != oldWidget.state.filterStatus) {
      _statusFilter = widget.state.filterStatus;
    }
  }

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
        _sortAscending = column == 1 || column == 2;
      }
    });
  }

  List<SalesOrder> get _sortedOrders {
    final list = List<SalesOrder>.from(widget.state.orders);
    list.sort((a, b) {
      int cmp = 0;
      switch (_sortColumn) {
        case 0:
          cmp = a.orderedAt.compareTo(b.orderedAt);
          break;
        case 1:
          cmp = a.number.toLowerCase().compareTo(b.number.toLowerCase());
          break;
        case 2:
          cmp = a.customerName.toLowerCase().compareTo(b.customerName.toLowerCase());
          break;
        case 3:
          cmp = a.total.compareTo(b.total);
          break;
        default:
          cmp = a.orderedAt.compareTo(b.orderedAt);
      }
      return _sortAscending ? cmp : -cmp;
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final state = widget.state;
    final orders = _sortedOrders;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f2): () {
          if (widget.canWrite) widget.onOpenCreate();
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

                if (state.status == SalesOrderViewStatus.loading) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: AppSpacing.xs),
                ],

                // 2. 4 KPIs stratégiques consolidés
                _buildStrategicKpis(context, theme, cs, state.orders),

                const SizedBox(height: AppSpacing.md),

                // 3. Barre d'onglets ERP
                _buildTabBar(context, theme, cs, state.orders.length),

                const SizedBox(height: AppSpacing.sm),

                // 4. Contenu selon l'onglet actif
                Expanded(
                  child: _activeTabIndex == 0
                      ? _buildOrdersTab(context, theme, cs, orders)
                      : _buildReportsTab(context, theme, cs),
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
        final isCompact = constraints.maxWidth < 1050;

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
                Icons.assignment_outlined,
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
                          'Commandes Clients & Livraisons',
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
                          '${widget.state.orders.length} commande(s)',
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
                    'Suivi des réservations, préparation de colis, acomptes et bons de livraison',
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
            if (widget.canWrite) ...[
              FilledButton.icon(
                onPressed: widget.onOpenCreate,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nouvelle Commande (F2)'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
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
            const ModuleHelpButton(articleId: 'sales_orders'),
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
    List<SalesOrder> orders,
  ) {
    final activeOrders = orders.where((o) =>
        o.status == SalesOrderStatus.draft ||
        o.status == SalesOrderStatus.confirmed ||
        o.status == SalesOrderStatus.preparing).toList();

    final toDeliver = orders.where((o) =>
        o.status == SalesOrderStatus.preparing ||
        o.status == SalesOrderStatus.partiallyDelivered).toList();

    final deliveredOrClosed = orders.where((o) =>
        o.status == SalesOrderStatus.delivered ||
        o.status == SalesOrderStatus.closed).toList();

    final totalActiveVolume = activeOrders.fold<int>(0, (sum, o) => sum + o.total);

    final card1 = _OrderKpiCard(
      icon: Icons.pending_actions_rounded,
      label: 'Commandes En Cours',
      value: '${activeOrders.length}',
      subtitle: '${orders.where((o) => o.status == SalesOrderStatus.confirmed).length} confirmée(s)',
      accentColor: Colors.blue.shade700,
      backgroundColor: Colors.blue.shade50,
    );

    final card2 = _OrderKpiCard(
      icon: Icons.local_shipping_outlined,
      label: 'À Livrer / En Prépa',
      value: '${toDeliver.length}',
      subtitle: '${orders.where((o) => o.status == SalesOrderStatus.partiallyDelivered).length} livraison(s) partielle(s)',
      accentColor: Colors.amber.shade800,
      backgroundColor: Colors.amber.shade50,
    );

    final card3 = _OrderKpiCard(
      icon: Icons.check_circle_outline_rounded,
      label: 'Livrées & Clôturées',
      value: '${deliveredOrClosed.length}',
      subtitle: 'Taux : ${orders.isEmpty ? '0%' : '${((deliveredOrClosed.length / orders.length) * 100).toStringAsFixed(0)}%'}',
      accentColor: AppColors.success,
      backgroundColor: AppColors.success.withValues(alpha: 0.1),
    );

    final card4 = _OrderKpiCard(
      icon: Icons.account_balance_wallet_rounded,
      label: 'Volume d\'Affaires Engagé',
      value: formatFcfa(totalActiveVolume),
      subtitle: 'Sur les commandes en cours',
      accentColor: cs.primary,
      backgroundColor: cs.primaryContainer.withValues(alpha: 0.35),
      highlight: true,
      badgeText: 'Engagements',
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
    int orderCount,
  ) {
    return Row(
      children: [
        _buildTabButton(
          index: 0,
          label: 'Liste des Commandes',
          icon: Icons.format_list_bulleted_rounded,
          badge: '$orderCount',
        ),
        const SizedBox(width: AppSpacing.xs),
        _buildTabButton(
          index: 1,
          label: 'Rapports & Statistiques',
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
  // 4. Onglet Commandes : Filtres & Table ERP
  // ===========================================================================
  Widget _buildOrdersTab(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    List<SalesOrder> orders,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toolbar de filtres
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
                width: 280,
                height: 38,
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {});
                    widget.onSearchChanged(val);
                  },
                  decoration: InputDecoration(
                    hintText: 'Rechercher N° commande ou client...',
                    hintStyle: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                              widget.onSearchChanged('');
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
              const SizedBox(width: AppSpacing.sm),
              SizedBox(
                width: 220,
                height: 38,
                child: DropdownButtonFormField<SalesOrderStatus?>(
                  initialValue: _statusFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Statut',
                    labelStyle: const TextStyle(fontSize: 11),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tous les statuts', style: TextStyle(fontSize: 12)),
                    ),
                    ...SalesOrderStatus.values.map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(s.labelFr, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() => _statusFilter = val);
                    widget.onStatusFilterChanged(val);
                  },
                ),
              ),
              const Spacer(),
              Text(
                '${orders.length} commande(s)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '· Total : ${formatFcfa(orders.fold<int>(0, (sum, o) => sum + o.total))}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Table
        Expanded(
          child: orders.isEmpty
              ? Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    side: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.6),
                    ),
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
                          const EmptyListPlaceholder(
                            icon: Icons.assignment_outlined,
                            title: 'Aucune commande client trouvée',
                            subtitle:
                                'Créez une commande pour planifier une expédition ou enregistrer un acompte.',
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (widget.canWrite)
                            FilledButton.icon(
                              onPressed: widget.onOpenCreate,
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Créer une commande (F2)'),
                            ),
                        ],
                      ),
                    ),
                  ),
                )
              : _buildTable(context, theme, cs, orders),
        ),
      ],
    );
  }

  Widget _buildTable(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    List<SalesOrder> orders,
  ) {
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
        icon: Icons.receipt_outlined,
        minWidth: 150,
        flex: 2,
        isSorted: _sortColumn == 1,
        sortAscending: _sortAscending,
        onSort: () => _toggleSort(1),
      ),
      AppTableColumn(
        label: 'Client',
        icon: Icons.person_outline_rounded,
        minWidth: 200,
        flex: 3,
        isSorted: _sortColumn == 2,
        sortAscending: _sortAscending,
        onSort: () => _toggleSort(2),
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
        label: 'Montant Total',
        icon: Icons.payments_outlined,
        minWidth: 140,
        flex: 2,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
        isSorted: _sortColumn == 3,
        sortAscending: _sortAscending,
        onSort: () => _toggleSort(3),
      ),
      const AppTableColumn(
        label: 'Actions',
        minWidth: 90,
        flex: 1,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
    ];

    final rows = orders.map((order) {
      final dt = DateTime.fromMillisecondsSinceEpoch(order.orderedAt);
      final totalQty = order.items.fold<int>(0, (sum, i) => sum + i.quantityOrdered);

      return AppTableRow(
        onTap: () => widget.onOpenDetail(order),
        cells: [
          // 1. Date
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

          // 2. N° Commande
          Row(
            children: [
              Text(
                '#${order.number}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              if (order.notes != null && order.notes!.isNotEmpty) ...[
                const SizedBox(width: 4),
                Tooltip(
                  message: order.notes!,
                  child: Icon(
                    Icons.note_alt_outlined,
                    size: 14,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),

          // 3. Client
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  order.customerName.isNotEmpty
                      ? order.customerName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cs.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  order.customerName,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // 4. Articles
          Align(
            alignment: Alignment.center,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '${order.items.length} réf ($totalQty u.)',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // 5. Statut
          Align(
            alignment: Alignment.center,
            child: _buildStatusBadge(order.status, cs),
          ),

          // 6. Montant Total
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              formatFcfa(order.total),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: cs.primary,
                letterSpacing: -0.2,
              ),
            ),
          ),

          // 7. Actions
          Align(
            alignment: Alignment.center,
            child: OutlinedButton(
              onPressed: () => widget.onOpenDetail(order),
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

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: AppDesktopDataTable(
        columns: columns,
        rows: rows,
        minWidth: 970,
        itemsPerPage: 15,
        headerTrailing: Text(
          'Total filtré : ${formatFcfa(orders.fold<int>(0, (sum, o) => sum + o.total))}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 5. Onglet Rapports & Livraisons
  // ===========================================================================
  Widget _buildReportsTab(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
  ) {
    final report = widget.state.report;
    final loading = widget.state.reportLoading;

    if (loading && report == null) {
      return const DashboardSkeleton();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sélecteur de période
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                const Icon(Icons.date_range_rounded, size: 18),
                const SizedBox(width: AppSpacing.xs),
                const Text(
                  'Période d\'analyse :',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: AppSpacing.sm),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7 jours')),
                    ButtonSegment(value: 30, label: Text('30 jours')),
                    ButtonSegment(value: 90, label: Text('3 mois')),
                  ],
                  selected: {widget.activePeriodDays},
                  onSelectionChanged: (set) => widget.onPeriodChanged(set.first),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          if (report != null) ...[
            Row(
              children: [
                Expanded(
                  child: _OrderKpiCard(
                    icon: Icons.cancel_outlined,
                    label: 'Articles Refusés',
                    value: '${report.totalRefusedQty}',
                    subtitle: 'Total refusés à la livraison',
                    accentColor: AppColors.danger,
                    backgroundColor: AppColors.danger.withValues(alpha: 0.1),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _OrderKpiCard(
                    icon: Icons.inventory_2_outlined,
                    label: 'Retours Stock / Pertes',
                    value: '${report.totalDestinationQty}',
                    subtitle: 'Articles réintégrés ou perdus',
                    accentColor: Colors.amber.shade800,
                    backgroundColor: Colors.amber.shade50,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _OrderKpiCard(
                    icon: Icons.local_shipping_outlined,
                    label: 'Livraisons Partielles',
                    value: '${report.totalPartialDeliveries}',
                    subtitle: 'Reliquats restant à livrer',
                    accentColor: Colors.blue.shade700,
                    backgroundColor: Colors.blue.shade50,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (report.byRefusalReason.isNotEmpty) ...[
              Text(
                'Motifs de refus',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  side: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    children: report.byRefusalReason.map((bucket) {
                      return Chip(
                        label: Text('${bucket.labelFr} : ${bucket.value} u.'),
                        backgroundColor: cs.surfaceContainerHigh,
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ] else ...[
            const EmptyListPlaceholder(
              icon: Icons.bar_chart_rounded,
              title: 'Données statistiques indisponibles',
              subtitle: 'Rechargez pour calculer les indicateurs de livraison.',
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // Helpers & Badges
  // ===========================================================================
  Widget _buildStatusBadge(SalesOrderStatus status, ColorScheme cs) {
    final (label, color, icon) = switch (status) {
      SalesOrderStatus.draft => ('Brouillon', cs.outline, Icons.edit_note_rounded),
      SalesOrderStatus.confirmed => ('Confirmée', Colors.blue.shade700, Icons.thumb_up_alt_outlined),
      SalesOrderStatus.preparing => ('En préparation', Colors.amber.shade800, Icons.inventory_2_outlined),
      SalesOrderStatus.partiallyDelivered => ('Part. livrée', Colors.orange.shade800, Icons.hourglass_bottom_rounded),
      SalesOrderStatus.delivered => ('Livrée', AppColors.success, Icons.check_circle_outline_rounded),
      SalesOrderStatus.closed => ('Clôturée', Colors.teal.shade700, Icons.lock_outline_rounded),
      SalesOrderStatus.cancelled => ('Annulée', AppColors.danger, Icons.cancel_outlined),
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
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderKpiCard extends StatelessWidget {
  const _OrderKpiCard({
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
