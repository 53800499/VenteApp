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
  int _syncedCatalogCount = -1;
  final _thresholdCtrl = TextEditingController();
  bool _thresholdSynced = false;

  @override
  void dispose() {
    _thresholdCtrl.dispose();
    super.dispose();
  }

  void _syncFromState(FxExchangeState state) {
    // Base = catalogue ; overlay = préférences boutique.
    _enabled = {
      for (final c in state.currencies)
        c.code: c.code == fxBaseCurrency || c.code == 'NGN',
    };
    _sortOrder = {
      for (final c in state.currencies) c.code: c.sortOrder,
    };
    for (final sc in state.shopCurrencies) {
      _enabled[sc.currencyCode] = sc.enabled;
      _sortOrder[sc.currencyCode] = sc.sortOrder;
    }
    if (!_thresholdSynced) {
      _thresholdCtrl.text = '${state.customerRequiredAboveFcfa}';
      _thresholdSynced = true;
    }
    _syncedCatalogCount = state.currencies.length;
    _localStateReady = true;
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<FxExchangeBloc>();
    final state = bloc.state;

    if (state.currencies.isNotEmpty &&
        _syncedCatalogCount != state.currencies.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _syncFromState(state));
      });
    } else if (!_thresholdSynced && state.status == FxExchangeStatus.ready) {
      _thresholdCtrl.text = '${state.customerRequiredAboveFcfa}';
      _thresholdSynced = true;
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
          SwitchListTile(
            title: const Text('Change en écran d’accueil'),
            subtitle: const Text(
              'Onglet Change en racine (idéal si vous n’utilisez que ce module). '
              'Clients et Plus restent accessibles.',
            ),
            value: state.primaryWorkspace,
            onChanged: state.isSubmitting
                ? null
                : (value) {
                    if (value == state.primaryWorkspace) return;
                    bloc.add(
                      FxPrimaryWorkspaceSaveRequested(enabled: value),
                    );
                  },
          ),
          const Divider(),
          Text(
            'Devises actives',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (state.currencies.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Aucune devise disponible pour le moment.'),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: state.isRefreshing
                        ? null
                        : () => bloc.add(const FxExchangeRefreshRequested()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualiser'),
                  ),
                ],
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
          Text(
            'Client obligatoire',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _thresholdCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Seuil FCFA',
              helperText:
                  'Client obligatoire si montant FCFA ≥ ce seuil. 0 = jamais.',
              border: OutlineInputBorder(),
            ),
          ),
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

                    final threshold = int.tryParse(
                          _thresholdCtrl.text.replaceAll(' ', ''),
                        ) ??
                        0;
                    if (threshold != state.customerRequiredAboveFcfa) {
                      bloc.add(
                        FxSaveCustomerThresholdRequested(
                          amountFcfa: threshold < 0 ? 0 : threshold,
                        ),
                      );
                    }
                    Navigator.pop(context);
                  },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
