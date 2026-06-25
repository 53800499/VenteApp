import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../core/responsive/screen_type.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../bloc/product_detail_bloc.dart';
import '../widgets/stock_gauge.dart';
import '../widgets/stock_movement_tile.dart';
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
        listener: (context, state) {
          if (state.archived) {
            Navigator.of(context).pop(true);
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
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == ProductDetailStatus.failure || state.detail == null) {
      return Center(
        child: Text(state.errorMessage ?? 'Produit introuvable'),
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
                          label: 'Prix vente',
                          value: formatFcfa(product.priceSell),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _InfoTile(
                          label: 'Prix achat',
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
                      label: 'Prix vente',
                      value: formatFcfa(product.priceSell),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _InfoTile(
                      label: 'Prix achat',
                      value: product.priceBuy != null
                          ? formatFcfa(product.priceBuy!)
                          : '—',
                    ),
                  ),
                ],
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
                    context
                        .read<ProductDetailBloc>()
                        .add(const ProductDetailLoadRequested());
                    Navigator.of(context).pop(true);
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
                icon: const Icon(Icons.archive_outlined),
                label: const Text('Archiver'),
              ),
            ] else if (detail.saleItemCount > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Archivage uniquement : ce produit a ${detail.saleItemCount} vente(s) liée(s).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Derniers mouvements',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            if (detail.recentMovements.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text('Aucun mouvement enregistré'),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archiver ce produit ?'),
        content: const Text(
          'Le produit sera retiré du catalogue actif mais restera visible dans l\'historique.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archiver'),
          ),
        ],
      ),
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
