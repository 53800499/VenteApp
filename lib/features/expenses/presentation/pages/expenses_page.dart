import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/expense_entities.dart';
import '../../domain/usecases/expense_usecases.dart';
import '../bloc/expenses_bloc.dart';
import 'expense_categories_page.dart';
import 'expense_detail_page.dart';
import 'expense_form_page.dart';
import '../services/expense_pdf_exporter.dart';

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    ensureExpensesDependencies();

    return BlocProvider(
      create: (_) => ExpensesBloc(
        listExpenses: sl<ListExpenses>(),
        getSummary: sl<GetExpenseSummary>(),
        listCategories: sl<ListExpenseCategories>(),
        createExpense: sl<CreateExpense>(),
        deleteExpense: sl<DeleteExpense>(),
        syncFromRemote: sl<SyncExpensesFromRemote>(),
        generateRecurring: sl<GenerateRecurringExpenses>(),
        session: session,
      )..add(const ExpensesLoadRequested()),
      child: const _ExpensesView(),
    );
  }
}

class _ExpensesView extends StatelessWidget {
  const _ExpensesView();

  @override
  Widget build(BuildContext context) {
    final canCreate = PermissionGuard.can(
      context.read<ExpensesBloc>().session.user.permissions,
      Permission.expensesCreate,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dépenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Catégories & budgets',
            onPressed: () => _openCategories(context),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Exporter PDF',
            onPressed: () => _exportPdf(context),
          ),
          if (canCreate)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openForm(context),
            ),
        ],
      ),
      body: BlocBuilder<ExpensesBloc, ExpensesState>(
        builder: (context, state) {
          if (state.status == ExpensesStatus.loading && state.summary == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == ExpensesStatus.failure && state.summary == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.errorMessage ?? 'Erreur'),
                  const SizedBox(height: AppSpacing.md),
                  FilledButton(
                    onPressed: () => context
                        .read<ExpensesBloc>()
                        .add(const ExpensesLoadRequested()),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          final summary = state.summary;
          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async {
                  context.read<ExpensesBloc>().add(const ExpensesLoadRequested());
                },
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    if (summary != null) ...[
                      _SummaryCards(summary: summary),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    Text(
                      'Dépenses récentes',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (state.expenses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: Center(
                          child: Text('Aucune dépense enregistrée.'),
                        ),
                      )
                    else
                      ...state.expenses.map(
                        (expense) => _ExpenseTile(
                          expense: expense,
                          session: context.read<ExpensesBloc>().session,
                        ),
                      ),
                  ],
                ),
              ),
              if (state.status == ExpensesStatus.refreshing)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(),
                ),
            ],
          );
        },
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Dépense'),
            )
          : null,
    );
  }

  Future<void> _openForm(BuildContext context) async {
    final bloc = context.read<ExpensesBloc>();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ExpenseFormPage(
          session: bloc.session,
          categories: bloc.state.categories,
        ),
      ),
    );
    if (created == true && context.mounted) {
      context.read<ExpensesBloc>().add(const ExpensesLoadRequested());
    }
  }

  Future<void> _openCategories(BuildContext context) async {
    final bloc = context.read<ExpensesBloc>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseCategoriesPage(session: bloc.session),
      ),
    );
    if (context.mounted) {
      context.read<ExpensesBloc>().add(const ExpensesLoadRequested());
    }
  }

  Future<void> _exportPdf(BuildContext context) async {
    final bloc = context.read<ExpensesBloc>();
    final state = bloc.state;
    try {
      await sl<ExpensePdfExporter>().sharePdf(
        shopName: bloc.session.shop.name,
        expenses: state.expenses,
        summary: state.summary,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export impossible : $error')),
      );
    }
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});

  final ExpenseSummary summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Aujourd\'hui',
                value: formatFcfa(summary.today.totalAmount),
                subtitle: '${summary.today.expenseCount} dépense(s)',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiCard(
                label: 'Cette semaine',
                value: formatFcfa(summary.week.totalAmount),
                subtitle: '${summary.week.expenseCount} dépense(s)',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _KpiCard(
                label: 'Ce mois',
                value: formatFcfa(summary.month.totalAmount),
                subtitle: '${summary.month.expenseCount} dépense(s)',
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _KpiCard(
                label: 'Caisse estimée',
                value: formatFcfa(summary.estimatedCashBalance),
                subtitle:
                    'Encaissé ${formatFcfa(summary.cashCollectedToday)} · '
                    'Sorties ${formatFcfa(summary.cashExpensesToday)}',
                highlight: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.subtitle,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String subtitle;
  final bool highlight;

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
                    color: highlight
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense, required this.session});

  final Expense expense;
  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Row(
          children: [
            Expanded(child: Text(expense.title)),
            if (expense.repeatSchedule != ExpenseRepeatSchedule.none)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Icon(
                  Icons.repeat,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
        subtitle: Text(
          '${expense.categoryName ?? 'Sans catégorie'} · '
          '${expense.paymentMethod.label} · ${expense.status.label}',
        ),
        trailing: Text(
          formatFcfa(expense.amount),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
        ),
        onTap: () async {
          final changed = await Navigator.of(context).push<bool>(
            MaterialPageRoute(
              builder: (_) => ExpenseDetailPage(
                session: session,
                expenseId: expense.id,
              ),
            ),
          );
          if (changed == true && context.mounted) {
            context.read<ExpensesBloc>().add(const ExpensesLoadRequested());
          }
        },
      ),
    );
  }
}
