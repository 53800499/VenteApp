import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/network/widgets/offline_mode_banner.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/components/app_desktop_data_table.dart';
import '../../../../shared/components/app_header_actions.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../help/presentation/widgets/module_help_button.dart';
import '../../domain/entities/expense_entities.dart';
import '../bloc/expenses_bloc.dart';

/// Vue Desktop ERP moderne pour le module Dépenses & Charges d'Exploitation.
/// Optimisée pour Windows et les écrans larges (>= 600px).
class DesktopExpensesView extends StatefulWidget {
  const DesktopExpensesView({
    super.key,
    required this.session,
    required this.state,
    required this.canCreate,
    required this.onRefresh,
    required this.onOpenForm,
    required this.onOpenCategories,
    required this.onExportPdf,
    required this.onOpenDetail,
  });

  final AuthSession session;
  final ExpensesState state;
  final bool canCreate;
  final Future<void> Function() onRefresh;
  final VoidCallback onOpenForm;
  final VoidCallback onOpenCategories;
  final VoidCallback onExportPdf;
  final ValueChanged<Expense> onOpenDetail;

  @override
  State<DesktopExpensesView> createState() => _DesktopExpensesViewState();
}

class _DesktopExpensesViewState extends State<DesktopExpensesView> {
  final TextEditingController _searchController = TextEditingController();
  int? _selectedCategoryId;
  ExpensePaymentMethod? _selectedPaymentMethod;
  ExpenseStatus? _selectedStatus;

  // Tri : 0 = Date, 1 = Libellé, 2 = Montant
  int _sortColumn = 0;
  bool _sortAscending = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSort(int column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = column == 1; // Libellé en A-Z par défaut
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _selectedCategoryId = null;
      _selectedPaymentMethod = null;
      _selectedStatus = null;
    });
  }

  bool get _hasActiveFilters =>
      _searchController.text.trim().isNotEmpty ||
      _selectedCategoryId != null ||
      _selectedPaymentMethod != null ||
      _selectedStatus != null;

  List<Expense> get _filteredExpenses {
    var list = widget.state.expenses;

    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((e) {
        final titleMatch = e.title.toLowerCase().contains(query);
        final supplierMatch =
            e.supplier?.toLowerCase().contains(query) ?? false;
        final invoiceMatch =
            e.invoiceNumber?.toLowerCase().contains(query) ?? false;
        final descMatch = e.description?.toLowerCase().contains(query) ?? false;
        final catMatch = e.categoryName?.toLowerCase().contains(query) ?? false;
        return titleMatch ||
            supplierMatch ||
            invoiceMatch ||
            descMatch ||
            catMatch;
      }).toList();
    }

    if (_selectedCategoryId != null) {
      list = list.where((e) => e.categoryId == _selectedCategoryId).toList();
    }

    if (_selectedPaymentMethod != null) {
      list =
          list.where((e) => e.paymentMethod == _selectedPaymentMethod).toList();
    }

    if (_selectedStatus != null) {
      list = list.where((e) => e.status == _selectedStatus).toList();
    }

    // Tri
    list = List<Expense>.from(list);
    list.sort((a, b) {
      int cmp = 0;
      switch (_sortColumn) {
        case 0:
          cmp = a.expenseDate.compareTo(b.expenseDate);
          break;
        case 1:
          cmp = a.title.toLowerCase().compareTo(b.title.toLowerCase());
          break;
        case 2:
          cmp = a.amount.compareTo(b.amount);
          break;
        default:
          cmp = a.expenseDate.compareTo(b.expenseDate);
      }
      return _sortAscending ? cmp : -cmp;
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final state = widget.state;
    final summary = state.summary;
    final filtered = _filteredExpenses;
    final totalFilteredAmount =
        filtered.fold<int>(0, (sum, item) => sum + item.amount);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f2): () {
          if (widget.canCreate) widget.onOpenForm();
        },
        const SingleActivator(LogicalKeyboardKey.f5): () {
          widget.onRefresh();
        },
      },
      child: Focus(
        autofocus: true,
        child: Container(
          color: cs.surfaceContainerLowest.withValues(alpha: 0.5),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Barre de commande ERP supérieure
                _buildCommandHeader(context, theme, cs),

                const SizedBox(height: AppSpacing.sm),

                // Bandeau mode hybride / hors-ligne
                const OfflineModeBanner(
                  onlinePreferredMessage: OfflineModeBanner.hybridReadMessage,
                ),

                if (state.status == ExpensesStatus.refreshing) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: AppSpacing.xs),
                ],

                // 2. Les 4 KPIs stratégiques consolidés
                if (summary != null) ...[
                  _buildStrategicKpis(context, theme, cs, summary),
                  const SizedBox(height: AppSpacing.md),
                ],

                // 3. Barre de filtres et recherche ergonomique
                _buildFilterToolbar(context, theme, cs, filtered.length,
                    totalFilteredAmount),

                const SizedBox(height: AppSpacing.sm),

                // 4. Table des dépenses ERP Desktop
                Expanded(
                  child: filtered.isEmpty
                      ? Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            side: BorderSide(
                              color: cs.outlineVariant.withValues(alpha: 0.6),
                            ),
                          ),
                          child: Center(
                            child: SingleChildScrollView(
                              physics: const ClampingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  EmptyListPlaceholder(
                                    icon: _hasActiveFilters
                                        ? Icons.filter_alt_off_outlined
                                        : Icons.receipt_long_outlined,
                                    title: _hasActiveFilters
                                        ? 'Aucune dépense ne correspond aux filtres'
                                        : 'Aucune dépense enregistrée',
                                    subtitle: _hasActiveFilters
                                        ? 'Modifiez votre recherche ou réinitialisez les critères.'
                                        : 'Enregistrez vos achats, loyers, salaires et charges.',
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  if (_hasActiveFilters)
                                    OutlinedButton.icon(
                                      onPressed: _clearFilters,
                                      icon: const Icon(Icons.clear_all_rounded,
                                          size: 16),
                                      label: const Text('Effacer les filtres'),
                                    )
                                  else if (widget.canCreate)
                                    FilledButton.icon(
                                      onPressed: widget.onOpenForm,
                                      icon: const Icon(Icons.add_rounded,
                                          size: 16),
                                      label:
                                          const Text('Créer une dépense (F2)'),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : _buildExpensesTable(context, theme, cs, filtered),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. Barre de commande supérieure ERP Desktop
  // ===========================================================================
  Widget _buildCommandHeader(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 1120;

        final titleBlock = Row(
          children: [
            if (Navigator.of(context).canPop()) ...[
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                tooltip: 'Retour',
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.amber.shade700.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: Colors.amber.shade700.withValues(alpha: 0.3),
                ),
              ),
              child: Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.amber.shade800,
                size: 24,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Dépenses & Charges d\'Exploitation',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Text(
                          '${widget.state.expenses.length} enregistrée(s)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cs.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Suivi des sorties de caisse, justificatifs, budgets par catégorie et charges fixes',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        );

        final actionButtons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.canCreate) ...[
              FilledButton.icon(
                onPressed: widget.onOpenForm,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Nouvelle Dépense (F2)'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            OutlinedButton.icon(
              onPressed: widget.onOpenCategories,
              icon: const Icon(Icons.category_outlined, size: 16),
              label: const Text('Catégories & Budgets'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            FilledButton.tonalIcon(
              onPressed: widget.onExportPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
              label: const Text('Export PDF'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            IconButton.filledTonal(
              icon: const Icon(Icons.refresh_rounded, size: 18),
              tooltip: 'Actualiser (F5)',
              onPressed: widget.onRefresh,
            ),
            const SizedBox(width: AppSpacing.xs),
            const ModuleHelpButton(articleId: 'expenses'),
            const AppHeaderActions(),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleBlock,
              const SizedBox(height: AppSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: actionButtons,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: AppSpacing.md),
            actionButtons,
          ],
        );
      },
    );
  }

  // ===========================================================================
  // 2. Les 4 Cartes Stratégiques KPIs
  // ===========================================================================
  Widget _buildStrategicKpis(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    ExpenseSummary summary,
  ) {
    final card1 = _ExpenseKpiCard(
      icon: Icons.today_rounded,
      label: 'Dépenses Aujourd\'hui',
      value: formatFcfa(summary.today.totalAmount),
      subtitle: '${summary.today.expenseCount} dépense(s) du jour',
      accentColor: Colors.amber.shade800,
      backgroundColor: Colors.amber.shade50,
    );

    final card2 = _ExpenseKpiCard(
      icon: Icons.date_range_rounded,
      label: 'Dépenses Cette Semaine',
      value: formatFcfa(summary.week.totalAmount),
      subtitle: '${summary.week.expenseCount} dépense(s) sur 7 jours',
      accentColor: Colors.blue.shade700,
      backgroundColor: Colors.blue.shade50,
    );

    final card3 = _ExpenseKpiCard(
      icon: Icons.calendar_month_rounded,
      label: 'Dépenses Ce Mois',
      value: formatFcfa(summary.month.totalAmount),
      subtitle: '${summary.month.expenseCount} dépense(s) mensuelle(s)',
      accentColor: Colors.deepPurple.shade700,
      backgroundColor: Colors.deepPurple.shade50,
    );

    final card4 = _ExpenseKpiCard(
      icon: Icons.account_balance_wallet_rounded,
      label: 'Caisse Estimée & Flux',
      value: formatFcfa(summary.estimatedCashBalance),
      subtitle:
          'Encaissé : +${formatFcfa(summary.cashCollectedToday)} · Sorties : -${formatFcfa(summary.cashExpensesToday)}',
      accentColor: cs.primary,
      backgroundColor: cs.primaryContainer.withValues(alpha: 0.35),
      highlight: true,
      badgeText: 'Position Caisse',
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 960) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(width: 240, child: card1),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(width: 240, child: card2),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(width: 240, child: card3),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(width: 260, child: card4),
              ],
            ),
          );
        }

        return Row(
          children: [
            Expanded(child: card1),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: card2),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: card3),
            const SizedBox(width: AppSpacing.sm),
            Expanded(flex: 1, child: card4),
          ],
        );
      },
    );
  }

  // ===========================================================================
  // 3. Barre de filtres et de recherche
  // ===========================================================================
  Widget _buildFilterToolbar(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    int filteredCount,
    int filteredAmount,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 900;

          final searchField = SizedBox(
            width: isNarrow ? double.infinity : 260,
            height: 38,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Rechercher libellé, fournisseur, facture...',
                hintStyle: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          );

          final categoryDropdown = SizedBox(
            width: isNarrow ? double.infinity : 200,
            height: 38,
            child: DropdownButtonFormField<int?>(
              initialValue: _selectedCategoryId,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Catégorie',
                labelStyle: const TextStyle(fontSize: 11),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('Toutes catégories', style: TextStyle(fontSize: 12)),
                ),
                ...widget.state.categories.map(
                  (c) => DropdownMenuItem<int?>(
                    value: c.id,
                    child: Text(
                      c.name,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() => _selectedCategoryId = val);
              },
            ),
          );

          final paymentDropdown = SizedBox(
            width: isNarrow ? double.infinity : 170,
            height: 38,
            child: DropdownButtonFormField<ExpensePaymentMethod?>(
              initialValue: _selectedPaymentMethod,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Mode de paiement',
                labelStyle: const TextStyle(fontSize: 11),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
              items: [
                const DropdownMenuItem<ExpensePaymentMethod?>(
                  value: null,
                  child: Text('Tous les modes', style: TextStyle(fontSize: 12)),
                ),
                ...ExpensePaymentMethod.values.map(
                  (m) => DropdownMenuItem<ExpensePaymentMethod?>(
                    value: m,
                    child: Text(
                      m.label,
                      style: const TextStyle(fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() => _selectedPaymentMethod = val);
              },
            ),
          );

          final statusDropdown = SizedBox(
            width: isNarrow ? double.infinity : 150,
            height: 38,
            child: DropdownButtonFormField<ExpenseStatus?>(
              initialValue: _selectedStatus,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Statut',
                labelStyle: const TextStyle(fontSize: 11),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
              ),
              items: [
                const DropdownMenuItem<ExpenseStatus?>(
                  value: null,
                  child: Text('Tous statuts', style: TextStyle(fontSize: 12)),
                ),
                ...ExpenseStatus.values.map(
                  (s) => DropdownMenuItem<ExpenseStatus?>(
                    value: s,
                    child: Text(
                      s.label,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
              onChanged: (val) {
                setState(() => _selectedStatus = val);
              },
            ),
          );

          final summaryLabel = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$filteredCount dépense(s)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '· Total : ${formatFcfa(filteredAmount)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.danger,
                ),
              ),
              if (_hasActiveFilters) ...[
                const SizedBox(width: AppSpacing.sm),
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 14),
                  label: const Text('Réinitialiser'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchField,
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(child: categoryDropdown),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: paymentDropdown),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(child: statusDropdown),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                summaryLabel,
              ],
            );
          }

          return Row(
            children: [
              searchField,
              const SizedBox(width: AppSpacing.sm),
              categoryDropdown,
              const SizedBox(width: AppSpacing.sm),
              paymentDropdown,
              const SizedBox(width: AppSpacing.sm),
              statusDropdown,
              const Spacer(),
              summaryLabel,
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 4. Table des Dépenses Desktop (AppDesktopDataTable)
  // ===========================================================================
  Widget _buildExpensesTable(
    BuildContext context,
    ThemeData theme,
    ColorScheme cs,
    List<Expense> expenses,
  ) {
    final columns = [
      AppTableColumn(
        label: 'Date & Heure',
        icon: Icons.calendar_today_rounded,
        minWidth: 140,
        flex: 2,
        isSorted: _sortColumn == 0,
        sortAscending: _sortAscending,
        onSort: () => _toggleSort(0),
      ),
      AppTableColumn(
        label: 'Libellé & Référence',
        icon: Icons.description_outlined,
        minWidth: 240,
        flex: 3,
        isSorted: _sortColumn == 1,
        sortAscending: _sortAscending,
        onSort: () => _toggleSort(1),
      ),
      const AppTableColumn(
        label: 'Catégorie',
        icon: Icons.category_outlined,
        minWidth: 150,
        flex: 2,
      ),
      const AppTableColumn(
        label: 'Mode de Paiement',
        icon: Icons.account_balance_wallet_outlined,
        minWidth: 140,
        flex: 2,
      ),
      const AppTableColumn(
        label: 'Statut',
        icon: Icons.verified_outlined,
        minWidth: 110,
        flex: 1,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
      AppTableColumn(
        label: 'Montant',
        icon: Icons.payments_outlined,
        minWidth: 140,
        flex: 2,
        alignment: Alignment.centerRight,
        textAlign: TextAlign.right,
        isSorted: _sortColumn == 2,
        sortAscending: _sortAscending,
        onSort: () => _toggleSort(2),
      ),
      const AppTableColumn(
        label: 'Actions',
        minWidth: 90,
        flex: 1,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
      ),
    ];

    final rows = expenses.map((expense) {
      final expenseDt =
          DateTime.fromMillisecondsSinceEpoch(expense.expenseDate);
      final formattedDate = AppDateFormatter.formatDate(expenseDt);
      final formattedTime = AppDateFormatter.formatTime(expenseDt);

      return AppTableRow(
        onTap: () => widget.onOpenDetail(expense),
        cells: [
          // 1. Date & Heure
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                formattedDate,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'à $formattedTime',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),

          // 2. Libellé & Références
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      expense.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (expense.repeatSchedule != ExpenseRepeatSchedule.none) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.repeat, size: 10, color: cs.primary),
                          const SizedBox(width: 2),
                          Text(
                            expense.repeatSchedule.label,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (expense.attachments.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.attach_file_rounded,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ],
              ),
              if (expense.supplier != null || expense.invoiceNumber != null) ...[
                const SizedBox(height: 2),
                Text(
                  [
                    if (expense.supplier != null) 'Fourn: ${expense.supplier}',
                    if (expense.invoiceNumber != null)
                      'Fact: ${expense.invoiceNumber}',
                  ].join(' · '),
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ] else if (expense.createdByName != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Enregistré par ${expense.createdByName}',
                  style: TextStyle(
                    fontSize: 11,
                    color: cs.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),

          // 3. Catégorie
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border:
                    Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.label_outline_rounded,
                    size: 12,
                    color: cs.primary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      expense.categoryName ?? 'Sans catégorie',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 4. Mode de Paiement
          Align(
            alignment: Alignment.centerLeft,
            child: _buildPaymentMethodBadge(expense.paymentMethod, cs),
          ),

          // 5. Statut
          Align(
            alignment: Alignment.center,
            child: _buildStatusBadge(expense.status, cs),
          ),

          // 6. Montant
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '- ${formatFcfa(expense.amount)}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.danger,
                letterSpacing: -0.2,
              ),
            ),
          ),

          // 7. Actions
          Align(
            alignment: Alignment.center,
            child: OutlinedButton(
              onPressed: () => widget.onOpenDetail(expense),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                visualDensity: VisualDensity.compact,
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: const Text('Détails'),
            ),
          ),
        ],
      );
    }).toList();

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: AppDesktopDataTable(
        columns: columns,
        rows: rows,
        minWidth: 1010,
        itemsPerPage: 15,
        headerTrailing: Text(
          'Total filtré : ${formatFcfa(expenses.fold<int>(0, (sum, i) => sum + i.amount))}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // Badges & Helpers
  // ===========================================================================
  Widget _buildPaymentMethodBadge(
    ExpensePaymentMethod method,
    ColorScheme cs,
  ) {
    final (icon, color) = switch (method) {
      ExpensePaymentMethod.cash => (Icons.payments_outlined, const Color(0xFF0D9488)),
      ExpensePaymentMethod.mtnMomo => (Icons.phone_android_outlined, Colors.amber.shade800),
      ExpensePaymentMethod.moovMoney => (Icons.phone_android_outlined, Colors.blue.shade700),
      ExpensePaymentMethod.card => (Icons.credit_card_outlined, Colors.indigo.shade700),
      ExpensePaymentMethod.transfer => (Icons.account_balance_outlined, Colors.teal.shade700),
      ExpensePaymentMethod.check => (Icons.receipt_outlined, Colors.purple.shade700),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              method.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ExpenseStatus status, ColorScheme cs) {
    final (label, color, icon) = switch (status) {
      ExpenseStatus.validated => ('Validée', AppColors.success, Icons.check_circle_outline_rounded),
      ExpenseStatus.pending => ('En attente', AppColors.warning, Icons.hourglass_top_rounded),
      ExpenseStatus.draft => ('Brouillon', cs.outline, Icons.edit_note_rounded),
      ExpenseStatus.refused => ('Refusée', AppColors.danger, Icons.cancel_outlined),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte KPI pour les dépenses avec design ERP soigné
class _ExpenseKpiCard extends StatelessWidget {
  const _ExpenseKpiCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.accentColor,
    required this.backgroundColor,
    this.highlight = false,
    this.badgeText,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color accentColor;
  final Color backgroundColor;
  final bool highlight;
  final String? badgeText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: highlight
              ? accentColor.withValues(alpha: 0.5)
              : cs.outlineVariant.withValues(alpha: 0.6),
          width: highlight ? 1.5 : 1.0,
        ),
      ),
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(icon, size: 16, color: accentColor),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badgeText != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      badgeText!,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: accentColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.3,
                color: highlight ? accentColor : cs.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
