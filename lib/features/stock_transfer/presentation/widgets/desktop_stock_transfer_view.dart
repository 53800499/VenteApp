import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/network/widgets/offline_mode_banner.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/components/app_desktop_data_table.dart';
import '../../../../shared/components/app_header_actions.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../help/presentation/widgets/module_help_button.dart';
import '../../domain/entities/stock_transfer.dart';
import '../bloc/stock_transfer_bloc.dart';

/// Vue Desktop ERP moderne pour le module Transferts de Stock Inter-Boutiques.
/// Optimisée pour Windows et les écrans larges (>= 600px).
class DesktopStockTransferView extends StatefulWidget {
  const DesktopStockTransferView({
    super.key,
    required this.state,
    required this.canCreate,
    required this.canReceive,
    required this.onRefresh,
    required this.onOpenCreate,
    required this.onOpenQrScan,
    required this.onOpenDetail,
  });

  final StockTransferState state;
  final bool canCreate;
  final bool canReceive;
  final VoidCallback onRefresh;
  final VoidCallback onOpenCreate;
  final VoidCallback onOpenQrScan;
  final ValueChanged<int> onOpenDetail;

  @override
  State<DesktopStockTransferView> createState() => _DesktopStockTransferViewState();
}

class _DesktopStockTransferViewState extends State<DesktopStockTransferView> {
  final TextEditingController _searchController = TextEditingController();
  int _activeTabIndex = 0; // 0: Sortants, 1: En transit, 2: Entrants, 3: Rapports

  int _sortColumn = 0; // 0: Date, 1: Référence
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

  List<StockTransfer> _filterAndSort(List<StockTransfer> list) {
    var result = list;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((t) {
        final refMatch = t.reference.toLowerCase().contains(query);
        final srcMatch = t.sourceShopLabel.toLowerCase().contains(query);
        final destMatch = t.destinationShopLabel.toLowerCase().contains(query);
        final notesMatch = t.notes?.toLowerCase().contains(query) ?? false;
        return refMatch || srcMatch || destMatch || notesMatch;
      }).toList();
    }

    result = List<StockTransfer>.from(result);
    result.sort((a, b) {
      int cmp = 0;
      if (_sortColumn == 0) {
        cmp = a.createdAt.compareTo(b.createdAt);
      } else {
        cmp = a.reference.toLowerCase().compareTo(b.reference.toLowerCase());
      }
      return _sortAscending ? cmp : -cmp;
    });

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final state = widget.state;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f2): () {
          if (widget.canCreate) widget.onOpenCreate();
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

                if (state.isRefreshing || state.status == StockTransferBlocStatus.loading) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: AppSpacing.xs),
                ],

                // 2. Les 4 Cartes Stratégiques KPIs
                _buildStrategicKpis(context, theme, cs),

                const SizedBox(height: AppSpacing.md),

                // 3. Barre d'onglets ERP
                _buildTabBar(context, theme, cs),

                const SizedBox(height: AppSpacing.sm),

                // 4. Contenu selon l'onglet actif
                Expanded(
                  child: _activeTabIndex == 3
                      ? _buildReportsTab(context, theme, cs)
                      : _buildTransfersTab(context, theme, cs),
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
                Icons.swap_horiz_rounded,
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
                          'Transferts de Stock Inter-Boutiques',
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
                          '${widget.state.outgoing.length + widget.state.inTransit.length + widget.state.incoming.length} flux',
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
                    'Expéditions, réceptions, tracking des colis en transit et retours marchandise',
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
                onPressed: widget.onOpenCreate,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nouveau Transfert (F2)'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (widget.canReceive) ...[
              OutlinedButton.icon(
                onPressed: widget.onOpenQrScan,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                label: const Text('Scanner QR'),
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
            const ModuleHelpButton(articleId: 'stock_transfers'),
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
    final outgoing = widget.state.outgoing;
    final inTransit = widget.state.inTransit;
    final incoming = widget.state.incoming;

    final card1 = _TransferKpiCard(
      icon: Icons.outbox_rounded,
      label: 'Transferts Sortants',
      value: '${outgoing.length}',
      subtitle: '${outgoing.where((t) => t.status == StockTransferStatus.validated).length} validé(s)',
      accentColor: Colors.blue.shade700,
      backgroundColor: Colors.blue.shade50,
    );

    final card2 = _TransferKpiCard(
      icon: Icons.local_shipping_outlined,
      label: 'En Transit (Sur la route)',
      value: '${inTransit.length}',
      subtitle: 'Colis en cours d\'acheminement',
      accentColor: Colors.amber.shade800,
      backgroundColor: Colors.amber.shade50,
      highlight: true,
      badgeText: 'Actif',
    );

    final card3 = _TransferKpiCard(
      icon: Icons.move_to_inbox_rounded,
      label: 'Transferts Entrants',
      value: '${incoming.length}',
      subtitle: '${incoming.where((t) => t.status == StockTransferStatus.received).length} reçu(s)',
      accentColor: AppColors.success,
      backgroundColor: AppColors.success.withValues(alpha: 0.1),
    );

    final totalFlux = outgoing.length + inTransit.length + incoming.length;
    final card4 = _TransferKpiCard(
      icon: Icons.insights_rounded,
      label: 'Total Mouvements',
      value: '$totalFlux flux',
      subtitle: 'Échanges inter-boutiques',
      accentColor: cs.primary,
      backgroundColor: cs.primaryContainer.withValues(alpha: 0.35),
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
                SizedBox(width: 240, child: card4),
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
          label: 'Sortants',
          icon: Icons.outbox_rounded,
          badge: '${widget.state.outgoing.length}',
        ),
        const SizedBox(width: AppSpacing.xs),
        _buildTabButton(
          index: 1,
          label: 'En Transit',
          icon: Icons.local_shipping_outlined,
          badge: '${widget.state.inTransit.length}',
        ),
        const SizedBox(width: AppSpacing.xs),
        _buildTabButton(
          index: 2,
          label: 'Entrants',
          icon: Icons.move_to_inbox_rounded,
          badge: '${widget.state.incoming.length}',
        ),
        const SizedBox(width: AppSpacing.xs),
        _buildTabButton(
          index: 3,
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
  // 4. Onglet Transferts : Filtres & Table ERP
  // ===========================================================================
  Widget _buildTransfersTab(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
  ) {
    final rawList = switch (_activeTabIndex) {
      0 => widget.state.outgoing,
      1 => widget.state.inTransit,
      2 => widget.state.incoming,
      _ => widget.state.outgoing,
    };

    final filtered = _filterAndSort(rawList);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Toolbar de recherche
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
                    hintText: 'Rechercher référence, boutique...',
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
              Text(
                '${filtered.length} transfert(s) affiché(s)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Table
        Expanded(
          child: filtered.isEmpty
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
                          EmptyListPlaceholder(
                            icon: Icons.swap_horiz_rounded,
                            title: 'Aucun transfert dans cette section',
                            subtitle: _activeTabIndex == 0
                                ? 'Créez un transfert pour envoyer de la marchandise vers une autre boutique.'
                                : (_activeTabIndex == 1
                                    ? 'Aucune marchandise n\'est actuellement en cours de transport.'
                                    : 'Aucun transfert en attente de réception pour cette boutique.'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (_activeTabIndex == 0 && widget.canCreate)
                            FilledButton.icon(
                              onPressed: widget.onOpenCreate,
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Créer un transfert (F2)'),
                            ),
                        ],
                      ),
                    ),
                  ),
                )
              : _buildTable(context, theme, cs, filtered),
        ),
      ],
    );
  }

  Widget _buildTable(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    List<StockTransfer> transfers,
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
        label: 'Référence',
        icon: Icons.tag_rounded,
        minWidth: 150,
        flex: 2,
        isSorted: _sortColumn == 1,
        sortAscending: _sortAscending,
        onSort: () => _toggleSort(1),
      ),
      const AppTableColumn(
        label: 'Trajet (Source → Destination)',
        icon: Icons.alt_route_rounded,
        minWidth: 260,
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
      const AppTableColumn(
        label: 'Actions',
        minWidth: 90,
        flex: 1,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
    ];

    final rows = transfers.map((t) {
      final dt = DateTime.fromMillisecondsSinceEpoch(t.createdAt);
      final itemCount = t.items?.length ?? 0;
      final totalQty = (t.items ?? []).fold<int>(0, (sum, i) => sum + i.quantityRequested);

      return AppTableRow(
        onTap: () => widget.onOpenDetail(t.id),
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

          // 2. Référence
          Row(
            children: [
              Text(
                '#${t.reference}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.2,
                ),
              ),
              if (t.isReturn) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(color: Colors.purple.shade200),
                  ),
                  child: Text(
                    'Retour',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),

          // 3. Trajet
          Row(
            children: [
              Flexible(
                child: Text(
                  t.sourceShopLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: cs.primary,
                ),
              ),
              Flexible(
                child: Text(
                  t.destinationShopLabel,
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
                '$itemCount réf ($totalQty u.)',
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
            child: _buildStatusBadge(t.status, cs),
          ),

          // 6. Actions
          Align(
            alignment: Alignment.center,
            child: OutlinedButton(
              onPressed: () => widget.onOpenDetail(t.id),
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
        minWidth: 900,
        itemsPerPage: 15,
      ),
    );
  }

  // ===========================================================================
  // 5. Onglet Rapports
  // ===========================================================================
  Widget _buildReportsTab(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
  ) {
    final report = widget.state.reportSummary;

    if (report == null) {
      return const EmptyListPlaceholder(
        icon: Icons.analytics_outlined,
        title: 'Synthèse des transferts indisponible',
        subtitle: 'Actualisez pour charger les statistiques du réseau.',
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _TransferKpiCard(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Total Transferts',
                  value: '${report.totalTransfers}',
                  subtitle: 'Tous les flux réseau',
                  accentColor: cs.primary,
                  backgroundColor: cs.primaryContainer.withValues(alpha: 0.35),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _TransferKpiCard(
                  icon: Icons.inventory_2_outlined,
                  label: 'Unités Expédiées',
                  value: '${report.totalUnitsShipped}',
                  subtitle: '${report.totalUnitsReceived} unités reçues',
                  accentColor: Colors.blue.shade700,
                  backgroundColor: Colors.blue.shade50,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _TransferKpiCard(
                  icon: Icons.local_shipping_outlined,
                  label: 'En Cours de Transit',
                  value: '${report.inTransitCount}',
                  subtitle: 'Expéditions actives',
                  accentColor: Colors.amber.shade800,
                  backgroundColor: Colors.amber.shade50,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _TransferKpiCard(
                  icon: Icons.report_problem_outlined,
                  label: 'Écarts & Anomalies',
                  value: '${report.discrepancyCount}',
                  subtitle: '${report.totalDiscrepancyUnits} unité(s) manquante(s)',
                  accentColor: report.discrepancyCount > 0 ? AppColors.danger : AppColors.success,
                  backgroundColor: (report.discrepancyCount > 0 ? AppColors.danger : AppColors.success).withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (report.discrepancies.isNotEmpty) ...[
            Text(
              'Alertes écarts et litiges',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
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
                child: Column(
                  children: report.discrepancies.map((d) {
                    return ListTile(
                      onTap: () => widget.onOpenDetail(d.transferId),
                      title: Text('#${d.reference} — ${d.productName}'),
                      subtitle: Text('Expédié: ${d.quantityShipped} · Reçu: ${d.quantityReceived} · Écart: ${d.gap} u.'),
                      trailing: Text(
                        StockTransferStatus.label(d.status),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // Helpers
  // ===========================================================================
  Widget _buildStatusBadge(String status, ColorScheme cs) {
    final label = StockTransferStatus.label(status);
    final (color, icon) = switch (status) {
      StockTransferStatus.draft => (cs.outline, Icons.edit_note_rounded),
      StockTransferStatus.pendingApproval => (Colors.purple.shade700, Icons.schedule_outlined),
      StockTransferStatus.validated => (Colors.blue.shade700, Icons.thumb_up_alt_outlined),
      StockTransferStatus.shipped || StockTransferStatus.partiallyShipped => (Colors.amber.shade800, Icons.local_shipping_outlined),
      StockTransferStatus.received || StockTransferStatus.partiallyReceived => (AppColors.success, Icons.check_circle_outline_rounded),
      StockTransferStatus.closed => (Colors.teal.shade700, Icons.lock_outline_rounded),
      StockTransferStatus.closedWithException => (AppColors.danger, Icons.report_problem_outlined),
      StockTransferStatus.cancelled => (AppColors.danger, Icons.cancel_outlined),
      _ => (cs.outline, Icons.help_outline),
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

class _TransferKpiCard extends StatelessWidget {
  const _TransferKpiCard({
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
