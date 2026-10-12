import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/network/widgets/offline_mode_banner.dart';
import '../../../../core/utils/benin_period_range.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/components/app_desktop_data_table.dart';
import '../../../../shared/components/app_header_actions.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../help/presentation/widgets/module_help_button.dart';
import '../../../sales_analysis/presentation/pages/sales_analysis_page.dart';
import '../../domain/entities/report_entities.dart';
import '../bloc/report_bloc.dart';

/// Vue Desktop ERP moderne pour le module Statistiques & Chiffre d'Affaires.
/// Optimisée pour Windows et les écrans larges (>= 600px).
class DesktopReportsView extends StatefulWidget {
  const DesktopReportsView({
    super.key,
    required this.session,
    required this.state,
    required this.onRefresh,
    required this.onExportPdf,
    required this.onPickCustomRange,
  });

  final AuthSession session;
  final ReportState state;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onExportPdf;
  final Future<void> Function(BuildContext context) onPickCustomRange;

  @override
  State<DesktopReportsView> createState() => _DesktopReportsViewState();
}

class _DesktopReportsViewState extends State<DesktopReportsView> {
  int _activeTabIndex = 0; // 0: Top Produits, 1: Vendeurs, 2: Trésorerie & Encaissements

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final state = widget.state;
    final report = state.report;

    if (report == null) {
      return const SizedBox.shrink();
    }

    final sales = report.sales;
    final financial = report.financial;
    final canFinancial = PermissionGuard.can(
      widget.session.user.permissions,
      Permission.reportsFinancial,
    );

    return Container(
      color: cs.surfaceContainerLowest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Barre de commande supérieure ERP Desktop
            _buildCommandHeader(context, theme, cs, state, report),

            const SizedBox(height: AppSpacing.sm),

            // Bandeau hors ligne
            const OfflineModeBanner(
              onlinePreferredMessage: OfflineModeBanner.hybridReadMessage,
            ),

            if (state.isRefreshing) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: AppSpacing.xs),
            ],

            // 2. Les 4 KPIs stratégiques consolidés (CA Brut, Encaissé, Crédits, Bénéfice Net)
            _buildStrategicKpis(context, theme, cs, sales, financial, canFinancial),

            const SizedBox(height: AppSpacing.md),

            // 3. Contenu principal
            Expanded(
              child: report.empty
                  ? Card(
                      child: Center(
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          child: EmptyListPlaceholder(
                            icon: Icons.insights_outlined,
                            title: report.emptyMessage ??
                                'Aucune transaction enregistrée sur cette période',
                          ),
                        ),
                      ),
                    )
                  : _buildMainContent(context, theme, cs, report, canFinancial),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. Barre de commande supérieure
  // ===========================================================================
  Widget _buildCommandHeader(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    ReportState state,
    Report report,
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
                border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
              ),
              child: Icon(Icons.bar_chart_rounded, color: cs.primary, size: 24),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Statistiques & Chiffre d\'Affaires',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    report.period.label,
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

        final periodPicker = _buildPeriodSelector(context, theme, cs, state.query);

        final actionButtons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.tonalIcon(
              onPressed: widget.onExportPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
              label: const Text('Export PDF'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton.filledTonal(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              tooltip: 'Actualiser',
              onPressed: widget.onRefresh,
            ),
            const SizedBox(width: AppSpacing.xs),
            const ModuleHelpButton(articleId: 'reports'),
            const AppHeaderActions(),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: titleBlock),
                  const SizedBox(width: AppSpacing.sm),
                  actionButtons,
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: periodPicker,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: AppSpacing.md),
            periodPicker,
            const SizedBox(width: AppSpacing.md),
            actionButtons,
          ],
        );
      },
    );
  }

  Widget _buildPeriodSelector(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    ReportQuery query,
  ) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPeriodPill(
            label: "Aujourd'hui",
            selected: query.period == ReportPeriodPreset.today,
            onTap: () => context
                .read<ReportBloc>()
                .add(const ReportPeriodChanged(ReportPeriodPreset.today)),
          ),
          _buildPeriodPill(
            label: '7 jours',
            selected: query.period == ReportPeriodPreset.week,
            onTap: () => context
                .read<ReportBloc>()
                .add(const ReportPeriodChanged(ReportPeriodPreset.week)),
          ),
          _buildPeriodPill(
            label: 'Ce mois',
            selected: query.period == ReportPeriodPreset.month,
            onTap: () => context
                .read<ReportBloc>()
                .add(const ReportPeriodChanged(ReportPeriodPreset.month)),
          ),
          _buildPeriodPill(
            icon: Icons.calendar_today_rounded,
            label: query.period == ReportPeriodPreset.custom
                ? 'Personnalisé'
                : 'Période',
            selected: query.period == ReportPeriodPreset.custom,
            onTap: () => widget.onPickCustomRange(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodPill({
    IconData? icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? cs.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 2. Strategic KPI Cards
  // ===========================================================================
  Widget _buildStrategicKpis(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    ReportSalesKpis sales,
    ReportFinancialKpis? financial,
    bool canFinancial,
  ) {
    final card1 = _ReportsKpiCard(
      icon: Icons.payments_rounded,
      label: 'Chiffre d\'affaires brut',
      value: formatFcfa(sales.grossRevenue),
      subtitle: '${sales.saleCount} ventes · Panier moy. ${formatFcfa(sales.averageBasket)}',
      accentColor: cs.primary,
      backgroundColor: cs.primaryContainer.withValues(alpha: 0.35),
    );

    final card2 = _ReportsKpiCard(
      icon: Icons.account_balance_wallet_rounded,
      label: 'CA Encaissé réel',
      value: formatFcfa(sales.collectedRevenue),
      subtitle: 'Espèces ${formatFcfa(sales.totalCash)} · MoMo ${formatFcfa(sales.totalMomo)}',
      accentColor: Colors.blue.shade700,
      backgroundColor: Colors.blue.shade50,
    );

    final hasCredit = sales.creditGranted > 0;
    final card3 = _ReportsKpiCard(
      icon: Icons.credit_card_rounded,
      label: 'Crédit accordé',
      value: formatFcfa(sales.creditGranted),
      subtitle: financial?.recoveryRateAvailable == true && financial?.recoveryRate != null
          ? 'Taux recouvrement : ${financial!.recoveryRate} %'
          : (hasCredit ? 'Dettes clients générées' : 'Aucun crédit accordé'),
      accentColor: hasCredit ? AppColors.warning : AppColors.success,
      backgroundColor: (hasCredit ? AppColors.warning : AppColors.success)
          .withValues(alpha: 0.1),
      badgeText: financial?.recoveryRateAvailable == true && financial?.recoveryRate != null
          ? '${financial!.recoveryRate} % recouvré'
          : null,
    );

    final netProfit = financial?.netProfit;
    final estimatedProfit = financial?.estimatedProfit;
    final profitDisplay = canFinancial
        ? (netProfit != null
            ? formatFcfa(netProfit)
            : (estimatedProfit != null ? formatFcfa(estimatedProfit) : '—'))
        : 'Confidentiel';

    final isProfitPositive = (netProfit ?? estimatedProfit ?? 0) >= 0;

    final card4 = _ReportsKpiCard(
      icon: Icons.trending_up_rounded,
      label: canFinancial ? (netProfit != null ? 'Bénéfice Net' : 'Bénéfice estimé') : 'Résultat Financier',
      value: profitDisplay,
      subtitle: canFinancial && financial != null && financial.totalExpenses > 0
          ? 'Charges déduites : ${formatFcfa(financial.totalExpenses)}'
          : (canFinancial && financial?.profitWarning != null
              ? financial!.profitWarning!
              : 'Marge opérationnelle'),
      accentColor: isProfitPositive ? AppColors.success : AppColors.danger,
      backgroundColor: (isProfitPositive ? AppColors.success : AppColors.danger)
          .withValues(alpha: 0.1),
      badgeText: canFinancial && isProfitPositive ? '+ Rentable' : null,
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
  // 3. Contenu principal : Onglets & Tables ERP
  // ===========================================================================
  Widget _buildMainContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    Report report,
    bool canFinancial,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Onglets de navigation ERP
        Row(
          children: [
            _buildTabButton(
              index: 0,
              label: 'Top Produits',
              icon: Icons.inventory_2_outlined,
              badge: '${report.topProducts.length}',
            ),
            const SizedBox(width: AppSpacing.xs),
            if (report.sellerPerformance != null &&
                report.sellerPerformance!.isNotEmpty) ...[
              _buildTabButton(
                index: 1,
                label: 'Performance Vendeurs',
                icon: Icons.badge_outlined,
                badge: '${report.sellerPerformance!.length}',
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (canFinancial && report.financial != null) ...[
              _buildTabButton(
                index: 2,
                label: 'Détail Financier & Charges',
                icon: Icons.pie_chart_outline_rounded,
              ),
            ],
            const Spacer(),
            // Lien vers Analyse des Ventes
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SalesAnalysisPage(session: widget.session),
                ),
              ),
              icon: const Icon(Icons.analytics_outlined, size: 16),
              label: const Text('Analyse détaillée des ventes →'),
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.sm),

        // Corps de l'onglet actif
        Expanded(
          child: switch (_activeTabIndex) {
            0 => _buildTopProductsView(context, theme, cs, report),
            1 => _buildSellersView(context, theme, cs, report),
            2 => _buildFinancialView(context, theme, cs, report),
            _ => const SizedBox.shrink(),
          },
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
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isSelected = _activeTabIndex == index;

    return InkWell(
      onTap: () => setState(() => _activeTabIndex = index),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.4),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? cs.onPrimary.withValues(alpha: 0.25)
                      : cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 0 : Top Produits
  // ---------------------------------------------------------------------------
  Widget _buildTopProductsView(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    Report report,
  ) {
    final products = report.topProducts;
    final topBy = widget.state.query.topBy;

    if (products.isEmpty) {
      return const EmptyListPlaceholder(
        icon: Icons.inventory_2_outlined,
        title: 'Aucun produit vendu sur la période',
      );
    }

    final maxVal = topBy == ReportTopSort.revenue
        ? products.map((p) => p.revenue).fold<int>(0, (m, r) => r > m ? r : m)
        : products.map((p) => p.quantitySold).fold<double>(0, (m, q) => q > m ? q : m);

    final columns = [
      const AppTableColumn(
        label: 'Rang',
        width: 70,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
      const AppTableColumn(label: 'Produit', flex: 3, minWidth: 220),
      const AppTableColumn(
        label: 'Quantité Vendue',
        width: 150,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Chiffre d\'Affaires',
        width: 170,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(label: 'Contribution au Volume', width: 220),
    ];

    final rows = products.map((product) {
      final fraction = maxVal > 0
          ? ((topBy == ReportTopSort.revenue ? product.revenue : product.quantitySold) / maxVal)
              .clamp(0.0, 1.0)
          : 0.0;

      return AppTableRow(
        cells: [
          // 1. Rang
          CircleAvatar(
            radius: 12,
            backgroundColor: product.rank <= 3
                ? (product.rank == 1
                    ? Colors.amber.shade700
                    : (product.rank == 2 ? Colors.blueGrey : Colors.brown))
                : cs.surfaceContainerHighest,
            child: Text(
              '${product.rank}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: product.rank <= 3 ? Colors.white : cs.onSurfaceVariant,
              ),
            ),
          ),
          // 2. Produit
          Text(
            product.productName,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // 3. Qté
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cs.secondaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '${product.quantitySold.toStringAsFixed(product.quantitySold.truncateToDouble() == product.quantitySold ? 0 : 1)} u',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: cs.onSecondaryContainer,
              ),
            ),
          ),
          // 4. CA
          Text(
            formatFcfa(product.revenue),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: topBy == ReportTopSort.revenue ? cs.primary : null,
            ),
          ),
          // 5. Jauge
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 7,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(cs.primary),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${(fraction * 100).toStringAsFixed(0)} %',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Spacer(),
            SegmentedButton<ReportTopSort>(
              segments: const [
                ButtonSegment(
                  value: ReportTopSort.quantity,
                  icon: Icon(Icons.numbers, size: 16),
                  label: Text('Trier par Quantité'),
                ),
                ButtonSegment(
                  value: ReportTopSort.revenue,
                  icon: Icon(Icons.monetization_on_outlined, size: 16),
                  label: Text('Trier par CA'),
                ),
              ],
              selected: {topBy},
              onSelectionChanged: (s) => context
                  .read<ReportBloc>()
                  .add(ReportTopSortChanged(s.first)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: AppDesktopDataTable(
            minWidth: 830,
            columns: columns,
            rows: rows,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1 : Performance Vendeurs
  // ---------------------------------------------------------------------------
  Widget _buildSellersView(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    Report report,
  ) {
    final sellers = report.sellerPerformance ?? [];
    if (sellers.isEmpty) {
      return const EmptyListPlaceholder(
        icon: Icons.badge_outlined,
        title: 'Aucune donnée de performance vendeur',
      );
    }

    final totalRev = sellers.fold<int>(0, (s, e) => s + e.totalRevenue);

    final columns = [
      const AppTableColumn(label: 'Collaborateur / Vendeur', flex: 3, minWidth: 220),
      const AppTableColumn(
        label: 'Ventes Réalisées',
        width: 150,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Chiffre d\'Affaires Total',
        width: 180,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Panier Moyen Vendeur',
        width: 180,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(label: 'Part du CA Boutique', width: 200),
    ];

    final rows = sellers.map((seller) {
      final name = seller.userName ?? 'Vendeur #${seller.userId}';
      final initial = name.characters.first.toUpperCase();
      final share = totalRev > 0 ? (seller.totalRevenue / totalRev) : 0.0;
      final avgBasket = seller.saleCount > 0
          ? (seller.totalRevenue / seller.saleCount).round()
          : 0;

      return AppTableRow(
        cells: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          Text('${seller.saleCount} vente(s)'),
          Text(
            formatFcfa(seller.totalRevenue),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          Text(formatFcfa(avgBasket)),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: share,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(cs.primary),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${(share * 100).toStringAsFixed(1)} %',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      );
    }).toList();

    return AppDesktopDataTable(
      minWidth: 880,
      columns: columns,
      rows: rows,
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 2 : Détail Financier & Charges
  // ---------------------------------------------------------------------------
  Widget _buildFinancialView(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    Report report,
  ) {
    final fin = report.financial;
    if (fin == null) {
      return const EmptyListPlaceholder(
        icon: Icons.pie_chart_outline,
        title: 'Aucune donnée financière disponible',
      );
    }

    final rows = [
      (
        label: 'Bénéfice brut estimé',
        val: fin.estimatedProfit != null ? formatFcfa(fin.estimatedProfit!) : '—',
        color: AppColors.success,
        icon: Icons.trending_up_rounded,
      ),
      (
        label: 'Total dépenses & charges d\'exploitation',
        val: formatFcfa(fin.totalExpenses),
        color: AppColors.danger,
        icon: Icons.receipt_long_outlined,
      ),
      (
        label: 'Bénéfice net d\'exploitation',
        val: fin.netProfit != null ? formatFcfa(fin.netProfit!) : '—',
        color: (fin.netProfit ?? 0) >= 0 ? cs.primary : AppColors.danger,
        icon: Icons.account_balance_wallet_rounded,
      ),
      (
        label: 'Dettes clients créées sur la période',
        val: formatFcfa(fin.debtsCreatedAmount),
        color: AppColors.warning,
        icon: Icons.credit_card_outlined,
      ),
      (
        label: 'Dettes clients remboursées',
        val: formatFcfa(fin.debtsRepaidAmount),
        color: AppColors.success,
        icon: Icons.check_circle_outline_rounded,
      ),
    ];

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Synthèse du compte de résultat d\'exploitation',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: AppSpacing.md),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: BoxDecoration(
                          color: rows[i].color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Icon(rows[i].icon, size: 18, color: rows[i].color),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          rows[i].label,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        rows[i].val,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: rows[i].color,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// KPI Card Modulaire
// =============================================================================
class _ReportsKpiCard extends StatelessWidget {
  const _ReportsKpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.accentColor,
    required this.backgroundColor,
    this.badgeText,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color accentColor;
  final Color backgroundColor;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ),
              if (badgeText != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    badgeText!,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
