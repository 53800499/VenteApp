import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/failures.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/sale_entities.dart';
import '../../domain/usecases/sale_usecases.dart';
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

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
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

      final sale = await sl<CreateQuickSale>()(
        session: widget.session,
        input: CreateQuickSaleInput(
          totalAmount: amount,
          payment: payment,
        ),
      );

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
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Échec de la vente rapide.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vente rapide')),
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
            onChanged: (v) {
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
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enregistrer'),
          ),
        ),
      ),
    );
  }
}
