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
      final fromCatalog = state.currencies
          .where((c) => enabledCodes.contains(c.code))
          .toList();
      if (fromCatalog.isNotEmpty) return fromCatalog;

      // Catalogue local vide / désync : afficher quand même les codes actifs.
      return enabledCodes
          .map(
            (code) => FxCurrency(
              code: code,
              label: code,
              symbol: code,
              minorUnit: 0,
              sortOrder: 0,
            ),
          )
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

  Future<void> _submit(BuildContext context, String selectedQuote) async {
    final bloc = context.read<FxExchangeBloc>();
    final sessionOpen = bloc.state.openSession != null;

    var applyMode = FxRateApplyMode.nextSession;
    if (sessionOpen) {
      final open = bloc.state.openSession!;
      if (open.isPendingClose) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Clôture en attente : le taux sera pour la prochaine session.',
            ),
          ),
        );
        applyMode = FxRateApplyMode.nextSession;
      } else {
      final choice = await showDialog<FxRateApplyMode>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nouveau taux disponible'),
          content: const Text(
            'Une session est ouverte.\n\n'
            'Appliquer maintenant : les prochaines opérations utilisent ce taux '
            '(les opérations déjà saisies gardent l’ancien).\n\n'
            'Prochaine session : la journée continue avec les taux actuels ; '
            'ce taux servira à la prochaine ouverture.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(ctx, FxRateApplyMode.nextSession),
              child: const Text('Prochaine session'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, FxRateApplyMode.now),
              child: const Text('Appliquer maintenant'),
            ),
          ],
        ),
      );
      if (choice == null || !context.mounted) return;
      applyMode = choice;
      }
    }

    bloc.add(
      FxCreateRateRequested(
        input: CreateFxRateInput(
          quoteCurrency: selectedQuote,
          buyRateNumerator: int.parse(_buyNum.text.trim()),
          buyRateDenominator: int.parse(_buyDen.text.trim()),
          sellRateNumerator: int.parse(_sellNum.text.trim()),
          sellRateDenominator: int.parse(_sellDen.text.trim()),
          applyMode: applyMode,
        ),
      ),
    );
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<FxExchangeBloc>().state;
    final options = _quoteOptions(state);
    final selectedQuote = _resolveSelectedQuote(options);
    final sessionOpen = state.openSession != null;

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
          if (sessionOpen)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline),
                    SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Session ouverte : les opérations utilisent les taux '
                        'gelés. Un nouveau taux peut s’appliquer maintenant '
                        'ou à la prochaine session.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (sessionOpen) const SizedBox(height: AppSpacing.md),
          if (options.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aucune devise étrangère active',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Activez au moins une devise (NGN, GHS, USD…) '
                      'dans la configuration du module.',
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: () => openFxSubPage(
                        context,
                        const FxSettingsPage(),
                      ),
                      icon: const Icon(Icons.settings_outlined),
                      label: const Text('Configurer les devises'),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Text(
              'Devise cotée',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              key: ValueKey(selectedQuote),
              initialValue: selectedQuote,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_exchange),
              ),
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
            const SizedBox(height: AppSpacing.lg),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Taux achat',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      'Client vend la devise à la boutique',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _rateRow(_buyDen, _buyNum),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Taux vente',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      'Client achète la devise à la boutique',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _rateRow(_sellDen, _sellNum),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              height: AppSizes.controlHeight,
              child: FilledButton(
                onPressed: state.isSubmitting || selectedQuote == null
                    ? null
                    : () => _submit(context, selectedQuote),
                child: state.isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        sessionOpen
                            ? 'Nouveau taux…'
                            : 'Enregistrer le taux',
                      ),
              ),
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
            decoration: const InputDecoration(
              labelText: 'Quantité devise',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text('='),
        ),
        Expanded(
          child: TextField(
            controller: numeratorCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'FCFA',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ],
    );
  }
}
