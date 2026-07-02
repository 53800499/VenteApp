import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/customer_entities.dart';
import '../../domain/repositories/customer_repository.dart';
import '../bloc/customer_list_bloc.dart';
import 'customer_detail_page.dart';
import 'customer_form_page.dart';

class CustomerListPage extends StatefulWidget {
  const CustomerListPage({
    super.key,
    required this.session,
    this.initialDebtorsOnly = false,
  });

  final AuthSession session;
  final bool initialDebtorsOnly;

  @override
  State<CustomerListPage> createState() => _CustomerListPageState();
}

class _CustomerListPageState extends State<CustomerListPage> {
  final _searchController = TextEditingController();

  bool get _canWrite => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.customersWrite,
      );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CustomerListBloc(
        listCustomers: sl(),
        listDebtors: sl(),
        repository: sl<CustomerRepository>(),
        syncPolicy: sl(),
        session: widget.session,
        initialFilters: CustomerListFilters(
          hasDebtOnly: widget.initialDebtorsOnly,
        ),
      )..add(
          widget.initialDebtorsOnly
              ? const CustomerListShowDebtorsToggled(true)
              : const CustomerListLoadRequested(),
        ),
      child: Builder(
        builder: (context) {
          return Scaffold(
            body: Column(
              children: [
                BlocBuilder<CustomerListBloc, CustomerListState>(
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Rechercher un client…',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        context.read<CustomerListBloc>().add(
                                              const CustomerListSearchChanged(
                                                '',
                                              ),
                                            );
                                        setState(() {});
                                      },
                                    )
                                  : null,
                            ),
                            onChanged: (value) {
                              setState(() {});
                              context.read<CustomerListBloc>().add(
                                    CustomerListSearchChanged(value),
                                  );
                            },
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          const _FilterBar(),
                        ],
                      ),
                    );
                  },
                ),
                Expanded(
                  child: BlocBuilder<CustomerListBloc, CustomerListState>(
                    builder: (context, state) {
                      return switch (state.status) {
                        CustomerListStatus.initial ||
                        CustomerListStatus.loading =>
                          const Center(child: CircularProgressIndicator()),
                        CustomerListStatus.failure => Center(
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
                                        .read<CustomerListBloc>()
                                        .add(const CustomerListLoadRequested()),
                                    child: const Text('Réessayer'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        CustomerListStatus.ready =>
                          RefreshIndicator(
                            onRefresh: () async {
                              context.read<CustomerListBloc>().add(
                                    const CustomerListRefreshRequested(),
                                  );
                              await context
                                  .read<CustomerListBloc>()
                                  .stream
                                  .firstWhere(
                                    (s) =>
                                        s.status == CustomerListStatus.ready &&
                                        !s.isRefreshing,
                                  );
                            },
                            child: _CustomerListBody(
                              state: state,
                              onCustomerTap: (id) => _openDetail(context, id),
                            ),
                          ),
                      };
                    },
                  ),
                ),
              ],
            ),
            floatingActionButton: _canWrite
                ? FloatingActionButton.extended(
                    heroTag: 'new_customer',
                    onPressed: () => _openCreate(context),
                    icon: const Icon(Icons.person_add_outlined),
                    label: const Text('Nouveau client'),
                  )
                : null,
          );
        },
      ),
    );
  }

  Future<void> _openCreate(BuildContext context) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CustomerFormPage(session: widget.session),
      ),
    );
    if (created == true && context.mounted) {
      context.read<CustomerListBloc>().add(const CustomerListRefreshRequested());
    }
  }

  Future<void> _openDetail(BuildContext context, int customerId) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CustomerDetailPage(
          session: widget.session,
          customerId: customerId,
        ),
      ),
    );
    if (updated == true && context.mounted) {
      context.read<CustomerListBloc>().add(const CustomerListRefreshRequested());
    }
  }
}

class _CustomerListBody extends StatelessWidget {
  const _CustomerListBody({
    required this.state,
    required this.onCustomerTap,
  });

  final CustomerListState state;
  final void Function(int customerId) onCustomerTap;

  @override
  Widget build(BuildContext context) {
    if (state.customers.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(
            child: Text(
              'Aucun client trouvé.\nCréez votre premier client.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    final showBanner =
        state.debtorsOverview != null && state.showDebtorsOverview;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: state.customers.length + (showBanner ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (showBanner && index == 0) {
          return _DebtorsBanner(overview: state.debtorsOverview!);
        }
        final customerIndex = showBanner ? index - 1 : index;
        final customer = state.customers[customerIndex];
        return _CustomerListTile(
          customer: customer,
          onTap: () => onCustomerTap(customer.id),
        );
      },
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomerListBloc, CustomerListState>(
      builder: (context, state) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('Débiteurs'),
                selected: state.filters.hasDebtOnly,
                onSelected: (v) => context.read<CustomerListBloc>().add(
                      CustomerListDebtFilterToggled(v),
                    ),
              ),
              const SizedBox(width: AppSpacing.sm),
              PopupMenuButton<CustomerSort>(
                tooltip: 'Trier',
                onSelected: (sort) => context.read<CustomerListBloc>().add(
                      CustomerListSortChanged(sort),
                    ),
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: CustomerSort.name,
                    child: Text('Nom'),
                  ),
                  PopupMenuItem(
                    value: CustomerSort.debt,
                    child: Text('Dette'),
                  ),
                  PopupMenuItem(
                    value: CustomerSort.lastActivity,
                    child: Text('Dernière activité'),
                  ),
                ],
                child: Chip(
                  avatar: const Icon(Icons.sort, size: 18),
                  label: Text(_sortLabel(state.filters.sort)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _sortLabel(CustomerSort sort) => switch (sort) {
        CustomerSort.name => 'Tri : nom',
        CustomerSort.debt => 'Tri : dette',
        CustomerSort.lastActivity => 'Tri : activité',
      };
}

class _DebtorsBanner extends StatelessWidget {
  const _DebtorsBanner({required this.overview});

  final DebtorsOverview overview;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.danger.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${overview.debtorCount} débiteur(s)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'Total dû : ${formatFcfa(overview.totalDebt)}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerListTile extends StatelessWidget {
  const _CustomerListTile({
    required this.customer,
    required this.onTap,
  });

  final Customer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initial =
        customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?';
    final hasDebt = customer.hasDebt;

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: hasDebt
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            initial,
            style: TextStyle(
              color: hasDebt
                  ? Theme.of(context).colorScheme.onErrorContainer
                  : Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(customer.name),
        subtitle: Text(
          [
            if (customer.isShared) 'Partagé',
            if (customer.phone != null && customer.phone!.isNotEmpty)
              customer.phone!,
            if (customer.purchaseCount > 0)
              '${customer.purchaseCount} achat(s)',
          ].join(' · '),
        ),
        trailing: hasDebt
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatFcfa(customer.balanceDue),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: customer.isCriticalDebt
                              ? Theme.of(context).colorScheme.error
                              : AppColors.warning,
                        ),
                  ),
                  if (customer.isCriticalDebt)
                    Text(
                      'Critique',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                ],
              )
            : Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.outline,
              ),
      ),
    );
  }
}
