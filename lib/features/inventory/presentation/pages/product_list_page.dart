import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../core/responsive/screen_type.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/inventory_entities.dart';
import '../../../procurement/presentation/models/po_form_prefill.dart';
import '../../../procurement/presentation/utils/procurement_navigation.dart';
import '../bloc/product_list_bloc.dart';
import '../widgets/product_card.dart';
import 'product_detail_page.dart';
import 'product_form_page.dart';
import 'category_list_page.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({
    super.key,
    required this.session,
    this.initialLowStockOnly = false,
  });

  final AuthSession session;
  final bool initialLowStockOnly;

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage> {
  final _searchController = TextEditingController();

  bool get _canWrite => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.inventoryWrite,
      );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = _buildScaffold(context);

    final hasBloc =
        context.findAncestorWidgetOfExactType<BlocProvider<ProductListBloc>>() !=
            null;
    if (hasBloc) {
      return scaffold;
    }

    return BlocProvider(
      create: (_) => ProductListBloc(
        listProducts: sl(),
        listCategories: sl(),
        repository: sl(),
        syncPolicy: sl(),
        session: widget.session,
        initialFilters: ProductListFilters(
          lowStockOnly: widget.initialLowStockOnly,
        ),
        syncService: sl(),
      )..add(const ProductListLoadRequested()),
      child: scaffold,
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
            body: Column(
              children: [
                BlocBuilder<ProductListBloc, ProductListState>(
                  buildWhen: (prev, curr) =>
                      prev.isRefreshing != curr.isRefreshing,
                  builder: (context, state) {
                    if (!state.isRefreshing) {
                      return const SizedBox.shrink();
                    }
                    return const LinearProgressIndicator();
                  },
                ),
                ResponsiveBuilder(
                  builder: (context, screenType) {
                    final horizontal =
                        Breakpoints.horizontalPadding(screenType);
                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        AppSpacing.sm,
                        horizontal,
                        AppSpacing.sm,
                      ),
                      child: Column(
                        children: [
                          TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Rechercher un produit…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    context.read<ProductListBloc>().add(
                                          const ProductListSearchChanged(''),
                                        );
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          setState(() {});
                          context
                              .read<ProductListBloc>()
                              .add(ProductListSearchChanged(value));
                        },
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Expanded(child: _FiltersBar(canWrite: _canWrite)),
                          if (_canWrite)
                            TextButton.icon(
                              onPressed: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CategoryListPage(
                                      session: widget.session,
                                    ),
                                  ),
                                );
                                if (context.mounted) {
                                  context.read<ProductListBloc>().add(
                                        const ProductListLocalRefreshRequested(),
                                      );
                                }
                              },
                              icon: const Icon(Icons.category_outlined, size: 18),
                              label: const Text('Gérer'),
                            ),
                        ],
                      ),
                        ],
                      ),
                    );
                  },
                ),
                Expanded(
                  child: _ProductListView(
                    session: widget.session,
                    canWrite: _canWrite,
                  ),
                ),
              ],
            ),
            floatingActionButton: _canWrite
                ? FloatingActionButton.extended(
                    onPressed: () async {
                      final created = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) =>
                              ProductFormPage(session: widget.session),
                        ),
                      );
                      if (created == true && context.mounted) {
                        context
                            .read<ProductListBloc>()
                            .add(const ProductListLocalRefreshRequested());
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Produit'),
                  )
                : null,
    );
  }
}

class _FiltersBar extends StatelessWidget {
  const _FiltersBar({required this.canWrite});

  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductListBloc, ProductListState>(
      builder: (context, state) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('Stock faible'),
                selected: state.filters.lowStockOnly,
                onSelected: (value) => context
                    .read<ProductListBloc>()
                    .add(ProductListLowStockToggled(value)),
              ),
              const SizedBox(width: AppSpacing.sm),
              ...state.categories.map(
                (category) => Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: FilterChip(
                    label: Text(category.name),
                    selected: state.filters.categoryId == category.id,
                    onSelected: (selected) {
                      context.read<ProductListBloc>().add(
                            ProductListCategoryChanged(
                              selected ? category.id : null,
                            ),
                          );
                    },
                  ),
                ),
              ),
              PopupMenuButton<ProductSort>(
                icon: const Icon(Icons.sort),
                tooltip: 'Trier',
                onSelected: (sort) => context
                    .read<ProductListBloc>()
                    .add(ProductListSortChanged(sort)),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: ProductSort.nameAsc,
                    child: Text('Nom A → Z'),
                  ),
                  PopupMenuItem(
                    value: ProductSort.nameDesc,
                    child: Text('Nom Z → A'),
                  ),
                  PopupMenuItem(
                    value: ProductSort.stockAsc,
                    child: Text('Stock croissant'),
                  ),
                  PopupMenuItem(
                    value: ProductSort.stockDesc,
                    child: Text('Stock décroissant'),
                  ),
                  PopupMenuItem(
                    value: ProductSort.priceAsc,
                    child: Text('Prix croissant'),
                  ),
                  PopupMenuItem(
                    value: ProductSort.priceDesc,
                    child: Text('Prix décroissant'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductListView extends StatelessWidget {
  const _ProductListView({
    required this.session,
    required this.canWrite,
  });

  final AuthSession session;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductListBloc, ProductListState>(
      builder: (context, state) {
        if (state.status == ProductListStatus.initial &&
            state.products.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        if (state.status == ProductListStatus.failure) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.errorMessage ?? 'Erreur'),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () => context
                        .read<ProductListBloc>()
                        .add(const ProductListLoadRequested()),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        }

        if (state.products.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async {
              context
                  .read<ProductListBloc>()
                  .add(const ProductListRefreshRequested());
              await context.read<ProductListBloc>().stream.firstWhere(
                    (s) => !s.isRefreshing,
                  );
            },
            child: EmptyListPlaceholder(
              embedded: true,
              icon: Icons.inventory_2_outlined,
              title: state.filters.lowStockOnly
                  ? 'Aucun produit en alerte'
                  : 'Aucun produit',
              subtitle: canWrite
                  ? 'Ajoutez votre premier produit avec le bouton +'
                  : null,
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            context
                .read<ProductListBloc>()
                .add(const ProductListRefreshRequested());
            await context.read<ProductListBloc>().stream.firstWhere(
                  (s) => !s.isRefreshing,
                );
          },
          child: ResponsiveBuilder(
            builder: (context, screenType) {
              final horizontal = Breakpoints.horizontalPadding(screenType);
              final bottomPadding = screenType.isTablet ? AppSpacing.lg : 100.0;

              if (screenType.isCompact) {
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    0,
                    horizontal,
                    bottomPadding,
                  ),
                  itemCount: state.products.length,
                  separatorBuilder: (_, index) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) =>
                      _buildProductCard(context, state.products[index]),
                );
              }

              final columns = Breakpoints.gridColumns(
                screenType,
                medium: 2,
                expanded: 2,
              );

              return GridView.builder(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  0,
                  horizontal,
                  bottomPadding,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisExtent: 88,
                ),
                itemCount: state.products.length,
                itemBuilder: (context, index) =>
                    _buildProductCard(context, state.products[index]),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildProductCard(BuildContext context, Product product) {
    final canProcure = PermissionGuard.can(
      session.user.permissions,
      Permission.procurementCreate,
    );

    return ProductCard(
      product: product,
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => ProductDetailPage(
              session: session,
              productId: product.id,
            ),
          ),
        );
        if (changed == true && context.mounted) {
          context
              .read<ProductListBloc>()
              .add(const ProductListLocalRefreshRequested());
        }
      },
      trailing: canProcure && product.isLowStock
          ? IconButton(
              tooltip: 'Commander ce produit',
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () {
                final deficit =
                    (product.alertThreshold - product.quantityInStock)
                        .clamp(1, product.alertThreshold);
                openPoFormPage(
                  context,
                  session,
                  prefill: PoFormPrefill(
                    productId: product.id,
                    productName: product.name,
                    suggestedQuantity: product.alertThreshold + deficit,
                    unitCost: product.priceBuy,
                  ),
                );
              },
            )
          : null,
    );
  }
}
