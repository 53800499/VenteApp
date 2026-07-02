import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/components/action_feedback.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/debt_entities.dart';
import '../../domain/usecases/debt_usecases.dart';

class RecordDebtPaymentPage extends StatefulWidget {
  const RecordDebtPaymentPage({
    super.key,
    required this.session,
    required this.debt,
    required this.customerName,
  });

  final AuthSession session;
  final Debt debt;
  final String customerName;

  @override
  State<RecordDebtPaymentPage> createState() => _RecordDebtPaymentPageState();
}

class _RecordDebtPaymentPageState extends State<RecordDebtPaymentPage> {
  final _amountController = TextEditingController();
  final _tenderedController = TextEditingController();
  final _referenceController = TextEditingController();
  final _noteController = TextEditingController();

  DebtRepaymentMethod _method = DebtRepaymentMethod.cash;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = '${widget.debt.amountRemaining}';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _tenderedController.dispose();
    _referenceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int? get _amount => int.tryParse(_amountController.text.trim());
  int? get _tendered => int.tryParse(_tenderedController.text.trim());

  int get _change {
    final amount = _amount;
    final tendered = _tendered;
    if (_method != DebtRepaymentMethod.cash ||
        amount == null ||
        tendered == null ||
        tendered < amount) {
      return 0;
    }
    return tendered - amount;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enregistrer un paiement')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.customerName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.debt.receiptNumber != null
                        ? 'Vente ${widget.debt.receiptNumber}'
                        : 'Dette #${widget.debt.id}',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Solde restant : ${formatFcfa(widget.debt.amountRemaining)}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Montant du paiement (FCFA)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Mode de paiement', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          ...DebtRepaymentMethod.values.map(
            (method) => RadioListTile<DebtRepaymentMethod>(
              title: Text(method.label),
              value: method,
              groupValue: _method,
              onChanged: (v) => setState(() => _method = v!),
            ),
          ),
          if (_method == DebtRepaymentMethod.cash) ...[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _tenderedController,
              decoration: const InputDecoration(
                labelText: 'Montant remis (espèces)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (_) => setState(() {}),
            ),
            if (_change > 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Monnaie à rendre : ${formatFcfa(_change)}',
                  style: const TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
          if (_method == DebtRepaymentMethod.mtnMomo ||
              _method == DebtRepaymentMethod.moovMoney) ...[
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _referenceController,
              decoration: InputDecoration(
                labelText: 'Référence ${_method.label}',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _noteController,
            decoration: const InputDecoration(
              labelText: 'Note (optionnel)',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Confirmer le paiement'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final amount = _amount;
    if (amount == null || amount <= 0) {
      await ActionFeedback.showErrorDialog(
        context,
        title: 'Montant invalide',
        message: 'Saisissez un montant valide.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await sl<RecordDebtPayment>()(
        session: widget.session,
        debtId: widget.debt.id,
        input: RecordDebtPaymentInput(
          amount: amount,
          method: _method,
          reference: _referenceController.text.trim().isEmpty
              ? null
              : _referenceController.text.trim(),
          amountTendered: _method == DebtRepaymentMethod.cash ? _tendered : null,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        ),
      );

      if (!mounted) return;
      await ActionFeedback.showSuccess(
        context: context,
        title: 'Paiement enregistré',
        details: [
          Text('Montant : ${formatFcfa(result.amount)}'),
          if (result.changeGiven > 0)
            Text('Monnaie : ${formatFcfa(result.changeGiven)}'),
          Text('Reste dû : ${formatFcfa(result.amountRemaining)}'),
          if (result.receiptNumber != null)
            Text('Reçu : ${result.receiptNumber}'),
        ],
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Failure catch (e) {
      if (!mounted) return;
      await ActionFeedback.showErrorDialog(
        context,
        title: 'Paiement impossible',
        message: e.message,
      );
    } catch (_) {
      if (!mounted) return;
      await ActionFeedback.showErrorDialog(
        context,
        title: 'Paiement impossible',
        message: 'Impossible d\'enregistrer le paiement.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
