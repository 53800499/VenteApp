import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../dashboard/presentation/bloc/dashboard_bloc.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../domain/entities/sale_entities.dart';
import '../bloc/sale_list_bloc.dart';
import 'new_sale_page.dart';
import 'sale_detail_page.dart';
import 'quick_sale_page.dart';

class SaleListPage extends StatefulWidget {
  const SaleListPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<SaleListPage> createState() => _SaleListPageState();
}

class _SaleListPageState extends State<SaleListPage> {
  final _searchController = TextEditingController();

  bool get _canCreate => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.salesCreate,
      );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          BlocBuilder<SaleListBloc, SaleListState>(
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
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Rechercher par n° de reçu…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    context.read<SaleListBloc>().add(
                                          const SaleListSearchChanged(''),
                                        );
                                    setState(() {});
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          setState(() {});
                          context
                              .read<SaleListBloc>()
                              .add(SaleListSearchChanged(value));
                        },
                      ),
                    );
                  },
                ),
                Expanded(
                  child: BlocBuilder<SaleListBloc, SaleListState>(
                    builder: (context, state) {
                      return switch (state.status) {
                        SaleListStatus.initial ||
                        SaleListStatus.loading when state.sales.isEmpty =>
                          const Center(child: CircularProgressIndicator()),
                        SaleListStatus.failure when state.sales.isEmpty =>
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    state.errorMessage ??
                                        'Erreur de chargement',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  FilledButton(
                                    onPressed: () => context
                                        .read<SaleListBloc>()
                                        .add(const SaleListLoadRequested()),
                                    child: const Text('Réessayer'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        SaleListStatus.loaded ||
                        SaleListStatus.loading ||
                        SaleListStatus.failure =>
                          RefreshIndicator(
                            onRefresh: () async {
                              context
                                  .read<SaleListBloc>()
                                  .add(const SaleListRefreshRequested());
                              await context
                                  .read<SaleListBloc>()
                                  .stream
                                  .firstWhere(
                                    (s) =>
                                        s.status == SaleListStatus.loaded &&
                                        !s.isRefreshing,
                                  );
                            },
                            child: state.sales.isEmpty
                                ? EmptyListPlaceholder(
                                    embedded: true,
                                    icon: Icons.receipt_long_outlined,
                                    title: 'Aucune vente enregistrée',
                                  )
                                : ListView.separated(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.md,
                                      vertical: AppSpacing.sm,
                                    ),
                                    itemCount: state.sales.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: AppSpacing.sm),
                                    itemBuilder: (context, index) {
                                      final sale = state.sales[index];
                                      return _SaleListTile(
                                        sale: sale,
                                        onTap: () => _openDetail(
                                          context,
                                          sale.id,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        SaleListStatus.initial =>
                          const Center(child: CircularProgressIndicator()),
                      };
                    },
                  ),
                ),
              ],
            ),
            floatingActionButton: _canCreate
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FloatingActionButton.extended(
                        heroTag: 'quick_sale',
                        onPressed: () => _openQuickSale(context),
                        icon: const Icon(Icons.flash_on_outlined),
                        label: const Text('Rapide'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      FloatingActionButton.extended(
                        heroTag: 'new_sale',
                        onPressed: () => _openNewSale(context),
                        icon: const Icon(Icons.add_shopping_cart_outlined),
                        label: const Text('Nouvelle vente'),
                      ),
                    ],
                  )
                : null,
    );
  }

  Future<void> _openNewSale(BuildContext context) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NewSalePage(session: widget.session),
      ),
    );
    if (created == true && context.mounted) {
      context.read<SaleListBloc>().add(const SaleListLocalRefreshRequested());
      context.read<DashboardBloc>().add(const DashboardRefreshRequested());
    }
  }

  Future<void> _openQuickSale(BuildContext context) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => QuickSalePage(session: widget.session),
      ),
    );
    if (created == true && context.mounted) {
      context.read<SaleListBloc>().add(const SaleListLocalRefreshRequested());
      context.read<DashboardBloc>().add(const DashboardRefreshRequested());
    }
  }

  void _openDetail(BuildContext context, int saleId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SaleDetailPage(
          session: widget.session,
          saleId: saleId,
        ),
      ),
    );
  }
}

class _SaleListTile extends StatelessWidget {
  const _SaleListTile({required this.sale, required this.onTap});

  final SaleListRow sale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.fromMillisecondsSinceEpoch(sale.createdAt);
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final isCancelled = sale.status == SaleStatus.cancelled;
    final isCompact = context.isCompactScreen;

    final titleWidget = Text(
      sale.receiptNumber ?? 'Vente #${sale.id}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        decoration: isCancelled ? TextDecoration.lineThrough : null,
      ),
    );

    final detailsText = [
      time,
      if (sale.customerName != null) sale.customerName!,
      if (isCancelled) 'Annulée',
    ].join(' · ');

    final priceWidget = Text(
      formatFcfa(sale.totalAmount),
      style: (isCompact
              ? Theme.of(context).textTheme.titleSmall
              : Theme.of(context).textTheme.titleMedium)
          ?.copyWith(
        color: isCancelled
            ? Theme.of(context).colorScheme.outline
            : Theme.of(context).colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
    );

    if (isCompact) {
      return Card(
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: isCancelled
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              sale.saleType == SaleType.quick
                  ? Icons.flash_on
                  : Icons.receipt_long_outlined,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          title: titleWidget,
          subtitle: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  detailsText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              priceWidget,
            ],
          ),
        ),
      );
    }

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: isCancelled
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            sale.saleType == SaleType.quick
                ? Icons.flash_on
                : Icons.receipt_long_outlined,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        title: titleWidget,
        subtitle: Text(detailsText),
        trailing: priceWidget,
      ),
    );
  }
}
