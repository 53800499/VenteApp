import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/benin_day_range.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/expense_entities.dart';
import '../../domain/usecases/expense_usecases.dart';
import 'expense_form_page.dart';

class ExpenseDetailPage extends StatefulWidget {
  const ExpenseDetailPage({
    super.key,
    required this.session,
    required this.expenseId,
  });

  final AuthSession session;
  final int expenseId;

  @override
  State<ExpenseDetailPage> createState() => _ExpenseDetailPageState();
}

class _ExpenseDetailPageState extends State<ExpenseDetailPage> {
  ExpenseDetail? _detail;
  bool _loading = true;
  String? _error;

  bool get _canUpdate => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.expensesUpdate,
      );

  bool get _canDelete => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.expensesArchive,
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await sl<GetExpenseDetail>()(
        session: widget.session,
        expenseId: widget.expenseId,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on Failure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger la dépense.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final expense = _detail?.expense;

    return Scaffold(
      appBar: AppBar(
        title: Text(expense?.title ?? 'Dépense #${widget.expenseId}'),
        actions: [
          if (expense != null && (_canUpdate || _canDelete))
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _edit(expense);
                if (value == 'delete') _delete();
              },
              itemBuilder: (context) => [
                if (_canUpdate)
                  const PopupMenuItem(value: 'edit', child: Text('Modifier')),
                if (_canDelete)
                  const PopupMenuItem(value: 'delete', child: Text('Supprimer')),
              ],
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    final detail = _detail!;
    final expense = detail.expense;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatFcfa(expense.amount),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _InfoRow(
                    label: 'Catégorie',
                    value: expense.categoryName ?? 'Sans catégorie',
                  ),
                  _InfoRow(
                    label: 'Date',
                    value: formatBeninDate(expense.expenseDate),
                  ),
                  _InfoRow(label: 'Paiement', value: expense.paymentMethod.label),
                  _InfoRow(label: 'Statut', value: expense.status.label),
                  if (expense.repeatSchedule != ExpenseRepeatSchedule.none)
                    _InfoRow(
                      label: 'Récurrence',
                      value: expense.repeatSchedule.label,
                    ),
                  if (expense.supplier != null)
                    _InfoRow(label: 'Fournisseur', value: expense.supplier!),
                  if (expense.invoiceNumber != null)
                    _InfoRow(
                      label: 'N° facture',
                      value: expense.invoiceNumber!,
                    ),
                  if (expense.description != null &&
                      expense.description!.isNotEmpty)
                    _InfoRow(label: 'Description', value: expense.description!),
                  if (expense.createdByName != null)
                    _InfoRow(
                      label: 'Créée par',
                      value: expense.createdByName!,
                    ),
                ],
              ),
            ),
          ),
          if (expense.attachments.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Pièces jointes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...expense.attachments.map(
              (a) => ListTile(
                leading: const Icon(Icons.attach_file),
                title: Text(a.fileName),
                dense: true,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Historique des modifications',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (detail.history.isEmpty)
            const Card(
              child: ListTile(
                title: Text('Aucune modification enregistrée.'),
              ),
            )
          else
            ...detail.history.map(
              (entry) => Card(
                child: ListTile(
                  title: Text(_fieldLabel(entry.fieldName)),
                  subtitle: Text(
                    '${entry.oldValue ?? '—'} → ${entry.newValue ?? '—'}'
                    '${entry.userName != null ? '\nPar ${entry.userName}' : ''}',
                  ),
                  trailing: Text(
                    formatBeninDate(entry.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _fieldLabel(String field) => switch (field) {
        'title' => 'Titre',
        'amount' => 'Montant',
        'status' => 'Statut',
        'deleted_at' => 'Suppression',
        _ => field,
      };

  Future<void> _edit(Expense expense) async {
    final categories = await sl<ListExpenseCategories>()(
      shopId: widget.session.shop.id,
    );
    if (!mounted) return;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ExpenseFormPage(
          session: widget.session,
          categories: categories,
          expense: expense,
        ),
      ),
    );
    if (updated == true) await _load();
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer cette dépense ?'),
        content: const Text('Cette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await sl<DeleteExpense>()(
        shopId: widget.session.shop.id,
        expenseId: widget.expenseId,
        userId: widget.session.user.id,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on Failure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
