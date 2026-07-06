import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/expense_entities.dart';
import '../../domain/usecases/expense_usecases.dart';

class ExpenseCategoriesPage extends StatefulWidget {
  const ExpenseCategoriesPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<ExpenseCategoriesPage> createState() => _ExpenseCategoriesPageState();
}

class _ExpenseCategoriesPageState extends State<ExpenseCategoriesPage> {
  List<ExpenseCategory> _categories = [];
  List<ExpenseByCategory> _usage = [];
  bool _loading = true;
  String? _error;

  bool get _canManage => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.expensesCategories,
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
      final shopId = widget.session.shop.id;
      final now = DateTime.now().millisecondsSinceEpoch;
      final monthStart = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        1,
      ).millisecondsSinceEpoch;

      final results = await Future.wait([
        sl<ListExpenseCategories>()(shopId: shopId),
        sl<GetExpensesByCategory>()(
          shopId: shopId,
          fromMs: monthStart,
          toMs: now,
        ),
      ]);

      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<ExpenseCategory>;
        _usage = results[1] as List<ExpenseByCategory>;
        _loading = false;
      });
    } on Failure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  int _spentFor(int categoryId) {
    return _usage
            .where((u) => u.categoryId == categoryId)
            .map((u) => u.totalAmount)
            .firstOrNull ??
        0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Catégories & budgets')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final spent = _spentFor(category.id);
                      final budget = category.monthlyBudget;
                      final overBudget =
                          budget != null && budget > 0 && spent > budget;

                      return Card(
                        child: ListTile(
                          title: Text(category.name),
                          subtitle: Text(
                            budget != null
                                ? 'Dépensé ${formatFcfa(spent)} / ${formatFcfa(budget)} ce mois'
                                : 'Dépensé ${formatFcfa(spent)} ce mois',
                          ),
                          trailing: overBudget
                              ? Icon(
                                  Icons.warning_amber,
                                  color: Theme.of(context).colorScheme.error,
                                )
                              : _canManage
                                  ? const Icon(Icons.edit_outlined)
                                  : null,
                          onTap: _canManage
                              ? () => _editBudget(category, spent)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: _canManage
          ? FloatingActionButton(
              onPressed: _createCategory,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Future<void> _editBudget(ExpenseCategory category, int spent) async {
    final controller = TextEditingController(
      text: category.monthlyBudget?.toString() ?? '',
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Budget — ${category.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dépensé ce mois : ${formatFcfa(spent)}'),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Budget mensuel (FCFA)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final amount = int.tryParse(controller.text.trim()) ?? 0;
    try {
      await sl<UpsertCategoryBudget>()(
        shopId: widget.session.shop.id,
        categoryId: category.id,
        monthlyAmount: amount,
      );
      await _load();
    } on Failure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    }
  }

  Future<void> _createCategory() async {
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouvelle catégorie'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Nom',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (created != true || controller.text.trim().length < 2) return;

    try {
      await sl<CreateExpenseCategory>()(
        shopId: widget.session.shop.id,
        name: controller.text.trim(),
      );
      await _load();
    } on Failure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
