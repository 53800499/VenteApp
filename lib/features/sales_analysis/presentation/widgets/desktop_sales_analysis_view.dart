import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/network/widgets/offline_mode_banner.dart';
import '../../../../core/utils/benin_period_range.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/components/app_desktop_data_table.dart';
import '../../../../shared/components/app_header_actions.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../customers/presentation/pages/customer_detail_page.dart';
import '../../../help/presentation/widgets/module_help_button.dart';
import '../../domain/entities/sales_analysis_entities.dart';
import '../../domain/usecases/sales_analysis_usecases.dart';
import '../bloc/sales_analysis_bloc.dart';
import '../pages/product_sales_detail_page.dart';
import '../utils/sales_analysis_formatters.dart';

/// Vue Desktop ERP moderne pour le module d'Analyse des Ventes.
/// Optimisée pour Windows et les écrans larges (>= 600px).
class DesktopSalesAnalysisView extends StatefulWidget {
  const DesktopSalesAnalysisView({
    super.key,
    required this.session,
    required this.state,
    required this.tabController,
    required this.onRefresh,
    required this.onPickCustomRange,
    required this.onTabSelected,
  });

  final AuthSession session;
  final SalesAnalysisState state;
  final TabController tabController;
  final Future<void> Function() onRefresh;
  final Future<void> Function(BuildContext context) onPickCustomRange;
  final ValueChanged<int> onTabSelected;

  @override
  State<DesktopSalesAnalysisView> createState() =>
      _DesktopSalesAnalysisViewState();
}

class _DesktopSalesAnalysisViewState extends State<DesktopSalesAnalysisView> {
  final TextEditingController _productSearchController = TextEditingController();
  final TextEditingController _customerSearchController = TextEditingController();
  final TextEditingController _deviationSearchController = TextEditingController();

  String _productSearch = '';
  String _customerSearch = '';
  String _deviationSearch = '';

  String _productSort = 'revenue_desc';

  @override
  void initState() {
    super.initState();
    _productSearchController.addListener(() {
      setState(() => _productSearch = _productSearchController.text.trim().toLowerCase());
    });
    _customerSearchController.addListener(() {
      setState(() => _customerSearch = _customerSearchController.text.trim().toLowerCase());
    });
    _deviationSearchController.addListener(() {
      setState(() => _deviationSearch = _deviationSearchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _productSearchController.dispose();
    _customerSearchController.dispose();
    _deviationSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final state = widget.state;

    // Calculs de synthèse globale
    final totalUnitsSold = state.products.fold<double>(
      0,
      (sum, p) => sum + p.quantitySold,
    );
    final totalRevenueFromProducts = state.products.fold<int>(
      0,
      (sum, p) => sum + p.revenue,
    );
    final totalRevenue = state.trends.totalRevenue > 0
        ? state.trends.totalRevenue
        : (state.margins.totalRevenue > 0
            ? state.margins.totalRevenue
            : totalRevenueFromProducts);

    final totalSalesCount = state.trends.totalSaleCount > 0
        ? state.trends.totalSaleCount
        : state.customers.fold<int>(0, (s, c) => s + c.saleCount);

    final avgUnitPrice = totalUnitsSold > 0
        ? (totalRevenue / totalUnitsSold).round()
        : 0;

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
            _buildCommandHeader(context, theme, cs, state),

            const SizedBox(height: AppSpacing.sm),

            // Bandeau hors-ligne éventuel
            const OfflineModeBanner(
              onlinePreferredMessage: OfflineModeBanner.hybridReadMessage,
            ),

            if (state.status == SalesAnalysisStatus.loading) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: AppSpacing.xs),
            ],

            // 2. Les 4 KPIs stratégiques consolidés
            _buildStrategicKpis(
              context,
              theme,
              cs,
              totalRevenue: totalRevenue,
              totalSalesCount: totalSalesCount,
              totalUnitsSold: totalUnitsSold,
              avgUnitPrice: avgUnitPrice,
              margins: state.margins,
              priceDeviations: state.priceDeviations,
            ),

            const SizedBox(height: AppSpacing.md),

            // 3. Barre d'onglets ERP stylisée
            _buildErpTabBar(context, theme, cs, state),

            const SizedBox(height: AppSpacing.sm),

            // 4. Contenu de l'onglet actif avec DataTable moderne
            Expanded(
              child: _buildActiveTabContent(context, theme, cs, state),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. Command Header (Titre, Période active, Actions)
  // ===========================================================================
  Widget _buildCommandHeader(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    SalesAnalysisState state,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 820;

        final titleBlock = Row(
          mainAxisSize: MainAxisSize.min,
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
                border: Border.all(
                  color: cs.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Icon(
                Icons.analytics_rounded,
                color: cs.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Analyse des Ventes & Rentabilité',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  state.periodLabel ?? 'Performance commerciale en temps réel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        );

        final periodPicker = _buildPeriodSelector(context, theme, cs, state);

        final actionButtons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton.filledTonal(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              tooltip: 'Actualiser les indicateurs',
              onPressed: widget.onRefresh,
            ),
            const SizedBox(width: AppSpacing.xs),
            const ModuleHelpButton(articleId: 'sales_analysis'),
            const AppHeaderActions(),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: titleBlock),
                  actionButtons,
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              periodPicker,
            ],
          );
        }

        return Row(
          children: [
            titleBlock,
            const Spacer(),
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
    SalesAnalysisState state,
  ) {
    final query = state.query;

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
            onTap: () => context.read<SalesAnalysisBloc>().add(
                  const SalesAnalysisPeriodChanged(
                    period: ReportPeriodPreset.today,
                  ),
                ),
          ),
          _buildPeriodPill(
            label: '7 jours',
            selected: query.period == ReportPeriodPreset.week,
            onTap: () => context.read<SalesAnalysisBloc>().add(
                  const SalesAnalysisPeriodChanged(
                    period: ReportPeriodPreset.week,
                  ),
                ),
          ),
          _buildPeriodPill(
            label: 'Ce mois',
            selected: query.period == ReportPeriodPreset.month,
            onTap: () => context.read<SalesAnalysisBloc>().add(
                  const SalesAnalysisPeriodChanged(
                    period: ReportPeriodPreset.month,
                  ),
                ),
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
    ColorScheme cs, {
    required int totalRevenue,
    required int totalSalesCount,
    required double totalUnitsSold,
    required int avgUnitPrice,
    required MarginSummary margins,
    required List<PriceDeviationLine> priceDeviations,
  }) {
    final card1 = _ErpKpiCard(
      icon: Icons.point_of_sale_rounded,
      label: "Chiffre d'affaires",
      value: formatFcfa(totalRevenue),
      subtitle: totalSalesCount > 0
          ? '$totalSalesCount ventes enregistrées'
          : '${formatQuantitySold(totalUnitsSold)} unités vendues',
      accentColor: cs.primary,
      backgroundColor: cs.primaryContainer.withValues(alpha: 0.35),
    );

    final card2 = _ErpKpiCard(
      icon: Icons.trending_up_rounded,
      label: 'Marge brute estimée',
      value: margins.hasCostData ? formatFcfa(margins.estimatedProfit) : '—',
      subtitle: margins.hasCostData
          ? 'Coût d\'achat : ${formatFcfa(margins.totalCost)}'
          : 'Prix d\'achat non renseignés',
      accentColor: AppColors.success,
      backgroundColor: AppColors.success.withValues(alpha: 0.1),
      badgeText: margins.hasCostData
          ? '+${margins.marginPercent.toStringAsFixed(1)} %'
          : null,
    );

    final card3 = _ErpKpiCard(
      icon: Icons.inventory_2_rounded,
      label: 'Volume & Panier moyen',
      value: '${formatQuantitySold(totalUnitsSold)} unités',
      subtitle: avgUnitPrice > 0
          ? 'Prix moyen : ${formatFcfa(avgUnitPrice)}'
          : 'Aucun article vendu',
      accentColor: Colors.blue.shade700,
      backgroundColor: Colors.blue.shade50,
    );

    final hasDeviations = priceDeviations.isNotEmpty;
    final card4 = _ErpKpiCard(
      icon: Icons.price_change_rounded,
      label: 'Discipline tarifaire',
      value: '${priceDeviations.length} écart(s)',
      subtitle: hasDeviations
          ? 'Remises ou déviations catalogue'
          : '100% conforme au catalogue',
      accentColor: hasDeviations ? AppColors.warning : AppColors.success,
      backgroundColor: (hasDeviations ? AppColors.warning : AppColors.success)
          .withValues(alpha: 0.1),
      badgeText: hasDeviations ? 'À surveiller' : 'Conforme',
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
  // 3. ERP Tab Bar (Onglets professionnels avec compteurs)
  // ===========================================================================
  Widget _buildErpTabBar(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    SalesAnalysisState state,
  ) {
    final tabs = [
      (
        index: 0,
        label: 'Produits',
        icon: Icons.inventory_2_outlined,
        badge: '${state.products.length}',
      ),
      (
        index: 1,
        label: 'Employés',
        icon: Icons.badge_outlined,
        badge: '${state.employees.length}',
      ),
      (
        index: 2,
        label: 'Clients',
        icon: Icons.people_outline,
        badge: '${state.customers.length}',
      ),
      (
        index: 3,
        label: 'Catégories',
        icon: Icons.category_outlined,
        badge: '${state.categories.length}',
      ),
      (
        index: 4,
        label: 'Marges',
        icon: Icons.trending_up_rounded,
        badge: state.margins.hasCostData ? '${state.margins.topProducts.length}' : null,
      ),
      (
        index: 5,
        label: 'Écarts Prix',
        icon: Icons.price_change_outlined,
        badge: state.priceDeviations.isNotEmpty
            ? '${state.priceDeviations.length}'
            : null,
      ),
      (
        index: 6,
        label: 'Tendances',
        icon: Icons.show_chart_rounded,
        badge: '${state.trends.points.length}',
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((t) {
            final isSelected = widget.tabController.index == t.index;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: () => widget.onTabSelected(t.index),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? cs.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
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
                        t.icon,
                        size: 16,
                        color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        t.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? cs.onPrimary : cs.onSurfaceVariant,
                        ),
                      ),
                      if (t.badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? cs.onPrimary.withValues(alpha: 0.25)
                                : cs.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            t.badge!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? cs.onPrimary
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ===========================================================================
  // 4. Tab Content Router
  // ===========================================================================
  Widget _buildActiveTabContent(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    SalesAnalysisState state,
  ) {
    switch (widget.tabController.index) {
      case 0:
        return _buildProductsTab(context, theme, cs, state);
      case 1:
        return _buildEmployeesTab(context, theme, cs, state);
      case 2:
        return _buildCustomersTab(context, theme, cs, state);
      case 3:
        return _buildCategoriesTab(context, theme, cs, state);
      case 4:
        return _buildMarginsTab(context, theme, cs, state);
      case 5:
        return _buildDeviationsTab(context, theme, cs, state);
      case 6:
        return _buildTrendsTab(context, theme, cs, state);
      default:
        return const SizedBox.shrink();
    }
  }

  // ---------------------------------------------------------------------------
  // Tab 0 : Produits
  // ---------------------------------------------------------------------------
  Widget _buildProductsTab(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    SalesAnalysisState state,
  ) {
    if (state.products.isEmpty) {
      return const EmptyListPlaceholder(
        icon: Icons.inventory_2_outlined,
        title: 'Aucune vente produit sur cette période',
        subtitle: 'Les ventes de vos produits s\'afficheront ici.',
      );
    }

    var items = List<ProductSalesSummary>.from(state.products);

    if (_productSearch.isNotEmpty) {
      items = items
          .where((p) => p.productName.toLowerCase().contains(_productSearch))
          .toList();
    }

    switch (_productSort) {
      case 'revenue_desc':
        items.sort((a, b) => b.revenue.compareTo(a.revenue));
        break;
      case 'revenue_asc':
        items.sort((a, b) => a.revenue.compareTo(b.revenue));
        break;
      case 'quantity_desc':
        items.sort((a, b) => b.quantitySold.compareTo(a.quantitySold));
        break;
      case 'avg_price_desc':
        items.sort((a, b) => b.averageUnitPrice.compareTo(a.averageUnitPrice));
        break;
      case 'name_asc':
        items.sort((a, b) => a.productName.compareTo(b.productName));
        break;
    }

    final columns = [
      const AppTableColumn(label: 'Produit', flex: 3, minWidth: 230),
      const AppTableColumn(
        label: 'Qté Vendue',
        width: 130,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Prix Moyen',
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
      const AppTableColumn(label: 'Dernière Vente', width: 140),
      const AppTableColumn(
        label: 'Action',
        width: 100,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
    ];

    final rows = items.map((product) {
      final isHeadless = SalesAnalysisHeadlessLabels.isHeadlessProductName(
        product.productName,
      );
      final lastSale = product.lastSaleAt != null
          ? formatRelativeSaleDate(product.lastSaleAt!)
          : '—';

      return AppTableRow(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductSalesDetailPage(
                session: widget.session,
                query: state.query,
                productId: product.productId,
                productName: product.productName,
              ),
            ),
          );
        },
        cells: [
          // 1. Produit
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: cs.primaryContainer.withValues(alpha: 0.5),
                child: Icon(
                  isHeadless
                      ? Icons.flash_on_rounded
                      : Icons.inventory_2_outlined,
                  size: 14,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      product.productName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isHeadless)
                      Text(
                        'Vente rapide (sans détail)',
                        style: TextStyle(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // 2. Qté
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: cs.secondaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '${formatQuantitySold(product.quantitySold)} u',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: cs.onSecondaryContainer,
              ),
            ),
          ),
          // 3. Prix moyen
          Text(
            formatFcfa(product.averageUnitPrice),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
          // 4. CA
          Text(
            formatFcfa(product.revenue),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          // 5. Dernière vente
          Text(
            lastSale,
            style: theme.textTheme.bodySmall,
          ),
          // 6. Action
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProductSalesDetailPage(
                    session: widget.session,
                    query: state.query,
                    productId: product.productId,
                    productName: product.productName,
                  ),
                ),
              );
            },
            child: const Text('Détail', style: TextStyle(fontSize: 11)),
          ),
        ],
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barre d'outils locale
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _productSearchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un produit...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _productSearch.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => _productSearchController.clear(),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _productSort,
                  icon: const Icon(Icons.sort_rounded, size: 18),
                  style: theme.textTheme.bodySmall,
                  items: const [
                    DropdownMenuItem(
                      value: 'revenue_desc',
                      child: Text('Trier par CA décroissant'),
                    ),
                    DropdownMenuItem(
                      value: 'revenue_asc',
                      child: Text('Trier par CA croissant'),
                    ),
                    DropdownMenuItem(
                      value: 'quantity_desc',
                      child: Text('Trier par Qté vendue'),
                    ),
                    DropdownMenuItem(
                      value: 'avg_price_desc',
                      child: Text('Trier par Prix moyen'),
                    ),
                    DropdownMenuItem(
                      value: 'name_asc',
                      child: Text('Trier par Nom A-Z'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _productSort = val);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // DataTable
        Expanded(
          child: AppDesktopDataTable(
            minWidth: 920,
            columns: columns,
            rows: rows,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1 : Employés / Vendeurs
  // ---------------------------------------------------------------------------
  Widget _buildEmployeesTab(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    SalesAnalysisState state,
  ) {
    if (state.employees.isEmpty) {
      return const EmptyListPlaceholder(
        icon: Icons.badge_outlined,
        title: 'Aucune vente enregistrée sur cette période',
      );
    }

    final employees = state.employees;

    final columns = [
      const AppTableColumn(label: 'Vendeur / Collaborateur', flex: 3, minWidth: 220),
      const AppTableColumn(
        label: 'Lignes Vendues',
        width: 140,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Écarts de Prix',
        width: 150,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Prix Moyen Pratiqué',
        width: 170,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(label: 'Discipline Tarifaire', width: 200),
    ];

    final rows = employees.map((employee) {
      final name = employee.userName ?? 'Vendeur #${employee.userId}';
      final initial = name.characters.first.toUpperCase();
      final hasDiscounts = employee.discountLineCount > 0;

      final complianceRate = employee.saleLineCount > 0
          ? (((employee.saleLineCount - employee.discountLineCount) /
                      employee.saleLineCount) *
                  100)
              .clamp(0.0, 100.0)
          : 100.0;

      return AppTableRow(
        cells: [
          // 1. Nom
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'ID employé : ${employee.userId}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 2. Lignes
          Text('${employee.saleLineCount} lignes'),
          // 3. Écarts
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: hasDiscounts
                  ? AppColors.warning.withValues(alpha: 0.15)
                  : AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              hasDiscounts
                  ? '${employee.discountLineCount} écart(s)'
                  : '0 écart',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: hasDiscounts ? AppColors.warning : AppColors.success,
              ),
            ),
          ),
          // 4. Prix moyen
          Text(
            formatFcfa(employee.averageUnitPrice),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          // 5. Jauge de discipline
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: complianceRate / 100,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(
                      complianceRate >= 90
                          ? AppColors.success
                          : (complianceRate >= 70
                              ? AppColors.warning
                              : AppColors.danger),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${complianceRate.toStringAsFixed(0)} %',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
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
  // Tab 2 : Clients
  // ---------------------------------------------------------------------------
  Widget _buildCustomersTab(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    SalesAnalysisState state,
  ) {
    if (state.customers.isEmpty) {
      return const EmptyListPlaceholder(
        icon: Icons.people_outline,
        title: 'Aucun client identifié sur cette période',
      );
    }

    var customers = List<CustomerSalesInsight>.from(state.customers);
    if (_customerSearch.isNotEmpty) {
      customers = customers
          .where((c) => c.customerName.toLowerCase().contains(_customerSearch))
          .toList();
    }

    final columns = [
      const AppTableColumn(label: 'Client', flex: 3, minWidth: 220),
      const AppTableColumn(
        label: 'Ventes',
        width: 130,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Lignes Achetées',
        width: 140,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Prix Moyen',
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
        label: 'Action',
        width: 110,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
    ];

    final rows = customers.map((customer) {
      return AppTableRow(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CustomerDetailPage(
                session: widget.session,
                customerId: customer.customerId,
              ),
            ),
          );
        },
        cells: [
          // 1. Client
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: cs.tertiaryContainer,
                child: Icon(
                  Icons.person_outline_rounded,
                  size: 15,
                  color: cs.onTertiaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  customer.customerName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // 2. Ventes
          Text('${customer.saleCount} vente(s)'),
          // 3. Lignes
          Text('${customer.lineCount} ligne(s)'),
          // 4. Prix moyen
          Text(formatFcfa(customer.averageUnitPrice)),
          // 5. CA Total
          Text(
            formatFcfa(customer.totalRevenue),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          // 6. Action
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CustomerDetailPage(
                    session: widget.session,
                    customerId: customer.customerId,
                  ),
                ),
              );
            },
            child: const Text('Fiche', style: TextStyle(fontSize: 11)),
          ),
        ],
      );
    }).toList();

    return Column(
      children: [
        // Recherche
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _customerSearchController,
                  decoration: InputDecoration(
                    hintText: 'Filtrer par nom de client...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _customerSearch.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => _customerSearchController.clear(),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // DataTable
        Expanded(
          child: AppDesktopDataTable(
            minWidth: 920,
            columns: columns,
            rows: rows,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 3 : Catégories
  // ---------------------------------------------------------------------------
  Widget _buildCategoriesTab(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    SalesAnalysisState state,
  ) {
    if (state.categories.isEmpty) {
      return const EmptyListPlaceholder(
        icon: Icons.category_outlined,
        title: 'Aucune vente par catégorie sur cette période',
      );
    }

    final categories = state.categories;
    final totalCatRevenue = categories.fold<int>(0, (s, c) => s + c.revenue);

    final columns = [
      const AppTableColumn(label: 'Catégorie', flex: 3, minWidth: 220),
      const AppTableColumn(
        label: 'Produits Distincts',
        width: 150,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Volume Vendu',
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
      const AppTableColumn(label: 'Part du CA Total', width: 180),
      const AppTableColumn(
        label: 'Action',
        width: 150,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
    ];

    final rows = categories.map((cat) {
      final sharePercent = totalCatRevenue > 0
          ? (cat.revenue / totalCatRevenue) * 100
          : 0.0;

      return AppTableRow(
        onTap: () => _showDesktopCategoryDetails(context, cat),
        cells: [
          // 1. Nom
          Row(
            children: [
              Icon(Icons.folder_outlined, size: 18, color: cs.primary),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  cat.categoryName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // 2. Produits distincts
          Text('${cat.productCount} produit(s)'),
          // 3. Qté
          Text('${formatQuantitySold(cat.quantitySold)} u'),
          // 4. CA
          Text(
            formatFcfa(cat.revenue),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          // 5. Part du CA
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: sharePercent / 100,
                    minHeight: 6,
                    backgroundColor: cs.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation(cs.primary),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${sharePercent.toStringAsFixed(1)} %',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          // 6. Action
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => _showDesktopCategoryDetails(context, cat),
            child: const Text('Explorer', style: TextStyle(fontSize: 11)),
          ),
        ],
      );
    }).toList();

    return AppDesktopDataTable(
      minWidth: 920,
      columns: columns,
      rows: rows,
    );
  }

  void _showDesktopCategoryDetails(
    BuildContext context,
    CategorySalesSummary category,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _DesktopCategoryProductsDialog(
        session: widget.session,
        query: widget.state.query,
        category: category,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 4 : Marges & Rentabilité
  // ---------------------------------------------------------------------------
  Widget _buildMarginsTab(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    SalesAnalysisState state,
  ) {
    final margins = state.margins;
    if (margins.totalRevenue == 0) {
      return const EmptyListPlaceholder(
        icon: Icons.trending_up_outlined,
        title: 'Aucune vente enregistrée sur cette période',
      );
    }

    final topProducts = margins.topProducts;

    final columns = [
      const AppTableColumn(label: 'Produit Rentable', flex: 3, minWidth: 220),
      const AppTableColumn(
        label: 'Volume',
        width: 120,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'CA Réalisé',
        width: 160,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Coût Estimé',
        width: 160,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Marge Brute',
        width: 160,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Taux Marge',
        width: 130,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
      const AppTableColumn(
        label: 'Action',
        width: 100,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
    ];

    final rows = topProducts.map((line) {
      return AppTableRow(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductSalesDetailPage(
                session: widget.session,
                query: state.query,
                productId: line.productId,
                productName: line.productName,
              ),
            ),
          );
        },
        cells: [
          // 1. Produit
          Row(
            children: [
              Icon(
                Icons.star_rounded,
                size: 16,
                color: Colors.amber.shade700,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  line.productName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // 2. Qté
          Text('${formatQuantitySold(line.quantitySold)} u'),
          // 3. CA
          Text(formatFcfa(line.revenue)),
          // 4. Coût
          Text(formatFcfa(line.estimatedCost)),
          // 5. Marge
          Text(
            formatFcfa(line.estimatedProfit),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.success,
            ),
          ),
          // 6. Taux
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              '+${line.marginPercent.toStringAsFixed(1)} %',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.success,
              ),
            ),
          ),
          // 7. Action
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProductSalesDetailPage(
                    session: widget.session,
                    query: state.query,
                    productId: line.productId,
                    productName: line.productName,
                  ),
                ),
              );
            },
            child: const Text('Détail', style: TextStyle(fontSize: 11)),
          ),
        ],
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Synthèse financière des marges
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildFinancialMetric(
                  label: "Chiffre d'affaires",
                  value: formatFcfa(margins.totalRevenue),
                  icon: Icons.point_of_sale_rounded,
                  color: cs.primary,
                ),
              ),
              const VerticalDivider(width: 24),
              Expanded(
                child: _buildFinancialMetric(
                  label: "Prix d'achat estimé",
                  value: margins.hasCostData
                      ? formatFcfa(margins.totalCost)
                      : '—',
                  icon: Icons.shopping_cart_outlined,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const VerticalDivider(width: 24),
              Expanded(
                child: _buildFinancialMetric(
                  label: 'Marge brute estimée',
                  value: margins.hasCostData
                      ? formatFcfa(margins.estimatedProfit)
                      : '—',
                  icon: Icons.trending_up_rounded,
                  color: AppColors.success,
                  highlight: true,
                ),
              ),
              const VerticalDivider(width: 24),
              Expanded(
                child: _buildFinancialMetric(
                  label: 'Taux de marge',
                  value: margins.hasCostData
                      ? '${margins.marginPercent.toStringAsFixed(1)} %'
                      : '—',
                  icon: Icons.pie_chart_outline_rounded,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        if (!margins.hasCostData)
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Renseignez les prix d\'achat sur vos fiches articles pour débloquer l\'estimation détaillée des marges.',
                    style: TextStyle(fontSize: 12, color: AppColors.warning),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: AppSpacing.sm),

        // Tableau des produits les plus rentables
        Expanded(
          child: topProducts.isEmpty
              ? const Center(
                  child: Text('Aucun détail de rentabilité produit disponible.'),
                )
              : AppDesktopDataTable(
                  minWidth: 920,
                  columns: columns,
                  rows: rows,
                ),
        ),
      ],
    );
  }

  Widget _buildFinancialMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool highlight = false,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.xs),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                maxLines: 1,
              ),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: highlight ? color : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 5 : Écarts de Prix & Remises
  // ---------------------------------------------------------------------------
  Widget _buildDeviationsTab(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    SalesAnalysisState state,
  ) {
    if (state.priceDeviations.isEmpty) {
      return const EmptyListPlaceholder(
        icon: Icons.price_change_outlined,
        title: 'Aucun écart tarifaire constaté',
        subtitle:
            'Toutes les ventes ont été enregistrées aux prix catalogue exacts.',
      );
    }

    var deviations = List<PriceDeviationLine>.from(state.priceDeviations);
    if (_deviationSearch.isNotEmpty) {
      deviations = deviations
          .where(
            (d) =>
                d.productName.toLowerCase().contains(_deviationSearch) ||
                (d.sellerName?.toLowerCase().contains(_deviationSearch) ??
                    false),
          )
          .toList();
    }

    final columns = [
      const AppTableColumn(label: 'Produit', flex: 3, minWidth: 220),
      const AppTableColumn(label: 'Date de Vente', width: 140),
      const AppTableColumn(label: 'Vendeur', width: 150),
      const AppTableColumn(
        label: 'Prix Catalogue',
        width: 140,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Prix Appliqué',
        width: 140,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Écart Tarifaire',
        width: 170,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
      const AppTableColumn(
        label: 'Action',
        width: 100,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
    ];

    final rows = deviations.map((line) {
      final delta = line.priceDelta;
      final isUnder = delta != null && delta < 0;
      final isOver = delta != null && delta > 0;

      return AppTableRow(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductSalesDetailPage(
                session: widget.session,
                query: state.query,
                productId: line.productId,
                productName: line.productName,
              ),
            ),
          );
        },
        cells: [
          // 1. Produit
          Text(
            line.productName,
            style: const TextStyle(fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // 2. Date
          Text(
            formatRelativeSaleDate(line.soldAt),
            style: theme.textTheme.bodySmall,
          ),
          // 3. Vendeur
          Text(line.sellerName ?? 'Vendeur'),
          // 4. Catalogue
          Text(
            line.catalogPrice != null
                ? formatFcfa(line.catalogPrice!)
                : '—',
          ),
          // 5. Prix appliqué
          Text(
            formatFcfa(line.unitPrice),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isUnder ? cs.error : null,
            ),
          ),
          // 6. Écart
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 3,
            ),
            decoration: BoxDecoration(
              color: isUnder
                  ? AppColors.danger.withValues(alpha: 0.12)
                  : (isOver
                      ? AppColors.success.withValues(alpha: 0.12)
                      : cs.surfaceContainerHighest),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              delta == null
                  ? 'Inconnu'
                  : (delta == 0
                      ? 'Remise 0 FCFA'
                      : (delta < 0
                          ? '- ${formatFcfa(delta.abs())}'
                          : '+ ${formatFcfa(delta)}')),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isUnder
                    ? AppColors.danger
                    : (isOver ? AppColors.success : cs.onSurfaceVariant),
              ),
            ),
          ),
          // 7. Action
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProductSalesDetailPage(
                    session: widget.session,
                    query: state.query,
                    productId: line.productId,
                    productName: line.productName,
                  ),
                ),
              );
            },
            child: const Text('Détail', style: TextStyle(fontSize: 11)),
          ),
        ],
      );
    }).toList();

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _deviationSearchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher par produit ou vendeur...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    suffixIcon: _deviationSearch.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            onPressed: () => _deviationSearchController.clear(),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: AppDesktopDataTable(
            minWidth: 960,
            columns: columns,
            rows: rows,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 6 : Tendances
  // ---------------------------------------------------------------------------
  Widget _buildTrendsTab(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    SalesAnalysisState state,
  ) {
    final trends = state.trends;
    if (trends.points.isEmpty) {
      return const EmptyListPlaceholder(
        icon: Icons.show_chart_outlined,
        title: 'Aucune donnée de tendance disponible',
      );
    }

    final maxRevenue = trends.points
        .map((p) => p.revenue)
        .reduce((a, b) => a > b ? a : b);

    final columns = [
      const AppTableColumn(label: 'Intervalle / Date', flex: 2, minWidth: 180),
      const AppTableColumn(
        label: 'Ventes',
        width: 130,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Volume Articles',
        width: 140,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Chiffre d\'Affaires',
        width: 180,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(label: 'Intensité Commerciale', width: 220),
    ];

    final rows = trends.points.map((point) {
      final fraction = maxRevenue > 0 ? (point.revenue / maxRevenue) : 0.0;

      return AppTableRow(
        cells: [
          // 1. Label
          Text(
            point.label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          // 2. Ventes
          Text('${point.saleCount} vente(s)'),
          // 3. Articles
          Text('${formatQuantitySold(point.quantitySold)} u'),
          // 4. CA
          Text(
            formatFcfa(point.revenue),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: cs.primary,
            ),
          ),
          // 5. Jauge d'intensité
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 8,
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

    return AppDesktopDataTable(
      minWidth: 880,
      columns: columns,
      rows: rows,
    );
  }
}

// =============================================================================
// KPI Card ERP Modulaire
// =============================================================================
class _ErpKpiCard extends StatelessWidget {
  const _ErpKpiCard({
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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

// =============================================================================
// Desktop Dialog pour explorer les produits d'une catégorie
// =============================================================================
class _DesktopCategoryProductsDialog extends StatefulWidget {
  const _DesktopCategoryProductsDialog({
    required this.session,
    required this.query,
    required this.category,
  });

  final AuthSession session;
  final SalesAnalysisQuery query;
  final CategorySalesSummary category;

  @override
  State<_DesktopCategoryProductsDialog> createState() =>
      _DesktopCategoryProductsDialogState();
}

class _DesktopCategoryProductsDialogState
    extends State<_DesktopCategoryProductsDialog> {
  late Future<List<ProductSalesSummary>> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<ListProductSummariesByCategory>()(
      shopId: widget.session.shop.id,
      query: widget.query,
      categoryId: widget.category.categoryId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 820,
          maxHeight: 600,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(Icons.category_rounded, color: cs.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.category.categoryName,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${formatQuantitySold(widget.category.quantitySold)} unités vendues · ${formatFcfa(widget.category.revenue)} de chiffre d\'affaires',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Fermer',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const Divider(height: 1),
              const SizedBox(height: AppSpacing.md),

              // Contenu
              Expanded(
                child: FutureBuilder<List<ProductSalesSummary>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Erreur : ${snapshot.error}',
                          style: TextStyle(color: cs.error),
                        ),
                      );
                    }
                    final products = snapshot.data ?? [];
                    if (products.isEmpty) {
                      return const Center(
                        child: Text(
                          'Aucun produit vendu dans cette catégorie sur cette période.',
                        ),
                      );
                    }

                    final columns = [
                      const AppTableColumn(label: 'Produit', flex: 3, minWidth: 220),
                      const AppTableColumn(
                        label: 'Qté',
                        width: 110,
                        alignment: Alignment.centerRight,
                        textAlign: TextAlign.right,
                      ),
                      const AppTableColumn(
                        label: 'Prix Moyen',
                        width: 130,
                        alignment: Alignment.centerRight,
                        textAlign: TextAlign.right,
                      ),
                      const AppTableColumn(
                        label: 'CA Réalisé',
                        width: 150,
                        alignment: Alignment.centerRight,
                        textAlign: TextAlign.right,
                      ),
                      const AppTableColumn(
                        label: 'Action',
                        width: 90,
                        alignment: Alignment.center,
                        textAlign: TextAlign.center,
                      ),
                    ];

                    final rows = products.map((product) {
                      return AppTableRow(
                        cells: [
                          Text(
                            product.productName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text('${formatQuantitySold(product.quantitySold)} u'),
                          Text(formatFcfa(product.averageUnitPrice)),
                          Text(
                            formatFcfa(product.revenue),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                          ),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProductSalesDetailPage(
                                    session: widget.session,
                                    query: widget.query,
                                    productId: product.productId,
                                    productName: product.productName,
                                  ),
                                ),
                              );
                            },
                            child: const Text('Détail', style: TextStyle(fontSize: 10)),
                          ),
                        ],
                      );
                    }).toList();

                    return AppDesktopDataTable(
                      minWidth: 700,
                      columns: columns,
                      rows: rows,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
