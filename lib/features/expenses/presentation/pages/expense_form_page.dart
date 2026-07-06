import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/auth/app_lock_controller.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/expense_entities.dart';
import '../../domain/usecases/expense_usecases.dart';

class ExpenseFormPage extends StatefulWidget {
  const ExpenseFormPage({
    super.key,
    required this.session,
    required this.categories,
    this.expense,
  });

  final AuthSession session;
  final List<ExpenseCategory> categories;
  final Expense? expense;

  @override
  State<ExpenseFormPage> createState() => _ExpenseFormPageState();
}

class _ExpenseFormPageState extends State<ExpenseFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _supplierController = TextEditingController();
  final _invoiceController = TextEditingController();

  int? _categoryId;
  ExpensePaymentMethod _paymentMethod = ExpensePaymentMethod.cash;
  ExpenseRepeatSchedule _repeat = ExpenseRepeatSchedule.none;
  ExpenseStatus _status = ExpenseStatus.validated;
  DateTime _expenseDate = DateTime.now();
  final List<String> _attachmentPaths = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final expense = widget.expense;
    if (expense != null) {
      _titleController.text = expense.title;
      _amountController.text = '${expense.amount}';
      _descriptionController.text = expense.description ?? '';
      _supplierController.text = expense.supplier ?? '';
      _invoiceController.text = expense.invoiceNumber ?? '';
      _categoryId = expense.categoryId;
      _paymentMethod = expense.paymentMethod;
      _repeat = expense.repeatSchedule;
      _status = expense.status;
      _expenseDate = DateTime.fromMillisecondsSinceEpoch(expense.expenseDate);
    } else if (widget.categories.isNotEmpty) {
      _categoryId = widget.categories.first.id;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _supplierController.dispose();
    _invoiceController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final result = await sl<AppLockController>().runWithLockSuppressed(
      () => FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      ),
    );
    final file = result?.files.single;
    final filePath = file?.path;
    if (filePath == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory(p.join(dir.path, 'expense_receipts'));
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }
    final savedPath = p.join(
      receiptsDir.path,
      '${DateTime.now().millisecondsSinceEpoch}_${p.basename(filePath)}',
    );
    await File(filePath).copy(savedPath);
    setState(() => _attachmentPaths.add(savedPath));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    ensureExpensesDependencies();

    final input = CreateExpenseInput(
      categoryId: _categoryId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      amount: int.parse(_amountController.text.trim()),
      expenseDate: DateTime(
        _expenseDate.year,
        _expenseDate.month,
        _expenseDate.day,
      ).millisecondsSinceEpoch,
      paymentMethod: _paymentMethod,
      supplier: _supplierController.text.trim().isEmpty
          ? null
          : _supplierController.text.trim(),
      invoiceNumber: _invoiceController.text.trim().isEmpty
          ? null
          : _invoiceController.text.trim(),
      repeatSchedule: _repeat,
      status: _status,
      attachmentPaths: _attachmentPaths,
    );

    try {
      if (widget.expense == null) {
        await sl<CreateExpense>()(
          shopId: widget.session.shop.id,
          userId: widget.session.user.id,
          input: input,
        );
      } else {
        await sl<UpdateExpense>()(
          shopId: widget.session.shop.id,
          expenseId: widget.expense!.id,
          userId: widget.session.user.id,
          input: input,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.expense == null ? 'Nouvelle dépense' : 'Modifier'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Titre *'),
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Titre requis' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Montant (FCFA) *'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                if (n == null || n <= 0) return 'Montant invalide';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<int>(
              value: _categoryId,
              decoration: const InputDecoration(labelText: 'Catégorie'),
              items: widget.categories
                  .map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _categoryId = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<ExpensePaymentMethod>(
              value: _paymentMethod,
              decoration: const InputDecoration(labelText: 'Paiement'),
              items: ExpensePaymentMethod.values
                  .map(
                    (m) => DropdownMenuItem(value: m, child: Text(m.label)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _paymentMethod = v!),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<ExpenseRepeatSchedule>(
              value: _repeat,
              decoration: const InputDecoration(labelText: 'Récurrence'),
              items: ExpenseRepeatSchedule.values
                  .map(
                    (r) => DropdownMenuItem(value: r, child: Text(r.label)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _repeat = v!),
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date de dépense'),
              subtitle: Text(
                '${_expenseDate.day.toString().padLeft(2, '0')}/'
                '${_expenseDate.month.toString().padLeft(2, '0')}/'
                '${_expenseDate.year}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _expenseDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _expenseDate = picked);
              },
            ),
            TextFormField(
              controller: _supplierController,
              decoration: const InputDecoration(labelText: 'Fournisseur'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _invoiceController,
              decoration: const InputDecoration(labelText: 'N° facture'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _pickAttachment,
              icon: const Icon(Icons.receipt_long),
              label: const Text('Joindre une pièce (photo)'),
            ),
            if (_attachmentPaths.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text('${_attachmentPaths.length} pièce(s) jointe(s)'),
              ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.expense == null ? 'Enregistrer' : 'Mettre à jour'),
            ),
          ],
        ),
      ),
    );
  }
}
