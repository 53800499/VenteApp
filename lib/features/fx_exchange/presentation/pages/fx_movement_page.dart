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

    return Scaffold(
      appBar: AppBar(title: const Text('Mouvement manuel')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          DropdownButtonFormField<FxMovementType>(
            value: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [
              const DropdownMenuItem(
                value: FxMovementType.deposit,
                child: Text('Dépôt'),
              ),
              const DropdownMenuItem(
                value: FxMovementType.withdrawal,
                child: Text('Retrait'),
              ),
              if (canAdjust)
                const DropdownMenuItem(
                  value: FxMovementType.adjustment,
                  child: Text('Ajustement'),
                ),
            ],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          DropdownButtonFormField<String>(
            value: _currencyCode,
            decoration: const InputDecoration(labelText: 'Devise'),
            items: codes
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _currencyCode = v),
          ),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Montant'),
          ),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              labelText: _type == FxMovementType.adjustment
                  ? 'Justification (obligatoire)'
                  : 'Note',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: bloc.state.isSubmitting || _currencyCode == null
                ? null
                : () {
                    final amount =
                        int.tryParse(_amountCtrl.text.replaceAll(' ', ''));
                    if (amount == null || amount <= 0) return;

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
        ],
      ),
    );
  }
}
