import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../core/responsive/screen_type.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/components/app_desktop_data_table.dart';
import '../../../../shared/components/app_header_actions.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/stock_valuation_entities.dart';
import '../../domain/usecases/stock_valuation_usecases.dart';
import 'product_detail_page.dart';

enum _StockAnalysisFilter {
  all,
  topValue,
  topRevenue,
  topMargin,
  lowStock,
  deadStock,
  deficitStock,
}

/// Écran complet d'analyse et de valorisation du stock d'ARIKE.
/// - Desktop : Vue ERP riche avec métriques consolidées et DataTable moderne ([AppDesktopDataTable]).
/// - Mobile : Expérience tactile fluide, carrousel d'indicateurs de trésorerie et fiches produits financières ergonomiques.
class StockAnalysisPage extends StatefulWidget {
  const StockAnalysisPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<StockAnalysisPage> createState() => _StockAnalysisPageState();
}

class _StockAnalysisPageState extends State<StockAnalysisPage> {
  late Future<StockValuationSummary> _future;
  _StockAnalysisFilter _selectedFilter = _StockAnalysisFilter.all;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadData() {
    setState(() {
      _future = sl<GetStockValuationSummary>()(shopId: widget.session.shop.id);
    });
  }

  List<ProductStockValuation> _filterAndSortItems(
    List<ProductStockValuation> items,
  ) {
    var result = items;

    // Filtre textuel
    if (_searchQuery.isNotEmpty) {
      result = result.where((i) {
        final nameMatch = i.productName.toLowerCase().contains(_searchQuery);
        final skuMatch = i.sku?.toLowerCase().contains(_searchQuery) ?? false;
        final catMatch =
            i.categoryName?.toLowerCase().contains(_searchQuery) ?? false;
        return nameMatch || skuMatch || catMatch;
      }).toList();
    }

    // Filtre stratégique & tri
    switch (_selectedFilter) {
      case _StockAnalysisFilter.all:
        result.sort((a, b) => a.productName.compareTo(b.productName));
        break;
      case _StockAnalysisFilter.topValue:
        result.sort((a, b) => b.purchaseValue.compareTo(a.purchaseValue));
        break;
      case _StockAnalysisFilter.topRevenue:
        result.sort((a, b) => b.potentialRevenue.compareTo(a.potentialRevenue));
        break;
      case _StockAnalysisFilter.topMargin:
        result.sort((a, b) => b.potentialMargin.compareTo(a.potentialMargin));
        break;
      case _StockAnalysisFilter.lowStock:
        result = result.where((i) => i.isLowStock).toList();
        result.sort((a, b) => a.quantityInStock.compareTo(b.quantityInStock));
        break;
      case _StockAnalysisFilter.deadStock:
        result = result.where((i) => i.isDeadStock).toList();
        result.sort((a, b) => b.purchaseValue.compareTo(a.purchaseValue));
        break;
      case _StockAnalysisFilter.deficitStock:
        result = result.where((i) => i.quantityInStock < 0).toList();
        result.sort((a, b) => a.quantityInStock.compareTo(b.quantityInStock));
        break;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final isDesktop = Breakpoints.useDataTable(MediaQuery.sizeOf(context).width);

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('Analyse & Valorisation du Stock'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Actualiser',
                  onPressed: _loadData,
                ),
                const AppHeaderActions(),
              ],
            ),
      body: FutureBuilder<StockValuationSummary>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: AppSpacing.md),
                  Text('Calcul de la valorisation du stock…'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 48,
                      color: cs.error,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text('Erreur de chargement de la valorisation'),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton(
                      onPressed: _loadData,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }

          final summary = snapshot.data!;
          final filteredItems = _filterAndSortItems(summary.items);

          return ResponsiveBuilder(
            builder: (context, screenType) {
              final isDesktop = Breakpoints.useDataTable(
                MediaQuery.sizeOf(context).width,
              );

              if (isDesktop) {
                return _buildDesktopLayout(context, summary, filteredItems);
              }

              return _buildMobileLayout(
                context,
                summary,
                filteredItems,
                screenType,
              );
            },
          );
        },
      ),
    );
  }

  // ===========================================================================
  // LAYOUT DESKTOP : ERP avec DataTable
  // ===========================================================================

  Widget _buildDesktopLayout(
    BuildContext context,
    StockValuationSummary summary,
    List<ProductStockValuation> filteredItems,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompactOrMedium = constraints.maxWidth < 900;

        return Container(
          color: cs.surfaceContainerLowest.withValues(alpha: 0.5),
          padding: EdgeInsets.symmetric(
            horizontal: isCompactOrMedium ? AppSpacing.md : AppSpacing.xl,
            vertical: isCompactOrMedium ? AppSpacing.sm : AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Les 3 KPIs consolidés en haut de page
              _buildDesktopSummaryCards(context, summary),
              const SizedBox(height: AppSpacing.md),

              // 2. Barre d'outils ERP (Recherche + Filtres)
              _buildDesktopToolbar(context, summary),
              const SizedBox(height: AppSpacing.md),

              // 3. DataTable ERP
              Expanded(
                child: _buildDesktopDataTable(context, filteredItems),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopSummaryCards(
    BuildContext context,
    StockValuationSummary summary,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final card1 = _SummaryCard(
      icon: Icons.account_balance_wallet_outlined,
      label: 'Valeur du stock (Achat)',
      value: formatFcfa(summary.totalPurchaseValue),
      subtitle:
          '${summary.totalUnitsInStock} unités · Capital immobilisé (FIFO/lots)',
      accentColor: Colors.blue.shade700,
      backgroundColor: Colors.blue.shade50,
    );

    final card2 = _SummaryCard(
      icon: Icons.point_of_sale_outlined,
      label: 'CA potentiel (Vente)',
      value: formatFcfa(summary.totalPotentialRevenue),
      subtitle: 'Valorisation marchande aux prix boutique',
      accentColor: cs.primary,
      backgroundColor: cs.primaryContainer.withValues(alpha: 0.35),
    );

    final card3 = _SummaryCard(
      icon: Icons.trending_up_rounded,
      label: 'Marge potentielle brute',
      value: formatFcfa(summary.totalPotentialMargin),
      subtitle:
          'Gain brut estimé · Taux global : ${summary.overallMarginRate.toStringAsFixed(1)} %',
      accentColor: AppColors.success,
      backgroundColor: AppColors.success.withValues(alpha: 0.1),
      badgeText: '+${summary.overallMarginRate.toStringAsFixed(1)} %',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 840) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(width: 260, child: card1),
                const SizedBox(width: AppSpacing.md),
                SizedBox(width: 260, child: card2),
                const SizedBox(width: AppSpacing.md),
                SizedBox(width: 260, child: card3),
              ],
            ),
          );
        }

        return Row(
          children: [
            Expanded(child: card1),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: card2),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: card3),
          ],
        );
      },
    );
  }

  Widget _buildDesktopToolbar(
    BuildContext context,
    StockValuationSummary summary,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 800;

        final searchRow = Row(
          children: [
            if (Navigator.of(context).canPop()) ...[
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                tooltip: 'Retour',
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Filtrer par nom de produit, SKU ou catégorie…',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => _searchController.clear(),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    filled: true,
                    fillColor: cs.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );

        final filterChips = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildChip(
                label: 'Tous (${summary.items.length})',
                filter: _StockAnalysisFilter.all,
              ),
              const SizedBox(width: 6),
              _buildChip(
                label: 'Top Valeur',
                filter: _StockAnalysisFilter.topValue,
              ),
              const SizedBox(width: 6),
              _buildChip(
                label: 'Top CA',
                filter: _StockAnalysisFilter.topRevenue,
              ),
              const SizedBox(width: 6),
              _buildChip(
                label: 'Top Marge',
                filter: _StockAnalysisFilter.topMargin,
              ),
              const SizedBox(width: 6),
              _buildChip(
                label: 'Stock faible (${summary.lowStockCount})',
                filter: _StockAnalysisFilter.lowStock,
                badgeColor: AppColors.warning,
              ),
              const SizedBox(width: 6),
              _buildChip(
                label: 'Dormant (${summary.deadStockCount})',
                filter: _StockAnalysisFilter.deadStock,
                badgeColor: Colors.orange.shade800,
              ),
              const SizedBox(width: 6),
              _buildChip(
                label: 'En déficit (${summary.items.where((i) => i.quantityInStock < 0).length})',
                filter: _StockAnalysisFilter.deficitStock,
                badgeColor: Colors.redAccent,
              ),
            ],
          ),
        );

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    searchRow,
                    const SizedBox(height: AppSpacing.xs),
                    filterChips,
                  ],
                )
              : Row(
                  children: [
                    Expanded(flex: 2, child: searchRow),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(flex: 3, child: filterChips),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildDesktopDataTable(
    BuildContext context,
    List<ProductStockValuation> items,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    if (items.isEmpty) {
      return EmptyListPlaceholder(
        embedded: true,
        icon: Icons.inventory_2_outlined,
        title: 'Aucun article ne correspond à ce filtre',
        subtitle: _searchQuery.isNotEmpty
            ? 'Aucune référence ne correspond à "$_searchQuery"'
            : 'Modifiez vos filtres ci-dessus.',
      );
    }

    final columns = [
      const AppTableColumn(
        label: 'Réf. / SKU',
        icon: Icons.qr_code_rounded,
        width: 120,
      ),
      const AppTableColumn(
        label: 'Désignation Produit',
        icon: Icons.inventory_2_outlined,
        flex: 3,
        minWidth: 200,
      ),
      const AppTableColumn(
        label: 'Stock Dispo',
        icon: Icons.warehouse_rounded,
        width: 120,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'PMP Achat',
        icon: Icons.shopping_bag_outlined,
        width: 130,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Capital Immobilisé',
        icon: Icons.account_balance_wallet_outlined,
        width: 150,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Prix Vente',
        icon: Icons.sell_outlined,
        width: 120,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'CA Potentiel',
        icon: Icons.point_of_sale_outlined,
        width: 150,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Marge Potentielle',
        icon: Icons.trending_up_rounded,
        width: 150,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Statut',
        width: 130,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
      const AppTableColumn(
        label: 'Action',
        width: 70,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
    ];

    final rows = items.map((item) {
      final skuLabel =
          item.sku?.isNotEmpty == true ? item.sku! : '#${item.productId}';

      return AppTableRow(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProductDetailPage(
                session: widget.session,
                productId: item.productId,
              ),
            ),
          );
          _loadData();
        },
        cells: [
          // 1. SKU
          Text(
            skuLabel,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: AppColors.onSurfaceMuted,
            ),
          ),

          // 2. Produit
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: item.quantityInStock <= 0
                      ? AppColors.danger.withValues(alpha: 0.12)
                      : (item.isLowStock
                          ? AppColors.warning.withValues(alpha: 0.12)
                          : cs.primaryContainer.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  item.quantityInStock <= 0
                      ? Icons.remove_shopping_cart_outlined
                      : (item.isLowStock
                          ? Icons.warning_amber_rounded
                          : Icons.inventory_2_outlined),
                  size: 16,
                  color: item.quantityInStock <= 0
                      ? AppColors.danger
                      : (item.isLowStock ? AppColors.warning : cs.primary),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.categoryName != null)
                      Text(
                        item.categoryName!,
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.outline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),

          // 3. Stock Dispo
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${item.quantityInStock}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: item.quantityInStock <= 0
                      ? AppColors.danger
                      : (item.isLowStock ? AppColors.warning : cs.onSurface),
                ),
              ),
              Text(
                item.isFifoValued ? '${item.lotCount} lot(s) FIFO' : 'Catalogue',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: item.isFifoValued
                      ? cs.primary
                      : AppColors.onSurfaceMuted,
                ),
              ),
            ],
          ),

          // 4. PMP Achat
          Text(
            formatFcfa(item.averagePurchasePrice),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),

          // 5. Capital Immobilisé (Achat)
          Text(
            formatFcfa(item.purchaseValue),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Colors.blue.shade900,
            ),
          ),

          // 6. Prix Vente
          Text(
            formatFcfa(item.priceSell),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),

          // 7. CA Potentiel (Vente)
          Text(
            formatFcfa(item.potentialRevenue),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: cs.primary,
            ),
          ),

          // 8. Marge Potentielle
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatFcfa(item.potentialMargin),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: item.potentialMargin >= 0
                      ? AppColors.success
                      : AppColors.danger,
                ),
              ),
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: (item.potentialMargin >= 0
                          ? AppColors.success
                          : AppColors.danger)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${item.marginRate >= 0 ? '+' : ''}${item.marginRate.toStringAsFixed(1)} %',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: item.potentialMargin >= 0
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ),
              ),
            ],
          ),

          // 9. Statut / Vélocité
          _buildStatusBadge(item),

          // 10. Action
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
            tooltip: 'Voir fiche produit',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProductDetailPage(
                    session: widget.session,
                    productId: item.productId,
                  ),
                ),
              );
              _loadData();
            },
          ),
        ],
      );
    }).toList();

    return AppDesktopDataTable(
      columns: columns,
      rows: rows,
      itemsPerPage: 15,
      minWidth: 1260,
    );
  }

  Widget _buildStatusBadge(ProductStockValuation item) {
    if (item.isDeadStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: Colors.orange.shade300,
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bedtime_outlined, size: 12, color: Colors.orange.shade900),
            const SizedBox(width: 4),
            Text(
              item.daysSinceLastSale != null
                  ? 'Dormant (${item.daysSinceLastSale}j)'
                  : 'Dormant',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.orange.shade900,
              ),
            ),
          ],
        ),
      );
    }

    if (item.quantityInStock < 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.red.shade900.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Text(
          'Déficit (${item.quantityInStock})',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.red.shade700,
          ),
        ),
      );
    }

    if (item.quantityInStock == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: const Text(
          'Épuisé',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.danger,
          ),
        ),
      );
    }

    if (item.isLowStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: const Text(
          'Rupture',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.warning,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: const Text(
        'Actif',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.success,
        ),
      ),
    );
  }

  // ===========================================================================
  // LAYOUT MOBILE : Expérience tactile fluide et ergonomique
  // ===========================================================================

  Widget _buildMobileLayout(
    BuildContext context,
    StockValuationSummary summary,
    List<ProductStockValuation> filteredItems,
    ScreenType screenType,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final horizontal = Breakpoints.horizontalPadding(screenType);

    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          horizontal,
          AppSpacing.sm,
          horizontal,
          AppSpacing.xl + 20,
        ),
        children: [
          // 1. Carrousel horizontal ergonomique des 3 indicateurs de trésorerie
          _buildMobileSummaryCarousel(context, summary),
          const SizedBox(height: AppSpacing.md),

          // 2. Barre de recherche mobile
          _buildMobileSearchBar(context),
          const SizedBox(height: AppSpacing.sm),

          // 3. Filtres stratégiques
          _buildFilterChips(context, summary),
          const SizedBox(height: AppSpacing.md),

          // 4. En-tête de section
          Row(
            children: [
              Expanded(
                child: Text(
                  '${filteredItems.length} article(s)',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.onSurfaceMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Toucher pour détails',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.outline,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // 5. Liste des fiches valorisées
          if (filteredItems.isEmpty)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                side: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: EmptyListPlaceholder(
                  icon: Icons.inventory_2_outlined,
                  title: 'Aucun article trouvé',
                  subtitle: 'Ajustez votre recherche ou vos filtres.',
                ),
              ),
            )
          else
            ...filteredItems.map(
              (item) => _ProductValuationCard(
                valuation: item,
                onTap: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProductDetailPage(
                        session: widget.session,
                        productId: item.productId,
                      ),
                    ),
                  );
                  _loadData();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileSummaryCarousel(
    BuildContext context,
    StockValuationSummary summary,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = (screenWidth * 0.82).clamp(280.0, 380.0);

    final cards = [
      _SummaryCard(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Valeur Achat (Capital)',
        value: formatFcfa(summary.totalPurchaseValue),
        subtitle: '${summary.totalUnitsInStock} unités · Coût réel (FIFO)',
        accentColor: Colors.blue.shade700,
        backgroundColor: Colors.blue.shade50,
      ),
      _SummaryCard(
        icon: Icons.point_of_sale_outlined,
        label: 'CA potentiel (Vente)',
        value: formatFcfa(summary.totalPotentialRevenue),
        subtitle: 'Valorisation marchande boutique',
        accentColor: cs.primary,
        backgroundColor: cs.primaryContainer.withValues(alpha: 0.35),
      ),
      _SummaryCard(
        icon: Icons.trending_up_rounded,
        label: 'Marge brute potentielle',
        value: formatFcfa(summary.totalPotentialMargin),
        subtitle: 'Taux global : ${summary.overallMarginRate.toStringAsFixed(1)} %',
        accentColor: AppColors.success,
        backgroundColor: AppColors.success.withValues(alpha: 0.1),
        badgeText: '+${summary.overallMarginRate.toStringAsFixed(1)} %',
      ),
    ];

    return SizedBox(
      height: 126,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) => SizedBox(
          width: cardWidth,
          child: cards[index],
        ),
      ),
    );
  }

  Widget _buildMobileSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SizedBox(
      height: 44,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          hintText: 'Rechercher un article, SKU, catégorie…',
          hintStyle: theme.textTheme.bodyMedium?.copyWith(
            color: AppColors.onSurfaceMuted,
            fontSize: 13,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          filled: true,
          fillColor: cs.surfaceContainerLowest,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(
              color: cs.primary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(
    BuildContext context,
    StockValuationSummary summary,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildChip(
            label: 'Tous (${summary.items.length})',
            filter: _StockAnalysisFilter.all,
          ),
          const SizedBox(width: 6),
          _buildChip(
            label: 'Plus forte valeur',
            filter: _StockAnalysisFilter.topValue,
          ),
          const SizedBox(width: 6),
          _buildChip(
            label: 'Plus gros CA',
            filter: _StockAnalysisFilter.topRevenue,
          ),
          const SizedBox(width: 6),
          _buildChip(
            label: 'Plus forte marge',
            filter: _StockAnalysisFilter.topMargin,
          ),
          const SizedBox(width: 6),
          _buildChip(
            label: 'Stock faible (${summary.lowStockCount})',
            filter: _StockAnalysisFilter.lowStock,
            badgeColor: AppColors.warning,
          ),
          const SizedBox(width: 6),
          _buildChip(
            label: 'Dormant (${summary.deadStockCount})',
            filter: _StockAnalysisFilter.deadStock,
            badgeColor: Colors.orange.shade800,
          ),
          const SizedBox(width: 6),
          _buildChip(
            label: 'En déficit (${summary.items.where((i) => i.quantityInStock < 0).length})',
            filter: _StockAnalysisFilter.deficitStock,
            badgeColor: Colors.redAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required String label,
    required _StockAnalysisFilter filter,
    Color? badgeColor,
  }) {
    final selected = _selectedFilter == filter;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => setState(() => _selectedFilter = filter),
      selectedColor: cs.primaryContainer,
      checkmarkColor: cs.primary,
      visualDensity: VisualDensity.compact,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        color: selected ? cs.primary : cs.onSurface,
      ),
      side: BorderSide(
        color: selected
            ? cs.primary
            : cs.outlineVariant.withValues(alpha: 0.5),
        width: 1,
      ),
    );
  }
}

// =============================================================================
// COMPOSANTS PARTAGÉS
// =============================================================================

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
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
    final theme = Theme.of(context);

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
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: accentColor,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: accentColor.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte mobile harmonisée avec le design system ARIKE ([ProductCard])
class _ProductValuationCard extends StatelessWidget {
  const _ProductValuationCard({
    required this.valuation,
    required this.onTap,
  });

  final ProductStockValuation valuation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isOut = valuation.quantityInStock <= 0;
    final isLow = valuation.isLowStock;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. En-tête : Icône, Nom, Catégorie, SKU et Badge Stock
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isOut
                          ? AppColors.danger.withValues(alpha: 0.12)
                          : (isLow
                              ? AppColors.warning.withValues(alpha: 0.12)
                              : cs.primaryContainer.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isOut
                          ? Icons.remove_shopping_cart_outlined
                          : (isLow
                              ? Icons.warning_amber_rounded
                              : Icons.inventory_2_outlined),
                      color: isOut
                          ? AppColors.danger
                          : (isLow ? AppColors.warning : cs.primary),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          valuation.productName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (valuation.categoryName != null)
                              valuation.categoryName!,
                            if (valuation.sku != null &&
                                valuation.sku!.isNotEmpty)
                              valuation.sku!
                            else
                              '#${valuation.productId}',
                          ].join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Badge de Stock
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isOut
                          ? AppColors.danger.withValues(alpha: 0.12)
                          : (isLow
                              ? AppColors.warning.withValues(alpha: 0.15)
                              : cs.surfaceContainerHighest),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      valuation.quantityInStock < 0
                          ? 'Déficit : ${valuation.quantityInStock}'
                          : (isOut
                              ? 'Épuisé'
                              : 'Stock : ${valuation.quantityInStock}'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isOut
                            ? AppColors.danger
                            : (isLow ? AppColors.warning : cs.onSurface),
                      ),
                    ),
                  ),
                ],
              ),

              // Badges d'alerte (Dormant, FIFO)
              if (valuation.isDeadStock || valuation.isFifoValued) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (valuation.isDeadStock)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                          border: Border.all(
                            color: Colors.orange.shade300,
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bedtime_outlined,
                              size: 12,
                              color: Colors.orange.shade900,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              valuation.daysSinceLastSale != null
                                  ? 'Dormant (${valuation.daysSinceLastSale}j sans vente)'
                                  : 'Dormant (jamais vendu)',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (valuation.isFifoValued)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          '${valuation.lotCount} lot(s) FIFO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: cs.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.sm),

              // 2. Bloc financier ergonomique 3 colonnes
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    // Achat
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Achat (Immobilisé)',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.onSurfaceMuted,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              formatFcfa(valuation.purchaseValue),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'PMP: ${formatFcfa(valuation.averagePurchasePrice)}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.onSurfaceMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // CA Vente
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'CA Potentiel',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.onSurfaceMuted,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: Text(
                              formatFcfa(valuation.potentialRevenue),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: cs.primary,
                              ),
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: Text(
                              'Prix: ${formatFcfa(valuation.priceSell)}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.onSurfaceMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Marge Brute
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Marge Brute',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.onSurfaceMuted,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 1),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              formatFcfa(valuation.potentialMargin),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: valuation.potentialMargin >= 0
                                    ? AppColors.success
                                    : AppColors.danger,
                              ),
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 1),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: (valuation.potentialMargin >= 0
                                      ? AppColors.success
                                      : AppColors.danger)
                                  .withValues(alpha: 0.12),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${valuation.marginRate >= 0 ? '+' : ''}${valuation.marginRate.toStringAsFixed(1)} %',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: valuation.potentialMargin >= 0
                                      ? AppColors.success
                                      : AppColors.danger,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
