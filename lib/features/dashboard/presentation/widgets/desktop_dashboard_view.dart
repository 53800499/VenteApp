import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/dashboard_entities.dart';

/// Vue Dashboard adaptée aux écrans Desktop (Windows / Web / grands écrans).
///
/// Propose une ergonomie de type ERP :
/// - En-tête avec statut réseau et barre d'actions rapides (Nouvelle vente F2, alertes, relances).
/// - Grille Bento de 4 indicateurs clés (CA, Encaissé réel, Créances, Alertes stock).
/// - Synthèse financière avancée (crédits, dépenses, rentabilité).
/// - Grille à double colonne : Transactions récentes (gauche) et Répartition des encaissements + Bureau de commande (droite).
class DesktopDashboardView extends StatelessWidget {
  const DesktopDashboardView({
    super.key,
    required this.session,
    required this.data,
    required this.isRefreshing,
    required this.onRefresh,
    this.onLowStockTap,
    this.onNewSaleTap,
    this.onSalesHistoryTap,
    this.onDebtorsTap,
    this.onFxExchangeTap,
  });

  final AuthSession session;
  final DashboardData data;
  final bool isRefreshing;
  final Future<void> Function() onRefresh;
  final VoidCallback? onLowStockTap;
  final VoidCallback? onNewSaleTap;
  final VoidCallback? onSalesHistoryTap;
  final VoidCallback? onDebtorsTap;
  final VoidCallback? onFxExchangeTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final isWideDesktop = availableWidth >= 1100;

        return RefreshIndicator(
          onRefresh: onRefresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isRefreshing)
                  const Padding(
                    padding: EdgeInsets.only(bottom: AppSpacing.md),
                    child: LinearProgressIndicator(),
                  ),

                // 1. En-tête & Barre de commande Desktop
                _DesktopHeader(
                  session: session,
                  data: data,
                  isRefreshing: isRefreshing,
                  onRefresh: onRefresh,
                  onNewSale: onNewSaleTap,
                  onDebtors: onDebtorsTap,
                  onLowStock: onLowStockTap,
                  onFxExchange: onFxExchangeTap,
                ),

                const SizedBox(height: AppSpacing.lg),

                // 2. Grille Bento des 4 KPIs principaux
                _DesktopKpiGrid(
                  data: data,
                  isWide: isWideDesktop,
                  onSalesTap: onSalesHistoryTap,
                  onDebtorsTap: onDebtorsTap,
                  onLowStockTap: onLowStockTap,
                ),

                // 3. Synthèse financière du jour (si disponible)
                if (data.financial != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  _DesktopFinancialSummaryBar(financial: data.financial!),
                ],

                const SizedBox(height: AppSpacing.lg),

                // 4. Double colonne : Transactions récentes (gauche) & Panneau opérationnel (droite)
                if (availableWidth >= 1000)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Transactions récentes (62%)
                      Expanded(
                        flex: 62,
                        child: _DesktopRecentSalesCard(
                          sales: data.recentSales,
                          onViewAll: onSalesHistoryTap,
                          onNewSale: onNewSaleTap,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      // Panneau latéral : Répartition des encaissements + Actions (38%)
                      Expanded(
                        flex: 38,
                        child: Column(
                          children: [
                            _DesktopPaymentBreakdownCard(
                              financial: data.financial,
                              totalRevenue: data.kpis.totalRevenue,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _DesktopActionCenterCard(
                              kpis: data.kpis,
                              onNewSale: onNewSaleTap,
                              onDebtors: onDebtorsTap,
                              onLowStock: onLowStockTap,
                              onFxExchange: onFxExchangeTap,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  // En dessous de 1000px : empilement vertical avec cartes adaptées
                  _DesktopRecentSalesCard(
                    sales: data.recentSales,
                    onViewAll: onSalesHistoryTap,
                    onNewSale: onNewSaleTap,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _DesktopPaymentBreakdownCard(
                    financial: data.financial,
                    totalRevenue: data.kpis.totalRevenue,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _DesktopActionCenterCard(
                    kpis: data.kpis,
                    onNewSale: onNewSaleTap,
                    onDebtors: onDebtorsTap,
                    onLowStock: onLowStockTap,
                    onFxExchange: onFxExchangeTap,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 1. En-tête & Barre de commande Desktop
// ---------------------------------------------------------------------------

class _DesktopHeader extends StatelessWidget {
  const _DesktopHeader({
    required this.session,
    required this.data,
    required this.isRefreshing,
    required this.onRefresh,
    this.onNewSale,
    this.onDebtors,
    this.onLowStock,
    this.onFxExchange,
  });

  final AuthSession session;
  final DashboardData data;
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final VoidCallback? onNewSale;
  final VoidCallback? onDebtors;
  final VoidCallback? onLowStock;
  final VoidCallback? onFxExchange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final formattedDate = data.date.isNotEmpty
        ? data.date
        : AppDateFormatter.formatDateFull(DateTime.now());

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, headerConstraints) {
        final isWide = headerConstraints.maxWidth >= 1150;

        final greetingBlock = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              children: [
                Text(
                  'Bonjour, ${session.user.name} 👋',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const _DesktopNetworkStatusBadge(),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.storefront_rounded,
                      size: 16,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      session.shop.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: scheme.primary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Text('•', style: TextStyle(color: scheme.outline)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: AppColors.onSurfaceMuted,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        formattedDate,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );

        final actionsBlock = Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            // Bouton actualiser
            IconButton(
              onPressed: isRefreshing ? null : onRefresh,
              tooltip: 'Actualiser le tableau de bord',
              icon: isRefreshing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 20),
            ),

            // Raccourci Dettes
            if (onDebtors != null)
              OutlinedButton.icon(
                onPressed: onDebtors,
                icon: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 16,
                ),
                label: Text(
                  data.kpis.debtorCount > 0
                      ? 'Dettes (${data.kpis.debtorCount})'
                      : 'Dettes',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: data.kpis.debtorCount > 0
                      ? AppColors.danger
                      : scheme.onSurface,
                  side: BorderSide(
                    color: data.kpis.debtorCount > 0
                        ? AppColors.danger.withValues(alpha: 0.4)
                        : scheme.outlineVariant,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),

            // Raccourci Alertes Stock
            if (onLowStock != null)
              OutlinedButton.icon(
                onPressed: onLowStock,
                icon: const Icon(Icons.inventory_2_outlined, size: 16),
                label: Text(
                  data.kpis.lowStockCount > 0
                      ? 'Stock faible (${data.kpis.lowStockCount})'
                      : 'Stock',
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: data.kpis.lowStockCount > 0
                      ? AppColors.warning
                      : scheme.onSurface,
                  side: BorderSide(
                    color: data.kpis.lowStockCount > 0
                        ? AppColors.warning.withValues(alpha: 0.5)
                        : scheme.outlineVariant,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),

            // Raccourci FX
            if (onFxExchange != null)
              OutlinedButton.icon(
                onPressed: onFxExchange,
                icon: const Icon(Icons.currency_exchange_rounded, size: 16),
                label: const Text('Change'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
              ),

            // CTA Principal : Nouvelle Vente
            if (onNewSale != null)
              FilledButton.icon(
                onPressed: onNewSale,
                icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                label: const Text(
                  'Nouvelle Vente (F2)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
          ],
        );

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: greetingBlock),
              const SizedBox(width: AppSpacing.md),
              actionsBlock,
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            greetingBlock,
            const SizedBox(height: AppSpacing.md),
            actionsBlock,
          ],
        );
      },
    ),
  );
}
}

// ---------------------------------------------------------------------------
// 2. Grille Bento des 4 KPIs principaux Desktop
// ---------------------------------------------------------------------------

class _DesktopKpiGrid extends StatelessWidget {
  const _DesktopKpiGrid({
    required this.data,
    required this.isWide,
    this.onSalesTap,
    this.onDebtorsTap,
    this.onLowStockTap,
  });

  final DashboardData data;
  final bool isWide;
  final VoidCallback? onSalesTap;
  final VoidCallback? onDebtorsTap;
  final VoidCallback? onLowStockTap;

  @override
  Widget build(BuildContext context) {
    final financial = data.financial;
    final encaisse = financial != null
        ? (financial.totalCash + financial.totalMomo)
        : data.kpis.totalRevenue;

    final cards = [
      // 1. Chiffre d'Affaires du jour
      _DesktopKpiTile(
        title: 'Chiffre d\'affaires',
        value: formatFcfa(data.kpis.totalRevenue),
        subtitle: data.kpis.saleCount == 1
            ? '1 vente effectuée'
            : '${data.kpis.saleCount} ventes effectuées',
        icon: Icons.insights_rounded,
        accentColor: const Color(0xFF4F46E5), // Indigo
        onTap: onSalesTap,
        tag: 'Aujourd\'hui',
      ),

      // 2. Encaissements réels
      _DesktopKpiTile(
        title: 'Total Encaissé',
        value: formatFcfa(encaisse),
        subtitle: financial != null
            ? 'Espèces : ${formatFcfa(financial.totalCash)} · MoMo : ${formatFcfa(financial.totalMomo)}'
            : 'Règlement immédiat',
        icon: Icons.savings_outlined,
        accentColor: const Color(0xFF10B981), // Emerald
        tag: 'Cash & MoMo',
      ),

      // 3. Créances & Dettes clients
      _DesktopKpiTile(
        title: 'Créances clients',
        value: financial != null ? formatFcfa(financial.totalDebt) : '0 FCFA',
        subtitle: data.kpis.debtorCount == 1
            ? '1 client avec solde débiteur'
            : '${data.kpis.debtorCount} clients avec solde dû',
        icon: Icons.account_balance_wallet_outlined,
        accentColor: data.kpis.debtorCount > 0
            ? const Color(0xFFEF4444) // Red
            : const Color(0xFF6366F1),
        onTap: onDebtorsTap,
        tag: data.kpis.debtorCount > 0 ? 'À relancer' : 'À jour',
      ),

      // 4. Alertes de stock
      _DesktopKpiTile(
        title: 'Alertes stock',
        value: '${data.kpis.lowStockCount}',
        subtitle: data.kpis.lowStockCount > 0
            ? 'Produits sous le seuil d\'alerte'
            : 'Aucun produit en rupture',
        icon: Icons.inventory_2_outlined,
        accentColor: data.kpis.lowStockCount > 0
            ? const Color(0xFFF59E0B) // Amber
            : const Color(0xFF10B981),
        onTap: onLowStockTap,
        tag: data.kpis.lowStockCount > 0 ? 'Action requise' : 'Optimal',
      ),
    ];

    if (isWide) {
      return Row(
        children: cards
            .map(
              (card) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: card,
                ),
              ),
            )
            .toList(),
      );
    }

    // 2 x 2 pour écrans desktop moyens
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(child: cards[2]),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: cards[3]),
          ],
        ),
      ],
    );
  }
}

class _DesktopKpiTile extends StatelessWidget {
  const _DesktopKpiTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.onTap,
    this.tag,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;
  final String? tag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, size: 20, color: accentColor),
                  ),
                  if (tag != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tag!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Synthèse financière avancée du jour (Desktop)
// ---------------------------------------------------------------------------

class _DesktopFinancialSummaryBar extends StatelessWidget {
  const _DesktopFinancialSummaryBar({required this.financial});

  final DashboardFinancialKpis financial;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasExpenses = financial.totalExpenses > 0;
    final hasProfit =
        financial.profitAvailable && financial.estimatedProfit != null;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_rounded,
                size: 20,
                color: scheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Indicateurs du jour :',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.lg),
          _MetricPill(
            label: 'Ventes à crédit',
            value: formatFcfa(financial.totalCredit),
            color: const Color(0xFFF59E0B),
          ),
          if (hasExpenses) ...[
            const SizedBox(width: AppSpacing.md),
            _MetricPill(
              label: 'Dépenses',
              value: formatFcfa(financial.totalExpenses),
              color: const Color(0xFFEF4444),
            ),
          ],
          if (hasProfit) ...[
            const SizedBox(width: AppSpacing.md),
            _MetricPill(
              label: 'Bénéfice estimé',
              value: formatFcfa(financial.estimatedProfit!),
              color: const Color(0xFF10B981),
            ),
          ],
          if (financial.netProfit != null) ...[
            const SizedBox(width: AppSpacing.md),
            _MetricPill(
              label: 'Bénéfice net',
              value: formatFcfa(financial.netProfit!),
              color: financial.netProfit! >= 0
                  ? const Color(0xFF10B981)
                  : const Color(0xFFEF4444),
            ),
          ],
          if (financial.profitWarning != null)
            Tooltip(
              message: financial.profitWarning!,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline, size: 16, color: scheme.error),
                  const SizedBox(width: 4),
                  Text(
                    'Prix de revient partiel',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label : ',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.onSurfaceMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. Tableau des transactions récentes (Desktop)
// ---------------------------------------------------------------------------

class _DesktopRecentSalesCard extends StatelessWidget {
  const _DesktopRecentSalesCard({
    required this.sales,
    this.onViewAll,
    this.onNewSale,
  });

  final List<DashboardRecentSale> sales;
  final VoidCallback? onViewAll;
  final VoidCallback? onNewSale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête de la carte
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        size: 20,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dernières ventes du jour',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          sales.isEmpty
                              ? 'Aucune transaction enregistrée'
                              : '${sales.length} ventes récentes',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (onViewAll != null)
                  TextButton.icon(
                    onPressed: onViewAll,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Voir tout l\'historique'),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Liste des ventes ou État à vide
          if (sales.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        size: 40,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Aucune vente aujourd\'hui',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Les tickets et encaissements du jour s\'afficheront ici en temps réel.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (onNewSale != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      FilledButton.icon(
                        onPressed: onNewSale,
                        icon: const Icon(Icons.add_shopping_cart, size: 16),
                        label: const Text('Enregistrer une vente'),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else ...[
            // En-tête des colonnes du tableau
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              color: scheme.surfaceContainerLow,
              child: const Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      'Heure',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 90,
                    child: Text(
                      'Réf',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Client',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 100,
                    child: Text(
                      'Règlement',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 130,
                    child: Text(
                      'Montant',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Lignes de transactions
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sales.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final sale = sales[index];
                return _DesktopSaleTableRow(sale: sale, onTap: onViewAll);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _DesktopSaleTableRow extends StatelessWidget {
  const _DesktopSaleTableRow({
    required this.sale,
    this.onTap,
  });

  final DashboardRecentSale sale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final timeStr = _formatTime(sale.createdAt);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            // Heure
            SizedBox(
              width: 80,
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 13,
                    color: AppColors.onSurfaceMuted,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Référence
            SizedBox(
              width: 90,
              child: Text(
                '#${sale.id}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ),

            // Client
            Expanded(
              child: Text(
                sale.customerName?.isNotEmpty == true
                    ? sale.customerName!
                    : 'Client comptant',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: sale.customerName?.isNotEmpty == true
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: sale.customerName?.isNotEmpty == true
                      ? scheme.onSurface
                      : AppColors.onSurfaceMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Mode de règlement
            SizedBox(
              width: 100,
              child: _PaymentModeBadge(mode: sale.paymentMode),
            ),

            // Montant total
            SizedBox(
              width: 130,
              child: Text(
                formatFcfa(sale.totalAmount),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTime(int timestampMs) {
    final time = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _PaymentModeBadge extends StatelessWidget {
  const _PaymentModeBadge({required this.mode});

  final String mode;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (mode.toLowerCase()) {
      'momo' => ('MoMo', const Color(0xFF1565C0)),
      'credit' => ('Crédit', const Color(0xFFD97706)),
      'mixed' => ('Mixte', const Color(0xFF7C3AED)),
      _ => ('Espèces', const Color(0xFF059669)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 5. Répartition des règlements & Centre de commande (Panneau latéral)
// ---------------------------------------------------------------------------

class _DesktopPaymentBreakdownCard extends StatelessWidget {
  const _DesktopPaymentBreakdownCard({
    required this.financial,
    required this.totalRevenue,
  });

  final DashboardFinancialKpis? financial;
  final int totalRevenue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final cash = financial?.totalCash ?? 0;
    final momo = financial?.totalMomo ?? 0;
    final credit = financial?.totalCredit ?? 0;
    final total = cash + momo + credit;

    final cashPercent = total > 0 ? (cash / total) : 0.0;
    final momoPercent = total > 0 ? (momo / total) : 0.0;
    final creditPercent = total > 0 ? (credit / total) : 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart_outline_rounded,
                size: 20,
                color: scheme.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Répartition des encaissements',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Barre horizontale proportionnelle
          if (total > 0) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    if (cashPercent > 0)
                      Expanded(
                        flex: (cashPercent * 100).round().clamp(1, 100),
                        child: Container(color: const Color(0xFF10B981)),
                      ),
                    if (momoPercent > 0)
                      Expanded(
                        flex: (momoPercent * 100).round().clamp(1, 100),
                        child: Container(color: const Color(0xFF1565C0)),
                      ),
                    if (creditPercent > 0)
                      Expanded(
                        flex: (creditPercent * 100).round().clamp(1, 100),
                        child: Container(color: const Color(0xFFF59E0B)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          _PaymentRow(
            label: 'Espèces',
            amount: cash,
            percent: (cashPercent * 100).toStringAsFixed(0),
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: AppSpacing.xs),
          _PaymentRow(
            label: 'Mobile Money',
            amount: momo,
            percent: (momoPercent * 100).toStringAsFixed(0),
            color: const Color(0xFF1565C0),
          ),
          const SizedBox(height: AppSpacing.xs),
          _PaymentRow(
            label: 'Ventes à crédit',
            amount: credit,
            percent: (creditPercent * 100).toStringAsFixed(0),
            color: const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.label,
    required this.amount,
    required this.percent,
    required this.color,
  });

  final String label;
  final int amount;
  final String percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          '$percent%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.onSurfaceMuted,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          formatFcfa(amount),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _DesktopActionCenterCard extends StatelessWidget {
  const _DesktopActionCenterCard({
    required this.kpis,
    this.onNewSale,
    this.onDebtors,
    this.onLowStock,
    this.onFxExchange,
  });

  final DashboardKpis kpis;
  final VoidCallback? onNewSale;
  final VoidCallback? onDebtors;
  final VoidCallback? onLowStock;
  final VoidCallback? onFxExchange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flash_on_rounded,
                size: 20,
                color: const Color(0xFFF59E0B),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Actions & Raccourcis caisse',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Action Vente
          _DesktopActionTile(
            title: 'Nouvelle vente de caisse',
            subtitle: 'Encaisser un client (Touche F2)',
            icon: Icons.point_of_sale_rounded,
            color: const Color(0xFF10B981),
            onTap: onNewSale,
          ),

          const SizedBox(height: AppSpacing.sm),

          // Action Relance Débiteurs
          _DesktopActionTile(
            title: 'Recouvrement créances',
            subtitle: kpis.debtorCount > 0
                ? '${kpis.debtorCount} client(s) à relancer'
                : 'Consulter l\'état des créances',
            icon: Icons.account_balance_wallet_outlined,
            color: kpis.debtorCount > 0
                ? const Color(0xFFEF4444)
                : const Color(0xFF6366F1),
            onTap: onDebtors,
          ),

          const SizedBox(height: AppSpacing.sm),

          // Action Réapprovisionnement
          _DesktopActionTile(
            title: 'Réapprovisionnement',
            subtitle: kpis.lowStockCount > 0
                ? '${kpis.lowStockCount} article(s) sous le seuil d\'alerte'
                : 'Inventaire et niveaux de stock',
            icon: Icons.inventory_2_outlined,
            color: kpis.lowStockCount > 0
                ? const Color(0xFFF59E0B)
                : const Color(0xFF10B981),
            onTap: onLowStock,
          ),

          if (onFxExchange != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _DesktopActionTile(
              title: 'Bureau de Change devises',
              subtitle: 'Achat & vente de devises étrangères',
              icon: Icons.currency_exchange_rounded,
              color: const Color(0xFF06B6D4),
              onTap: onFxExchange,
            ),
          ],
        ],
      ),
    );
  }
}

class _DesktopActionTile extends StatelessWidget {
  const _DesktopActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 10,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 6. Badge de connectivité réseau pour Desktop
// ---------------------------------------------------------------------------

class _DesktopNetworkStatusBadge extends StatefulWidget {
  const _DesktopNetworkStatusBadge();

  @override
  State<_DesktopNetworkStatusBadge> createState() =>
      _DesktopNetworkStatusBadgeState();
}

class _DesktopNetworkStatusBadgeState
    extends State<_DesktopNetworkStatusBadge> {
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
          isOnline =
              !snapshot.data!.every((r) => r == ConnectivityResult.none);
        } else {
          isOnline = _isOnline ?? true;
        }

        final color = isOnline ? Colors.green : Colors.amber.shade800;
        final bg = isOnline
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.amber.withValues(alpha: 0.15);
        final label = isOnline ? 'En ligne' : 'Hors-ligne';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
