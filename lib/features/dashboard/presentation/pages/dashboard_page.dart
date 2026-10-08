import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/auth_entities.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/breakpoints.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../core/responsive/screen_type.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/components/skeleton_loaders.dart';
import '../../domain/entities/dashboard_entities.dart';
import '../bloc/dashboard_bloc.dart';
import '../widgets/desktop_dashboard_view.dart';
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
    this.onFxExchangeTap,
  });

  final AuthSession session;
  final VoidCallback? onLowStockTap;
  final VoidCallback? onNewSaleTap;
  final VoidCallback? onSalesHistoryTap;
  final VoidCallback? onDebtorsTap;
  final VoidCallback? onFxExchangeTap;

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
          DashboardInitial() || DashboardLoading() => const DashboardSkeleton(),
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
                final isDesktop = Breakpoints.isDesktopWidth(
                  MediaQuery.sizeOf(context).width,
                );

                if (isDesktop) {
                  return DesktopDashboardView(
                    session: widget.session,
                    data: data,
                    isRefreshing: isRefreshing,
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
                    onLowStockTap: widget.onLowStockTap,
                    onNewSaleTap: widget.onNewSaleTap,
                    onSalesHistoryTap: widget.onSalesHistoryTap,
                    onDebtorsTap: widget.onDebtorsTap,
                    onFxExchangeTap: widget.onFxExchangeTap,
                  );
                }

                // --- RENDU MOBILE STRICTEMENT IDENTIQUE ET PRÉSERVÉ ---
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
                        shopName: widget.session.shop.name,
                        date: data.date.isNotEmpty
                            ? data.date
                            : AppDateFormatter.formatDateFull(DateTime.now()),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      RevenueHeroCard(
                        revenue: data.kpis.totalRevenue,
                        saleCount: data.kpis.saleCount,
                        onNewSale: widget.onNewSaleTap,
                        onTap: widget.onSalesHistoryTap ??
                            () => _showComingSoon('Historique des ventes'),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _QuickActionsHub(
                        onNewSale: widget.onNewSaleTap,
                        onDebtors: widget.onDebtorsTap,
                        onLowStock: widget.onLowStockTap,
                        onFxExchange: widget.onFxExchangeTap,
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
    required this.shopName,
    required this.date,
  });

  final String userName;
  final String shopName;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bonjour, $userName 👋',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 2,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        size: 15,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          shopName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '•  $date',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const _NetworkStatusBadge(),
      ],
    );
  }
}

class _NetworkStatusBadge extends StatefulWidget {
  const _NetworkStatusBadge();

  @override
  State<_NetworkStatusBadge> createState() => _NetworkStatusBadgeState();
}

class _NetworkStatusBadgeState extends State<_NetworkStatusBadge> {
  bool? _isOnline;

  @override
  void initState() {
    super.initState();
    _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = !results.every((r) => r == ConnectivityResult.none);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectivityResult>>(
      stream: Connectivity().onConnectivityChanged,
      builder: (context, snapshot) {
        final bool isOnline;
        if (snapshot.hasData) {
          isOnline = !snapshot.data!.every((r) => r == ConnectivityResult.none);
        } else {
          isOnline = _isOnline ?? true;
        }

        final color = isOnline ? Colors.green : Colors.amber.shade800;
        final bg = isOnline
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.amber.withValues(alpha: 0.15);
        final label = isOnline ? 'En ligne' : 'Hors-ligne';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.circle, size: 8, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickActionsHub extends StatelessWidget {
  const _QuickActionsHub({
    this.onNewSale,
    this.onDebtors,
    this.onLowStock,
    this.onFxExchange,
  });

  final VoidCallback? onNewSale;
  final VoidCallback? onDebtors;
  final VoidCallback? onLowStock;
  final VoidCallback? onFxExchange;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Raccourcis rapides',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _QuickActionChip(
                label: 'Nouvelle Vente',
                icon: Icons.add_shopping_cart_rounded,
                color: const Color(0xFF10B981),
                onTap: onNewSale,
              ),
              const SizedBox(width: AppSpacing.sm),
              _QuickActionChip(
                label: 'Dettes & Relances',
                icon: Icons.account_balance_wallet_outlined,
                color: const Color(0xFFF59E0B),
                onTap: onDebtors,
              ),
              const SizedBox(width: AppSpacing.sm),
              _QuickActionChip(
                label: 'Alertes Stock',
                icon: Icons.inventory_2_outlined,
                color: const Color(0xFF6366F1),
                onTap: onLowStock,
              ),
              if (onFxExchange != null) ...[
                const SizedBox(width: AppSpacing.sm),
                _QuickActionChip(
                  label: 'Bureau de Change',
                  icon: Icons.currency_exchange_rounded,
                  color: const Color(0xFF06B6D4),
                  onTap: onFxExchange,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
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
