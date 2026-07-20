import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../domain/entities/fx_exchange_entities.dart';
import '../bloc/fx_exchange_bloc.dart';

class FxSettingsPage extends StatefulWidget {
  const FxSettingsPage({super.key});

  @override
  State<FxSettingsPage> createState() => _FxSettingsPageState();
}

class _FxSettingsPageState extends State<FxSettingsPage> {
  Map<String, bool> _enabled = {};
  Map<String, int> _sortOrder = {};
  bool _localStateReady = false;

  void _syncFromState(FxExchangeState state) {
    if (state.shopCurrencies.isNotEmpty) {
      _enabled = {
        for (final sc in state.shopCurrencies) sc.currencyCode: sc.enabled,
      };
      _sortOrder = {
        for (final sc in state.shopCurrencies) sc.currencyCode: sc.sortOrder,
      };
    } else {
      // Défauts boutique : FCFA + NGN actifs.
      _enabled = {
        for (final c in state.currencies)
          c.code: c.code == fxBaseCurrency || c.code == 'NGN',
      };
      _sortOrder = {
        for (final c in state.currencies) c.code: c.sortOrder,
      };
    }
    _localStateReady = true;
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<FxExchangeBloc>();
    final state = bloc.state;

    if (!_localStateReady &&
        (state.shopCurrencies.isNotEmpty || state.currencies.isNotEmpty)) {
      _syncFromState(state);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configuration FX')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          SwitchListTile(
            title: const Text('Module Bureau de change'),
            subtitle: const Text('Activer ou désactiver pour cette boutique'),
            value: state.moduleEnabled,
            onChanged: state.isSubmitting
                ? null
                : (value) {
                    if (value == state.moduleEnabled) return;
                    bloc.add(FxModuleToggleRequested(enabled: value));
                  },
          ),
          const Divider(),
          Text(
            'Devises actives',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (state.currencies.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(
                'Aucune devise disponible. Fermez puis rouvrez cet écran, '
                'ou appuyez sur Actualiser sur le tableau de bord.',
              ),
            )
          else
            ...state.currencies.map((currency) {
              final isXof = currency.code == fxBaseCurrency;
              return SwitchListTile(
                title: Text('${currency.label} (${currency.code})'),
                value: _enabled[currency.code] ?? false,
                onChanged: isXof
                    ? null
                    : (value) =>
                        setState(() => _enabled[currency.code] = value),
              );
            }),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: state.isSubmitting || state.currencies.isEmpty
                ? null
                : () {
                    final items = state.currencies
                        .map(
                          (c) => UpsertFxShopCurrencyInput(
                            currencyCode: c.code,
                            enabled: c.code == fxBaseCurrency
                                ? true
                                : (_enabled[c.code] ?? false),
                            sortOrder: _sortOrder[c.code] ?? c.sortOrder,
                          ),
                        )
                        .toList();
                    bloc.add(FxSaveCurrenciesRequested(items: items));
                    Navigator.pop(context);
                  },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
