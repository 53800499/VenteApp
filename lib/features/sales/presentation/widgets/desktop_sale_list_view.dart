import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/components/app_desktop_data_table.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/sale_entities.dart';
import '../bloc/sale_list_bloc.dart';

/// Vue Desktop ERP moderne et adaptative pour le listing des ventes.
class DesktopSaleListView extends StatefulWidget {
  const DesktopSaleListView({
    super.key,
    required this.session,
    required this.state,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onRefresh,
    required this.onNewSale,
    required this.onQuickSale,
    required this.onSaleTap,
    required this.canCreate,
  });

  final AuthSession session;
  final SaleListState state;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final Future<void> Function() onRefresh;
  final VoidCallback onNewSale;
  final VoidCallback onQuickSale;
  final ValueChanged<int> onSaleTap;
  final bool canCreate;

  @override
  State<DesktopSaleListView> createState() => _DesktopSaleListViewState();
}

class _DesktopSaleListViewState extends State<DesktopSaleListView> {
  SaleType? _filterType;
  SaleStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final allSales = widget.state.sales;

    // Filtrage local en plus de la recherche du bloc
    final filteredSales = allSales.where((s) {
      if (_filterType != null && s.saleType != _filterType) return false;
      if (_filterStatus != null && s.status != _filterStatus) return false;
      return true;
    }).toList();

    // Calculs de synthèse
    final completedSales = allSales.where((s) => s.status != SaleStatus.cancelled);
    final totalRevenue = completedSales.fold<int>(0, (sum, s) => sum + s.totalAmount);

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
            // 1. Barre de commande supérieure Desktop
            _buildCommandHeader(context, theme, scheme, totalRevenue, allSales.length),

            const SizedBox(height: AppSpacing.md),

            // 2. Barre d'outils (Recherche + Filtres de type & statut)
            _buildToolbar(theme, scheme),

            const SizedBox(height: AppSpacing.md),

            // 3. Tableau de données moderne ERP
            Expanded(
              child: _buildDataTable(context, theme, scheme, filteredSales),
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
    int totalRevenue,
    int totalCount,
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
              Icons.point_of_sale_rounded,
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
                      'Historique des Ventes',
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
                        '$totalCount vente${totalCount > 1 ? 's' : ''}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Volume total réalisé : ${formatFcfa(totalRevenue)}',
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
            onPressed: widget.state.isRefreshing ? null : widget.onRefresh,
            tooltip: 'Actualiser la liste',
            icon: widget.state.isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 20),
          ),
          if (widget.canCreate) ...[
            const SizedBox(width: AppSpacing.sm),
            OutlinedButton.icon(
              onPressed: widget.onQuickSale,
              icon: const Icon(Icons.flash_on_rounded, size: 18),
              label: const Text('Vente rapide'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD97706),
                side: BorderSide(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 2,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            FilledButton.icon(
              onPressed: widget.onNewSale,
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
              label: const Text('Nouvelle Vente (F2)'),
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

  Widget _buildToolbar(ThemeData theme, ColorScheme scheme) {
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
          // Champ de recherche
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: widget.searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher par n° de reçu, client…',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: widget.searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: widget.onClearSearch,
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
                onChanged: widget.onSearchChanged,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Filtres par type de vente
          FilterChip(
            label: const Text('Toutes'),
            selected: _filterType == null && _filterStatus == null,
            onSelected: (_) {
              setState(() {
                _filterType = null;
                _filterStatus = null;
              });
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: AppSpacing.xs),
          FilterChip(
            avatar: const Icon(Icons.receipt_long_outlined, size: 14),
            label: const Text('Standard'),
            selected: _filterType == SaleType.standard,
            onSelected: (selected) {
              setState(() {
                _filterType = selected ? SaleType.standard : null;
              });
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: AppSpacing.xs),
          FilterChip(
            avatar: const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFFD97706)),
            label: const Text('Rapide'),
            selected: _filterType == SaleType.quick,
            onSelected: (selected) {
              setState(() {
                _filterType = selected ? SaleType.quick : null;
              });
            },
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: AppSpacing.xs),
          FilterChip(
            avatar: const Icon(Icons.cancel_outlined, size: 14, color: AppColors.danger),
            label: const Text('Annulées'),
            selected: _filterStatus == SaleStatus.cancelled,
            onSelected: (selected) {
              setState(() {
                _filterStatus = selected ? SaleStatus.cancelled : null;
              });
            },
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    List<SaleListRow> sales,
  ) {
    if (sales.isEmpty) {
      return EmptyListPlaceholder(
        embedded: true,
        icon: Icons.receipt_long_outlined,
        title: 'Aucune vente trouvée',
        subtitle: widget.searchController.text.isNotEmpty
            ? 'Aucune transaction ne correspond à "${widget.searchController.text}"'
            : 'Enregistrez votre première vente avec le bouton ci-dessus.',
      );
    }

    final columns = [
      const AppTableColumn(
        label: 'Reçu / ID',
        icon: Icons.tag_rounded,
        width: 140,
      ),
      const AppTableColumn(
        label: 'Date & Heure',
        icon: Icons.access_time_rounded,
        width: 160,
      ),
      const AppTableColumn(
        label: 'Client',
        icon: Icons.person_outline_rounded,
        flex: 2,
      ),
      const AppTableColumn(
        label: 'Type',
        icon: Icons.category_outlined,
        width: 130,
      ),
      const AppTableColumn(
        label: 'Montant Total',
        icon: Icons.monetization_on_outlined,
        width: 160,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Statut',
        icon: Icons.check_circle_outline_rounded,
        width: 130,
        alignment: Alignment.center,
      ),
      const AppTableColumn(
        label: 'Action',
        width: 100,
        alignment: Alignment.center,
      ),
    ];

    final rows = sales.map((sale) {
      final isCancelled = sale.status == SaleStatus.cancelled;
      final dt = DateTime.fromMillisecondsSinceEpoch(sale.createdAt);
      final formattedDate = AppDateFormatter.formatDateTime(dt);
      final receiptLabel = sale.receiptNumber?.replaceAll('/', '') ?? '#${sale.id}';

      return AppTableRow(
        onTap: () => widget.onSaleTap(sale.id),
        cells: [
          // 1. Reçu
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                sale.saleType == SaleType.quick
                    ? Icons.flash_on_rounded
                    : Icons.receipt_long_rounded,
                size: 16,
                color: isCancelled
                    ? AppColors.onSurfaceMuted
                    : (sale.saleType == SaleType.quick
                        ? const Color(0xFFD97706)
                        : scheme.primary),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  receiptLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                    color: isCancelled ? AppColors.onSurfaceMuted : scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // 2. Date
          Text(
            formattedDate,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.onSurfaceMuted,
              fontSize: 13,
            ),
          ),

          // 3. Client
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: scheme.primaryContainer.withValues(alpha: 0.5),
                child: Text(
                  (sale.customerName?.isNotEmpty ?? false)
                      ? sale.customerName![0].toUpperCase()
                      : 'C',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  sale.customerName ?? 'Client comptant',
                  style: TextStyle(
                    fontWeight: sale.customerName != null ? FontWeight.w600 : FontWeight.w400,
                    color: sale.customerName != null ? scheme.onSurface : AppColors.onSurfaceMuted,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          // 4. Type
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: sale.saleType == SaleType.quick
                  ? const Color(0xFFFEF3C7)
                  : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Text(
              sale.saleType == SaleType.quick ? 'Vente rapide' : 'Standard',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: sale.saleType == SaleType.quick
                    ? const Color(0xFFB45309)
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),

          // 5. Montant Total
          Text(
            formatFcfa(sale.totalAmount),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: isCancelled ? AppColors.onSurfaceMuted : scheme.primary,
              decoration: isCancelled ? TextDecoration.lineThrough : null,
            ),
          ),

          // 6. Statut
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isCancelled
                  ? AppColors.danger.withValues(alpha: 0.12)
                  : AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: isCancelled
                    ? AppColors.danger.withValues(alpha: 0.4)
                    : AppColors.success.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isCancelled ? Icons.close_rounded : Icons.check_circle_rounded,
                  size: 12,
                  color: isCancelled ? AppColors.danger : AppColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  isCancelled ? 'Annulée' : 'Validée',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isCancelled ? AppColors.danger : AppColors.success,
                  ),
                ),
              ],
            ),
          ),

          // 7. Action
          IconButton(
            onPressed: () => widget.onSaleTap(sale.id),
            tooltip: 'Voir les détails de la vente',
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
      minWidth: 850,
    );
  }
}
