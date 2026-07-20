import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../domain/entities/fx_exchange_entities.dart';
import '../bloc/fx_exchange_bloc.dart';
import '../fx_exchange_navigation.dart';
import 'fx_settings_page.dart';

class FxRatesPage extends StatefulWidget {
  const FxRatesPage({super.key});

  @override
  State<FxRatesPage> createState() => _FxRatesPageState();
}

class _FxRatesPageState extends State<FxRatesPage> {
  final _buyNum = TextEditingController(text: '380');
  final _buyDen = TextEditingController(text: '1000');
  final _sellNum = TextEditingController(text: '400');
  final _sellDen = TextEditingController(text: '1000');
  String? _quoteCurrency;
  bool _selectionInitialized = false;

  @override
  void dispose() {
    _buyNum.dispose();
    _buyDen.dispose();
    _sellNum.dispose();
    _sellDen.dispose();
    super.dispose();
  }

  List<FxCurrency> _quoteOptions(FxExchangeState state) {
    final enabledCodes = state.shopCurrencies
        .where((c) => c.enabled && c.currencyCode != fxBaseCurrency)
        .map((c) => c.currencyCode)
        .toSet();

    if (enabledCodes.isNotEmpty) {
      return state.currencies
          .where((c) => enabledCodes.contains(c.code))
          .toList();
    }

    return state.currencies.where((c) => c.code != fxBaseCurrency).toList();
  }

  String? _resolveSelectedQuote(List<FxCurrency> options) {
    if (options.isEmpty) return null;
    if (_quoteCurrency != null &&
        options.any((c) => c.code == _quoteCurrency)) {
      return _quoteCurrency;
    }
    return options.first.code;
  }

  void _applyLatestRateForQuote(FxExchangeState state, String quoteCode) {
    FxRateSnapshot? rate;
    for (final r in state.latestRates) {
      if (r.quoteCurrency == quoteCode) {
        rate = r;
        break;
      }
    }
    if (rate == null) return;

    _buyNum.text = '${rate.buyRateNumerator}';
    _buyDen.text = '${rate.buyRateDenominator}';
    _sellNum.text = '${rate.sellRateNumerator}';
    _sellDen.text = '${rate.sellRateDenominator}';
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FxExchangeBloc>().state;
    final options = _quoteOptions(state);
    final selectedQuote = _resolveSelectedQuote(options);

    if (!_selectionInitialized && selectedQuote != null) {
      _quoteCurrency = selectedQuote;
      _applyLatestRateForQuote(state, selectedQuote);
      _selectionInitialized = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Taux du jour')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (options.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aucune devise étrangère active.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Activez au moins une devise (NGN, GHS, USD…) '
                      'dans la configuration du module.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () => openFxSubPage(
                        context,
                        const FxSettingsPage(),
                      ),
                      child: const Text('Configurer les devises'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            DropdownButtonFormField<String>(
              key: ValueKey(selectedQuote),
              initialValue: selectedQuote,
              decoration: const InputDecoration(labelText: 'Devise cotée'),
              items: options
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.code,
                      child: Text('${c.label} (${c.code})'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _quoteCurrency = value;
                  _applyLatestRateForQuote(state, value);
                });
              },
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Taux achat (client vend la devise)'),
            _rateRow(_buyDen, _buyNum),
            const SizedBox(height: AppSpacing.md),
            const Text('Taux vente (client achète la devise)'),
            _rateRow(_sellDen, _sellNum),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: state.isSubmitting || selectedQuote == null
                  ? null
                  : () {
                      context.read<FxExchangeBloc>().add(
                            FxCreateRateRequested(
                              input: CreateFxRateInput(
                                quoteCurrency: selectedQuote,
                                buyRateNumerator:
                                    int.parse(_buyNum.text.trim()),
                                buyRateDenominator:
                                    int.parse(_buyDen.text.trim()),
                                sellRateNumerator:
                                    int.parse(_sellNum.text.trim()),
                                sellRateDenominator:
                                    int.parse(_sellDen.text.trim()),
                              ),
                            ),
                          );
                      Navigator.pop(context);
                    },
              child: state.isSubmitting
                  ? const CircularProgressIndicator()
                  : const Text('Enregistrer le taux'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rateRow(
    TextEditingController denominatorCtrl,
    TextEditingController numeratorCtrl,
  ) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: denominatorCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Unités devise'),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('='),
        ),
        Expanded(
          child: TextField(
            controller: numeratorCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'FCFA'),
          ),
        ),
      ],
    );
  }
}
