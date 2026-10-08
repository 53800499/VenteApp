import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/components/app_desktop_data_table.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/customer_entities.dart';
import '../bloc/customer_list_bloc.dart';

/// Vue Desktop ERP moderne et adaptative pour le répertoire des clients.
class DesktopCustomerListView extends StatelessWidget {
  const DesktopCustomerListView({
    super.key,
    required this.session,
    required this.state,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onRefresh,
    required this.onNewCustomer,
    required this.onCustomerTap,
    required this.onDebtFilterToggled,
    required this.onSortSelected,
    required this.canWrite,
  });

  final AuthSession session;
  final CustomerListState state;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final Future<void> Function() onRefresh;
  final VoidCallback onNewCustomer;
  final ValueChanged<int> onCustomerTap;
  final ValueChanged<bool> onDebtFilterToggled;
  final ValueChanged<CustomerSort> onSortSelected;
  final bool canWrite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final customers = state.customers;

    final debtors = customers.where((c) => c.balanceDue > 0).toList();
    final totalDebtAmount = debtors.fold<int>(0, (sum, c) => sum + c.balanceDue);

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
            // 1. En-tête de commande ERP
            _buildCommandHeader(context, theme, scheme, customers.length, debtors.length, totalDebtAmount),

            const SizedBox(height: AppSpacing.md),

            // 2. Barre d'outils (Recherche + Filtres Débiteurs + Tri)
            _buildToolbar(theme, scheme, debtors.length),

            const SizedBox(height: AppSpacing.md),

            // 3. Tableau de données moderne ERP
            Expanded(
              child: _buildDataTable(context, theme, scheme, customers),
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
    int totalCount,
    int debtorCount,
    int totalDebtAmount,
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
              Icons.people_alt_rounded,
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
                      'Répertoire & Crédits Clients',
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
                        '$totalCount client${totalCount > 1 ? 's' : ''}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (debtorCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          '$debtorCount débiteur${debtorCount > 1 ? 's' : ''} (${formatFcfa(totalDebtAmount)})',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Gestion des contacts, fidélisation, historique des achats et suivi des créances',
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
            onPressed: state.isRefreshing ? null : onRefresh,
            tooltip: 'Actualiser la liste',
            icon: state.isRefreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 20),
          ),
          if (canWrite) ...[
            const SizedBox(width: AppSpacing.sm),
            FilledButton.icon(
              onPressed: onNewCustomer,
              icon: const Icon(Icons.person_add_rounded, size: 18),
              label: const Text('Nouveau Client'),
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

  Widget _buildToolbar(ThemeData theme, ColorScheme scheme, int debtorCount) {
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
          // Recherche
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 40,
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Rechercher un client par nom, téléphone…',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: onClearSearch,
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
                onChanged: onSearchChanged,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Filtre Débiteurs
          FilterChip(
            avatar: Icon(
              Icons.account_balance_wallet_outlined,
              size: 14,
              color: state.filters.hasDebtOnly ? AppColors.danger : AppColors.onSurfaceMuted,
            ),
            label: Text(
              debtorCount > 0 ? 'Débiteurs ($debtorCount)' : 'Débiteurs',
            ),
            selected: state.filters.hasDebtOnly,
            onSelected: onDebtFilterToggled,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: AppSpacing.xs),

          // Menu de tri
          PopupMenuButton<CustomerSort>(
            tooltip: 'Trier la liste',
            onSelected: onSortSelected,
            itemBuilder: (_) => const [
              PopupMenuItem(value: CustomerSort.name, child: Text('Nom')),
              PopupMenuItem(value: CustomerSort.debt, child: Text('Dette décroissante')),
              PopupMenuItem(value: CustomerSort.lastActivity, child: Text('Dernière activité')),
            ],
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sort_rounded, size: 18, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    _sortLabel(state.filters.sort),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataTable(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    List<Customer> customers,
  ) {
    if (customers.isEmpty) {
      return EmptyListPlaceholder(
        embedded: true,
        icon: Icons.people_outline,
        title: state.filters.hasDebtOnly
            ? 'Aucun client débiteur'
            : 'Aucun client trouvé',
        subtitle: searchController.text.isNotEmpty
            ? 'Aucun contact ne correspond à "${searchController.text}"'
            : (canWrite ? 'Enregistrez votre premier client avec le bouton ci-dessus.' : null),
      );
    }

    final columns = [
      const AppTableColumn(
        label: 'Client / Contact',
        icon: Icons.person_outline_rounded,
        flex: 3,
      ),
      const AppTableColumn(
        label: 'Téléphone',
        icon: Icons.phone_outlined,
        width: 150,
      ),
      const AppTableColumn(
        label: 'Adresse',
        icon: Icons.location_on_outlined,
        width: 150,
      ),
      const AppTableColumn(
        label: 'Achats Cumulés',
        icon: Icons.shopping_bag_outlined,
        width: 150,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Solde Dû (Créance)',
        icon: Icons.account_balance_wallet_outlined,
        width: 170,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
      ),
      const AppTableColumn(
        label: 'Dernière Activité',
        icon: Icons.schedule_rounded,
        width: 150,
        alignment: Alignment.center,
      ),
      const AppTableColumn(
        label: 'Action',
        width: 100,
        alignment: Alignment.center,
      ),
    ];

    final rows = customers.map((customer) {
      final hasDebt = customer.balanceDue > 0;
      final initial = customer.name.isNotEmpty ? customer.name[0].toUpperCase() : 'C';

      String lastActivityStr = '—';
      if (customer.lastActivityAt != null && customer.lastActivityAt! > 0) {
        final dt = DateTime.fromMillisecondsSinceEpoch(customer.lastActivityAt!);
        lastActivityStr = AppDateFormatter.formatDate(dt);
      }

      return AppTableRow(
        onTap: () => onCustomerTap(customer.id),
        cells: [
          // 1. Client
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: hasDebt
                    ? AppColors.danger.withValues(alpha: 0.15)
                    : scheme.primaryContainer.withValues(alpha: 0.5),
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: hasDebt ? AppColors.danger : scheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (customer.purchaseCount > 0)
                      Text(
                        '${customer.purchaseCount} commande${customer.purchaseCount > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.onSurfaceMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // 2. Téléphone
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (customer.phone != null && customer.phone!.isNotEmpty) ...[
                Icon(Icons.phone_rounded, size: 14, color: AppColors.onSurfaceMuted),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    customer.phone!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ] else
                Text('—', style: TextStyle(color: AppColors.onSurfaceMuted)),
            ],
          ),

          // 3. Adresse
          Text(
            customer.address?.isNotEmpty == true ? customer.address! : '—',
            style: TextStyle(
              fontSize: 13,
              color: customer.address?.isNotEmpty == true ? scheme.onSurface : AppColors.onSurfaceMuted,
            ),
            overflow: TextOverflow.ellipsis,
          ),

          // 4. Achats cumulés
          Text(
            formatFcfa(customer.totalPurchases),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),

          // 5. Solde Dû (Créance)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: hasDebt
                  ? AppColors.danger.withValues(alpha: 0.12)
                  : AppColors.success.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(
                color: hasDebt
                    ? AppColors.danger.withValues(alpha: 0.4)
                    : AppColors.success.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasDebt ? Icons.account_balance_wallet_outlined : Icons.check_circle_rounded,
                  size: 12,
                  color: hasDebt ? AppColors.danger : AppColors.success,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    hasDebt ? formatFcfa(customer.balanceDue) : 'À jour',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: hasDebt ? AppColors.danger : AppColors.success,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // 6. Dernière activité
          Text(
            lastActivityStr,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.onSurfaceMuted,
              fontWeight: FontWeight.w500,
            ),
          ),

          // 7. Action
          IconButton(
            onPressed: () => onCustomerTap(customer.id),
            tooltip: 'Fiche client & Crédits',
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
      minWidth: 920,
    );
  }

  String _sortLabel(CustomerSort sort) {
    return switch (sort) {
      CustomerSort.name => 'Nom',
      CustomerSort.debt => 'Dette',
      CustomerSort.lastActivity => 'Dernière activité',
    };
  }
}
