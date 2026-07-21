import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/sale_entities.dart';
import '../../domain/usecases/sale_usecases.dart';
import '../../../cash_sessions/domain/usecases/cash_session_usecases.dart';
import '../widgets/sale_feedback.dart';
import '../../../help/presentation/widgets/module_help_button.dart';
import 'sale_receipt_page.dart';

class QuickSalePage extends StatefulWidget {
  const QuickSalePage({super.key, required this.session});

  final AuthSession session;

  @override
  State<QuickSalePage> createState() => _QuickSalePageState();
}

class _QuickSalePageState extends State<QuickSalePage> {
  final _amountController = TextEditingController();
  PaymentMethod _method = PaymentMethod.cash;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'Montant invalide.');
      return;
    }

    final confirmed = await SaleFeedback.confirm(
      context: context,
      title: 'Confirmer la vente rapide',
      message:
          'Enregistrer une vente de ${formatFcfa(amount)} '
          'en ${_method.label} ?\n\n'
          'Aucun détail produit ni impact stock.',
    );
    if (confirmed != true || !mounted) return;

    final openSession = await sl<FindOpenCashSession>()(session: widget.session);
    if (openSession == null) {
      setState(() {
        _error =
            'Ouvrez la caisse (Plus → Gestion de caisse) avant une vente.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    ensureCashSessionDependencies();

    try {
      final sale = await SaleFeedback.runWithBlockingLoader<Sale>(
        context: context,
        message: 'Enregistrement de la vente…',
        action: () async {
          final payment = switch (_method) {
            PaymentMethod.cash => PaymentDraft(
                method: PaymentMethod.cash,
                amountCash: amount,
              ),
            PaymentMethod.mtnMomo || PaymentMethod.moovMoney => PaymentDraft(
                method: _method,
                amountMomo: amount,
              ),
            _ => PaymentDraft(method: PaymentMethod.cash, amountCash: amount),
          };

          return sl<CreateQuickSale>()(
            session: widget.session,
            input: CreateQuickSaleInput(
              totalAmount: amount,
              payment: payment,
            ),
          );
        },
      );

      if (!mounted || sale == null) return;

      await SaleFeedback.showSaleRegistered(context, sale: sale);
      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SaleReceiptPage(
            session: widget.session,
            sale: sale,
          ),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Failure catch (e) {
      if (!mounted) return;
      await SaleFeedback.showErrorDialog(
        context,
        title: 'Vente impossible',
        message: e.message,
      );
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      const message = 'Échec de la vente rapide.';
      await SaleFeedback.showErrorDialog(
        context,
        title: 'Vente impossible',
        message: message,
      );
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vente rapide'),
        actions: const [ModuleHelpButton(articleId: 'quick_sale')],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const Text(
            'Enregistrez un montant sans détail produit (pas d\'impact stock).',
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Montant (FCFA)',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<PaymentMethod>(
            value: _method,
            decoration: const InputDecoration(labelText: 'Paiement'),
            items: [
              PaymentMethod.cash,
              PaymentMethod.mtnMomo,
              PaymentMethod.moovMoney,
            ]
                .map(
                  (m) => DropdownMenuItem(value: m, child: Text(m.label)),
                )
                .toList(),
            onChanged: _submitting
                ? null
                : (v) {
                    if (v != null) setState(() => _method = v);
                  },
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? SaleFeedback.inlineLoader()
                : const Text('Enregistrer'),
          ),
        ),
      ),
    );
  }
}
