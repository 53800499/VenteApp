import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../core/responsive/screen_type.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../../shared/components/app_header_actions.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../procurement/presentation/models/po_form_prefill.dart';
import '../../../procurement/presentation/utils/procurement_navigation.dart';
import '../../domain/entities/inventory_entities.dart';
import '../../domain/entities/stock_valuation_entities.dart';
import '../../domain/services/stock_valuation_service.dart';
import '../../domain/usecases/stock_valuation_usecases.dart';
import '../bloc/product_detail_bloc.dart';
import '../widgets/inventory_feedback.dart';
import '../widgets/stock_gauge.dart';
import '../widgets/stock_lot_tile.dart';
import '../widgets/stock_movement_tile.dart';
import '../widgets/product_price_history_section.dart';
import 'product_form_page.dart';
import 'stock_adjustment_page.dart';

class ProductDetailPage extends StatelessWidget {
  const ProductDetailPage({
    super.key,
    required this.session,
    required this.productId,
  });

  final AuthSession session;
  final int productId;

  bool get _canWrite => PermissionGuard.can(
        session.user.permissions,
        Permission.inventoryWrite,
      );

  bool get _canAdjust => PermissionGuard.can(
        session.user.permissions,
        Permission.inventoryAdjust,
      );

  bool get _canArchive => PermissionGuard.can(
        session.user.permissions,
        Permission.inventoryArchive,
      );

  bool get _canProcure => PermissionGuard.can(
        session.user.permissions,
        Permission.procurementCreate,
      );

  bool get _canViewLots => PermissionGuard.can(
        session.user.permissions,
        Permission.inventoryWrite,
      );

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ProductDetailBloc(
        getProductDetail: sl(),
        archiveProduct: sl(),
        shopId: session.shop.id,
        productId: productId,
      )..add(const ProductDetailLoadRequested()),
      child: BlocConsumer<ProductDetailBloc, ProductDetailState>(
        listenWhen: (prev, curr) {
          if (curr.archived && !prev.archived) return true;
          if (prev.errorMessage != curr.errorMessage &&
              curr.errorMessage != null &&
              curr.status == ProductDetailStatus.loaded) {
            return true;
          }
          return false;
        },
        listener: (context, state) async {
          if (state.archived) {
            await InventoryFeedback.showSuccess(
              context: context,
              title: 'Produit archivé',
              message:
                  'Le produit a été retiré du catalogue actif.',
            );
            if (context.mounted) Navigator.of(context).pop(true);
            return;
          }
          if (state.errorMessage != null) {
            await InventoryFeedback.showErrorDialog(
              context,
              title: 'Action impossible',
              message: state.errorMessage!,
            );
            if (context.mounted) {
              context
                  .read<ProductDetailBloc>()
                  .add(const ProductDetailErrorDismissed());
            }
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Fiche produit'),
              actions: [
                if (_canWrite && state.detail != null)
                  IconButton(
                    onPressed: () async {
                      final changed = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => ProductFormPage(
                            session: session,
                            product: state.detail!.product,
                          ),
                        ),
                      );
                      if (changed == true && context.mounted) {
                        context
                            .read<ProductDetailBloc>()
                            .add(const ProductDetailLoadRequested());
                      }
                    },
                    icon: const Icon(Icons.edit_outlined),
                  ),
                const AppHeaderActions(),
              ],
            ),
            body: _buildBody(context, state),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, ProductDetailState state) {
    if (state.status == ProductDetailStatus.loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.md),
            Text('Chargement du produit…'),
          ],
        ),
      );
    }

    if (state.status == ProductDetailStatus.failure || state.detail == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(state.errorMessage ?? 'Produit introuvable'),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () => context
                    .read<ProductDetailBloc>()
                    .add(const ProductDetailLoadRequested()),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    final detail = state.detail!;
    final product = detail.product;
    final valuation = const StockValuationService().calculateProductValuation(
      product: product,
      activeLots: detail.stockLots,
    );

    return ResponsiveBuilder(
      builder: (context, screenType) {
        final horizontal = Breakpoints.horizontalPadding(screenType);

        return ListView(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            AppSpacing.md,
            horizontal,
            AppSpacing.lg,
          ),
          children: [
            if (state.errorMessage != null) ...[
              ErrorBanner(message: state.errorMessage!),
              const SizedBox(height: AppSpacing.md),
            ],
            Text(
              product.name,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (product.categoryName != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                product.categoryName!,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            if (screenType.isTablet)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Stock : ${product.quantityInStock}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            StockGauge(
                              quantity: product.quantityInStock,
                              alertThreshold: product.alertThreshold,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      children: [
                        _InfoTile(
                          label: 'Prix de vente',
                          value: formatFcfa(product.priceSell),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _InfoTile(
                          label: 'Dernier prix d\'achat (lots)',
                          value: product.priceBuy != null
                              ? formatFcfa(product.priceBuy!)
                              : '—',
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stock : ${product.quantityInStock}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      StockGauge(
                        quantity: product.quantityInStock,
                        alertThreshold: product.alertThreshold,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _InfoTile(
                      label: 'Prix de vente',
                      value: formatFcfa(product.priceSell),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _InfoTile(
                      label: 'Dernier prix d\'achat (lots)',
                      value: product.priceBuy != null
                          ? formatFcfa(product.priceBuy!)
                          : '—',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _buildValuationCard(context, valuation, product),
            const SizedBox(height: AppSpacing.md),
            _buildSalesVelocitySection(context, product.id),
            if (_canProcure && product.isLowStock) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: () {
                  final deficit =
                      (product.alertThreshold - product.quantityInStock)
                          .clamp(1, product.alertThreshold);
                  final suggestedQty = product.alertThreshold + deficit;
                  openPoFormPage(
                    context,
                    session,
                    prefill: PoFormPrefill(
                      productId: product.id,
                      productName: product.name,
                      suggestedQuantity: suggestedQty,
                      unitCost: product.priceBuy,
                    ),
                  );
                },
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text('Commander ce produit'),
              ),
            ],
            if (_canAdjust) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: () async {
                  final changed = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => StockAdjustmentPage(
                        session: session,
                        product: product,
                      ),
                    ),
                  );
                  if (changed == true && context.mounted) {
                    context.read<ProductDetailBloc>().add(
                          const ProductDetailLoadRequested(),
                        );
                  }
                },
                icon: const Icon(Icons.tune),
                label: const Text('Ajuster le stock'),
              ),
            ],
            if (_canArchive && detail.saleItemCount == 0) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                onPressed:
                    state.isArchiving ? null : () => _confirmArchive(context),
                icon: state.isArchiving
                    ? InventoryFeedback.inlineLoader(size: 18)
                    : const Icon(Icons.archive_outlined),
                label: Text(
                  state.isArchiving ? 'Archivage…' : 'Archiver',
                ),
              ),
            ] else if (detail.saleItemCount > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Archivage uniquement : ce produit a ${detail.saleItemCount} vente(s) liée(s).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_canViewLots) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Lots de stock (FIFO)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (detail.stockLots.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: EmptyListPlaceholder(
                      icon: Icons.inventory_2_outlined,
                      title: 'Aucun lot actif',
                    ),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < detail.stockLots.length; i++)
                        StockLotTile(
                          lot: detail.stockLots[i],
                          fifoRank: i + 1,
                        ),
                    ],
                  ),
                ),
            ],
            ProductPriceHistorySection(
              shopId: session.shop.id,
              productId: product.id,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Derniers mouvements',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (detail.recentMovements.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: EmptyListPlaceholder(
                    icon: Icons.swap_vert,
                    title: 'Aucun mouvement enregistré',
                  ),
                ),
              )
            else
              Card(
                child: Column(
                  children: detail.recentMovements
                      .map((m) => StockMovementTile(movement: m))
                      .toList(),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _confirmArchive(BuildContext context) async {
    final confirmed = await InventoryFeedback.confirm(
      context: context,
      title: 'Archiver ce produit ?',
      message:
          'Le produit sera retiré du catalogue actif mais restera visible dans l\'historique.',
      confirmLabel: 'Archiver',
      isDestructive: true,
    );

    if (confirmed == true && context.mounted) {
      context.read<ProductDetailBloc>().add(const ProductDetailArchiveRequested());
    }
  }

  Widget _buildValuationCard(
    BuildContext context,
    ProductStockValuation valuation,
    Product product,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 20,
                  color: cs.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Valorisation du stock',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (valuation.isFifoValued)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      '${valuation.lotCount} lot(s) FIFO',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'Prix catalogue',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    label: 'Valeur d\'achat (Capital)',
                    value: formatFcfa(valuation.purchaseValue),
                    subtitle: valuation.quantityInStock > 0
                        ? 'PMP : ${formatFcfa(valuation.averagePurchasePrice)} / u'
                        : 'Stock nul',
                    backgroundColor:
                        cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _MetricCard(
                    label: 'CA potentiel (Vente)',
                    value: formatFcfa(valuation.potentialRevenue),
                    subtitle: 'Prix : ${formatFcfa(product.priceSell)} / u',
                    backgroundColor:
                        cs.primaryContainer.withValues(alpha: 0.25),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: valuation.potentialMargin >= 0
                    ? Colors.green.shade50
                    : Colors.red.shade50,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: valuation.potentialMargin >= 0
                      ? Colors.green.shade300
                      : Colors.red.shade300,
                  width: 0.8,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Marge brute potentielle',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: valuation.potentialMargin >= 0
                                ? Colors.green.shade900
                                : Colors.red.shade900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            formatFcfa(valuation.potentialMargin),
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: valuation.potentialMargin >= 0
                                  ? Colors.green.shade900
                                  : Colors.red.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: valuation.potentialMargin >= 0
                          ? Colors.green.shade600
                          : Colors.red.shade600,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      'Taux : ${valuation.marginRate.toStringAsFixed(1)} %',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesVelocitySection(BuildContext context, int productId) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return FutureBuilder<ProductSalesVelocity>(
      future: sl<GetProductSalesVelocity>()(
        shopId: session.shop.id,
        productId: productId,
      ),
      builder: (context, snapshot) {
        final velocity = snapshot.data ?? ProductSalesVelocity.empty;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.trending_up_rounded,
                        size: 20, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dynamique des ventes',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isLoading) ...[
                      const SizedBox(width: 8),
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _VelocityCell(
                        period: 'Aujourd\'hui',
                        qty: velocity.salesToday,
                        revenue: velocity.revenueToday,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _VelocityCell(
                        period: 'Cette semaine',
                        qty: velocity.salesThisWeek,
                        revenue: velocity.revenueThisWeek,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _VelocityCell(
                        period: 'Ce mois',
                        qty: velocity.salesThisMonth,
                        revenue: velocity.revenueThisMonth,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _VelocityCell(
                        period: 'Total réalisé',
                        qty: velocity.salesTotal,
                        revenue: velocity.revenueTotal,
                        isTotal: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.backgroundColor,
  });

  final String label;
  final String value;
  final String subtitle;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.outline,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _VelocityCell extends StatelessWidget {
  const _VelocityCell({
    required this.period,
    required this.qty,
    required this.revenue,
    this.isTotal = false,
  });

  final String period;
  final int qty;
  final int revenue;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isTotal
            ? cs.secondaryContainer.withValues(alpha: 0.3)
            : cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.xs),
        border: Border.all(
          color: isTotal
              ? cs.primary.withValues(alpha: 0.3)
              : cs.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            period,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isTotal ? cs.primary : cs.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$qty unité${qty > 1 ? 's' : ''}',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatFcfa(revenue),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: cs.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
