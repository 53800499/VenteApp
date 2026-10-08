import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/components/app_desktop_data_table.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/inventory_entities.dart';
import '../bloc/product_list_bloc.dart';

/// Vue Desktop ERP moderne et adaptative pour le listing des stocks et produits.
class DesktopProductListView extends StatelessWidget {
  const DesktopProductListView({
    super.key,
    required this.session,
    required this.state,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onRefresh,
    required this.onNewProduct,
    required this.onManageCategories,
    required this.onProductTap,
    required this.onCategorySelected,
    required this.onLowStockToggled,
    required this.onSortSelected,
    required this.canWrite,
  });

  final AuthSession session;
  final ProductListState state;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final Future<void> Function() onRefresh;
  final VoidCallback onNewProduct;
  final VoidCallback onManageCategories;
  final ValueChanged<Product> onProductTap;
  final ValueChanged<int?> onCategorySelected;
  final ValueChanged<bool> onLowStockToggled;
  final ValueChanged<ProductSort> onSortSelected;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final products = state.products;

    final lowStockCount = products.where((p) => p.isLowStock || p.quantityInStock <= p.alertThreshold).length;

    return Container(
      color: scheme.surfaceContainerLowest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. En-tête de commande ERP
            _buildCommandHeader(context, theme, scheme, products.length, lowStockCount),

            const SizedBox(height: AppSpacing.md),

            // 2. Barre d'outils (Recherche + Filtres Catégories / Alertes / Tri)
            _buildToolbar(context, theme, scheme, lowStockCount),

            const SizedBox(height: AppSpacing.md),

            // 3. Tableau de données moderne ERP
            Expanded(
              child: _buildDataTable(context, theme, scheme, products),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandHeader(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    int totalCount,
    int lowStockCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.inventory_2_rounded,
              color: scheme.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    Text(
                      'Gestion des Stocks & Produits',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '$totalCount référence${totalCount > 1 ? 's' : ''}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (lowStockCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '$lowStockCount en alerte',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.warning,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Catalogue de vente, suivi des approvisionnements et alertes de rupture en temps réel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Actions
          IconButton(
            onPressed: state.isRefreshing ? null : onRefresh,
            tooltip: 'Actualiser le catalogue',
            icon: state.isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 20),
          ),
          if (canWrite) ...[
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: onManageCategories,
              icon: const Icon(Icons.category_outlined, size: 18),
              label: const Text('Gérer les catégories'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 2,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.icon(
              onPressed: onNewProduct,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Nouveau Produit'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm + 2,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    int lowStockCount,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          // Recherche
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher un produit, SKU, code-barres…',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: onClearSearch,
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  filled: true,
                  fillColor: scheme.surfaceContainerLowest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide(color: scheme.primary, width: 1.5),
                  ),
                ),
                onChanged: onSearchChanged,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Filtre Stock faible
          FilterChip(
            avatar: Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: state.filters.lowStockOnly ? AppColors.warning : AppColors.onSurfaceMuted,
            ),
            label: Text(
              lowStockCount > 0 ? 'Stock faible ($lowStockCount)' : 'Stock faible',
            ),
            selected: state.filters.lowStockOnly,
            onSelected: onLowStockToggled,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: AppSpacing.xs),

          // Menu déroulant des catégories
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: state.filters.categoryId,
                hint: const Text('Toutes les catégories', style: TextStyle(fontSize: 13)),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                  fontSize: 13,
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Toutes les catégories'),
                  ),
                  ...state.categories.map(
                    (cat) => DropdownMenuItem<int?>(
                      value: cat.id,
                      child: Text(cat.name),
                    ),
                  ),
                ],
                onChanged: onCategorySelected,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),

          // Menu de tri
          PopupMenuButton<ProductSort>(
            tooltip: 'Trier la liste',
            onSelected: onSortSelected,
            itemBuilder: (_) => const [
              PopupMenuItem(value: ProductSort.nameAsc, child: Text('Nom A → Z')),
              PopupMenuItem(value: ProductSort.nameDesc, child: Text('Nom Z → A')),
              PopupMenuItem(value: ProductSort.stockAsc, child: Text('Stock croissant')),
              PopupMenuItem(value: ProductSort.stockDesc, child: Text('Stock décroissant')),
              PopupMenuItem(value: ProductSort.priceAsc, child: Text('Prix croissant')),
              PopupMenuItem(value: ProductSort.priceDesc, child: Text('Prix décroissant')),
            ],
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort_rounded, size: 18, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    'Trier',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    List<Product> products,
  ) {
    if (products.isEmpty) {
      return EmptyListPlaceholder(
        embedded: true,
        icon: Icons.inventory_2_outlined,
        title: state.filters.lowStockOnly
            ? 'Aucun produit en alerte de stock'
            : 'Aucun produit dans le catalogue',
        subtitle: searchController.text.isNotEmpty
            ? 'Aucune référence ne correspond à "${searchController.text}"'
            : (canWrite ? 'Ajoutez votre premier produit avec le bouton ci-dessus.' : null),
      );
    }

    final columns = [
      const AppTableColumn(
        label: 'Réf. / SKU',
        icon: Icons.qr_code_rounded,
        width: 130,
      ),
      const AppTableColumn(
        label: 'Désignation Produit',
        icon: Icons.inventory_2_outlined,
        flex: 3,
      ),
      const AppTableColumn(
        label: 'Catégorie',
        icon: Icons.category_outlined,
        width: 160,
      ),
      const AppTableColumn(
        label: 'Prix Unitaire',
        icon: Icons.monetization_on_outlined,
        width: 150,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Stock Dispo',
        icon: Icons.warehouse_rounded,
        width: 140,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Seuil Min',
        icon: Icons.notifications_none_rounded,
        width: 110,
        alignment: Alignment.center,
      ),
      const AppTableColumn(
        label: 'État',
        icon: Icons.health_and_safety_outlined,
        width: 140,
        alignment: Alignment.center,
      ),
      const AppTableColumn(
        label: 'Action',
        width: 100,
        alignment: Alignment.center,
      ),
    ];

    final rows = products.map((product) {
      final isOut = product.quantityInStock <= 0;
      final isLow = product.isLowStock || product.quantityInStock <= product.alertThreshold;
      final skuLabel = product.sku?.isNotEmpty == true ? product.sku! : '#${product.id}';

      return AppTableRow(
        onTap: () => onProductTap(product),
        cells: [
          // 1. SKU
          Text(
            skuLabel,
            style: TextStyle(
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
                  color: isOut
                      ? AppColors.danger.withValues(alpha: 0.12)
                      : (isLow
                          ? AppColors.warning.withValues(alpha: 0.12)
                          : scheme.primaryContainer.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                  color: isOut
                      ? AppColors.danger
                      : (isLow ? AppColors.warning : scheme.primary),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (product.categoryName != null)
                      Text(
                        product.categoryName!,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.onSurfaceMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),

          // 3. Catégorie
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              product.categoryName ?? 'Non classé',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // 4. Prix unitaire
          Text(
            formatFcfa(product.priceSell),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: scheme.primary,
            ),
          ),

          // 5. Stock
          Text(
            '${product.quantityInStock}',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: isOut
                  ? AppColors.danger
                  : (isLow ? AppColors.warning : AppColors.success),
            ),
          ),

          // 6. Seuil Alerte
          Text(
            'min ${product.alertThreshold}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.onSurfaceMuted,
              fontWeight: FontWeight.w500,
            ),
          ),

          // 7. État
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isOut
                  ? AppColors.danger.withValues(alpha: 0.12)
                  : (isLow
                      ? AppColors.warning.withValues(alpha: 0.12)
                      : AppColors.success.withValues(alpha: 0.12)),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: isOut
                    ? AppColors.danger.withValues(alpha: 0.4)
                    : (isLow
                        ? AppColors.warning.withValues(alpha: 0.4)
                        : AppColors.success.withValues(alpha: 0.4)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isOut
                      ? Icons.cancel_rounded
                      : (isLow ? Icons.warning_rounded : Icons.check_circle_rounded),
                  size: 12,
                  color: isOut
                      ? AppColors.danger
                      : (isLow ? AppColors.warning : AppColors.success),
                ),
                const SizedBox(width: 4),
                Text(
                  isOut
                      ? 'Rupture'
                      : (isLow ? 'Faible' : 'En stock'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isOut
                        ? AppColors.danger
                        : (isLow ? AppColors.warning : AppColors.success),
                  ),
                ),
              ],
            ),
          ),

          // 8. Action
          IconButton(
            onPressed: () => onProductTap(product),
            tooltip: 'Fiche produit & Stock',
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            visualDensity: VisualDensity.compact,
          ),
        ],
      );
    }).toList();

    return AppDesktopDataTable(
      columns: columns,
      rows: rows,
      itemsPerPage: 15,
      minWidth: 900,
    );
  }
}
