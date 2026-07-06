import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/auth_entities.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../core/responsive/screen_type.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/dashboard_entities.dart';
import '../bloc/dashboard_bloc.dart';
import '../widgets/kpi_card.dart';
import '../widgets/recent_sales_list.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
    required this.session,
    this.onLowStockTap,
    this.onNewSaleTap,
    this.onSalesHistoryTap,
    this.onDebtorsTap,
  });

  final AuthSession session;
  final VoidCallback? onLowStockTap;
  final VoidCallback? onNewSaleTap;
  final VoidCallback? onSalesHistoryTap;
  final VoidCallback? onDebtorsTap;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  void _showComingSoon(String module) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$module — bientôt disponible')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        return switch (state) {
          DashboardInitial() || DashboardLoading() => const Center(
              child: CircularProgressIndicator(),
            ),
          DashboardFailure(:final message) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: () => context
                          .read<DashboardBloc>()
                          .add(const DashboardRefreshRequested()),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            ),
          DashboardLoaded(:final data, :final isRefreshing) =>
            ResponsiveBuilder(
              builder: (context, screenType) {
                final horizontal = Breakpoints.horizontalPadding(screenType);
                return RefreshIndicator(
                  onRefresh: () async {
                    context
                        .read<DashboardBloc>()
                        .add(const DashboardRefreshRequested());
                    await context
                        .read<DashboardBloc>()
                        .stream
                        .firstWhere(
                          (s) => s is DashboardLoaded && !s.isRefreshing,
                        );
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      AppSpacing.sm,
                      horizontal,
                      screenType.isTablet ? AppSpacing.lg : AppSpacing.md,
                    ),
                    children: [
                      if (isRefreshing)
                        const Padding(
                          padding: EdgeInsets.only(bottom: AppSpacing.sm),
                          child: LinearProgressIndicator(),
                        ),
                      _GreetingHeader(
                        userName: widget.session.user.name,
                        date: data.date,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      RevenueHeroCard(
                        revenue: data.kpis.totalRevenue,
                        saleCount: data.kpis.saleCount,
                        onTap: widget.onSalesHistoryTap ??
                            () => _showComingSoon('Historique des ventes'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (data.financial != null) ...[
                        _FinancialSection(
                          financial: data.financial!,
                          screenType: screenType,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      Text(
                        'Indicateurs',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ResponsiveKpiGrid(
                        withSubtitle: true,
                        children: [
                          KpiCard(
                            label: 'Stock faible',
                            value: '${data.kpis.lowStockCount}',
                            subtitle: 'produits en alerte',
                            icon: Icons.inventory_2_outlined,
                            accentColor: data.kpis.lowStockCount > 0
                                ? AppColors.warning
                                : null,
                            onTap: widget.onLowStockTap ??
                                () => _showComingSoon('Produits en alerte'),
                          ),
                          KpiCard(
                            label: 'Dettes clients',
                            value: '${data.kpis.debtorCount}',
                            subtitle: data.financial != null
                                ? formatFcfa(data.financial!.totalDebt)
                                : 'débiteurs actifs',
                            icon: Icons.account_balance_wallet_outlined,
                            accentColor: data.kpis.debtorCount > 0
                                ? AppColors.danger
                                : null,
                            onTap: widget.onDebtorsTap ??
                                () => _showComingSoon('Liste des débiteurs'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      RecentSalesList(sales: data.recentSales),
                    ],
                  ),
                );
              },
            ),
        };
      },
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.userName,
    required this.date,
  });

  final String userName;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bonjour, $userName 👋',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 14,
              color: AppColors.onSurfaceMuted,
            ),
            const SizedBox(width: 6),
            Text(
              date,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FinancialSection extends StatelessWidget {
  const _FinancialSection({
    required this.financial,
    required this.screenType,
  });

  final DashboardFinancialKpis financial;
  final ScreenType screenType;

  @override
  Widget build(BuildContext context) {
    final encaisse = financial.totalCash + financial.totalMomo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Encaissements du jour',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        if (screenType.isTablet)
          ResponsiveKpiGrid(
            withSubtitle: true,
            crossAxisCount: screenType == ScreenType.expanded ? 3 : 2,
            children: [
              KpiCard(
                label: 'Encaissé',
                value: formatFcfa(encaisse),
                subtitle:
                    'Espèces ${formatFcfa(financial.totalCash)} · MoMo ${formatFcfa(financial.totalMomo)}',
                icon: Icons.savings_outlined,
              ),
              KpiCard(
                label: 'Crédit',
                value: formatFcfa(financial.totalCredit),
                subtitle: 'ventes à crédit',
                icon: Icons.credit_card_outlined,
              ),
              if (financial.profitAvailable && financial.estimatedProfit != null)
                KpiCard(
                  label: 'Bénéfice estimé',
                  value: formatFcfa(financial.estimatedProfit!),
                  icon: Icons.trending_up,
                  accentColor: AppColors.success,
                ),
            ],
          )
        else ...[
          Row(
            children: [
              Expanded(
                child: KpiCard(
                  label: 'Encaissé',
                  value: formatFcfa(encaisse),
                  subtitle:
                      'Espèces ${formatFcfa(financial.totalCash)} · MoMo ${formatFcfa(financial.totalMomo)}',
                  icon: Icons.savings_outlined,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: KpiCard(
                  label: 'Crédit',
                  value: formatFcfa(financial.totalCredit),
                  subtitle: 'ventes à crédit',
                  icon: Icons.credit_card_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          if (financial.profitAvailable && financial.estimatedProfit != null)
            KpiCard(
              label: 'Bénéfice estimé',
              value: formatFcfa(financial.estimatedProfit!),
              icon: Icons.trending_up,
              accentColor: AppColors.success,
            )
          else if (financial.profitWarning != null)
            Card(
              color: Theme.of(context).colorScheme.tertiaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color:
                          Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                      child: Text(
                        financial.profitWarning!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (financial.totalExpenses > 0) ...[
            const SizedBox(height: AppSpacing.sm + 4),
            KpiCard(
              label: 'Dépenses du jour',
              value: formatFcfa(financial.totalExpenses),
              icon: Icons.receipt_long_outlined,
              accentColor: AppColors.warning,
            ),
          ],
          if (financial.netProfit != null) ...[
            const SizedBox(height: AppSpacing.sm + 4),
            KpiCard(
              label: 'Bénéfice net',
              value: formatFcfa(financial.netProfit!),
              icon: Icons.account_balance_wallet_outlined,
              accentColor: financial.netProfit! >= 0
                  ? AppColors.success
                  : Theme.of(context).colorScheme.error,
            ),
          ],
        ],
      ],
    );
  }
}
