import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../domain/entities/fx_exchange_entities.dart';
import '../bloc/fx_exchange_bloc.dart';

class FxMovementPage extends StatefulWidget {
  const FxMovementPage({super.key});

  @override
  State<FxMovementPage> createState() => _FxMovementPageState();
}

class _FxMovementPageState extends State<FxMovementPage> {
  FxMovementType _type = FxMovementType.deposit;
  String? _currencyCode;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<FxExchangeBloc>();
    final codes = bloc.state.shopCurrencies
        .where((c) => c.enabled)
        .map((c) => c.currencyCode)
        .toList();
    _currencyCode ??= codes.isNotEmpty ? codes.first : fxBaseCurrency;

    final canAdjust = PermissionGuard.can(
      bloc.session.user.permissions,
      Permission.fxExchangeAdjust,
    );

    final amount = int.tryParse(_amountCtrl.text.replaceAll(' ', ''));
    final canSubmit = !bloc.state.isSubmitting &&
        _currencyCode != null &&
        amount != null &&
        amount > 0 &&
        (_type != FxMovementType.adjustment ||
            _noteCtrl.text.trim().isNotEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('Mouvement manuel')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  'Type',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<FxMovementType>(
                  segments: [
                    const ButtonSegment(
                      value: FxMovementType.deposit,
                      label: Text('Dépôt'),
                      icon: Icon(Icons.add, size: 16),
                    ),
                    const ButtonSegment(
                      value: FxMovementType.withdrawal,
                      label: Text('Retrait'),
                      icon: Icon(Icons.remove, size: 16),
                    ),
                    if (canAdjust)
                      const ButtonSegment(
                        value: FxMovementType.adjustment,
                        label: Text('Ajust.'),
                        icon: Icon(Icons.tune, size: 16),
                      ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (values) {
                    setState(() => _type = values.first);
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String>(
                  // ignore: deprecated_member_use
                  value: _currencyCode,
                  decoration: const InputDecoration(
                    labelText: 'Devise',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_exchange),
                  ),
                  items: codes
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _currencyCode = v),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Montant',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _noteCtrl,
                  decoration: InputDecoration(
                    labelText: _type == FxMovementType.adjustment
                        ? 'Justification (obligatoire)'
                        : 'Note (optionnel)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.notes_outlined),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: SizedBox(
                width: double.infinity,
                height: AppSizes.controlHeight,
                child: FilledButton(
                  onPressed: !canSubmit
                      ? null
                      : () {
                          bloc.add(
                            FxCreateMovementRequested(
                              allowNegativeBalance: canAdjust,
                              input: CreateFxMovementInput(
                                currencyCode: _currencyCode!,
                                movementType: _type,
                                amount: amount,
                                note: _noteCtrl.text.trim().isEmpty
                                    ? null
                                    : _noteCtrl.text.trim(),
                              ),
                            ),
                          );
                          Navigator.pop(context);
                        },
                  child: const Text('Enregistrer'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
