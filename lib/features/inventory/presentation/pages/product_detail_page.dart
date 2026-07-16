import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../core/responsive/screen_type.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../procurement/presentation/models/po_form_prefill.dart';
import '../../../procurement/presentation/utils/procurement_navigation.dart';
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
              MaterialBanner(
                content: Text(state.errorMessage!),
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                actions: [
                  TextButton(
                    onPressed: () {},
                    child: const SizedBox.shrink(),
                  ),
                ],
              ),
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
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
