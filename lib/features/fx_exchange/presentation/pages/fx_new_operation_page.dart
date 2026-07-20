import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../domain/entities/fx_exchange_entities.dart';
import '../../domain/services/fx_calculation_service.dart';
import '../../domain/usecases/fx_exchange_usecases.dart';
import '../bloc/fx_exchange_bloc.dart';

class FxNewOperationPage extends StatefulWidget {
  const FxNewOperationPage({super.key});

  @override
  State<FxNewOperationPage> createState() => _FxNewOperationPageState();
}

class _FxNewOperationPageState extends State<FxNewOperationPage> {
  FxOperationType _type = FxOperationType.sell;
  String? _foreignCurrency;
  final _fromAmountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  FxOperationPreview? _preview;
  String? _previewError;
  bool _loadingPreview = false;
  int _previewRequestId = 0;

  @override
  void dispose() {
    _fromAmountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _fromCurrency(String foreign) =>
      _type == FxOperationType.sell ? fxBaseCurrency : foreign;

  String _toCurrency(String foreign) =>
      _type == FxOperationType.sell ? foreign : fxBaseCurrency;

  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<FxExchangeBloc>();
    final foreignCodes = bloc.state.shopCurrencies
        .where((c) => c.enabled && c.currencyCode != fxBaseCurrency)
        .map((c) => c.currencyCode)
        .toList();

    // Fallback catalogue si aucune devise boutique active.
    final options = foreignCodes.isNotEmpty
        ? foreignCodes
        : bloc.state.currencies
            .where((c) => c.code != fxBaseCurrency)
            .map((c) => c.code)
            .toList();

    final selectedForeign = _resolveForeign(options);
    final preview = _preview;

    final canAdjust = PermissionGuard.can(
      bloc.session.user.permissions,
      Permission.fxExchangeAdjust,
    );

    VoidCallback? onValidate;
    if (selectedForeign != null &&
        preview != null &&
        !bloc.state.isSubmitting &&
        !_loadingPreview) {
      onValidate = () {
        final fromAmount =
            int.tryParse(_fromAmountCtrl.text.replaceAll(' ', ''));
        if (fromAmount == null || fromAmount <= 0) return;

        bloc.add(
          FxCreateOperationRequested(
            allowNegativeBalance: canAdjust,
            input: CreateFxOperationInput(
              operationType: _type,
              fromCurrency: _fromCurrency(selectedForeign),
              fromAmount: fromAmount,
              toCurrency: _toCurrency(selectedForeign),
              toAmount: preview.toAmount,
              note: _noteCtrl.text.trim().isEmpty
                  ? null
                  : _noteCtrl.text.trim(),
            ),
          ),
        );
        Navigator.pop(context);
      };
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle opération')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          SegmentedButton<FxOperationType>(
            segments: const [
              ButtonSegment(
                value: FxOperationType.sell,
                label: Text('Vente devise'),
              ),
              ButtonSegment(
                value: FxOperationType.buy,
                label: Text('Achat devise'),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (values) {
              setState(() {
                _type = values.first;
                _preview = null;
                _previewError = null;
              });
              if (selectedForeign != null) {
                _schedulePreview(bloc.shopId, selectedForeign);
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          if (options.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Aucune devise étrangère active. Activez-en une dans '
                  'Configuration FX.',
                ),
              ),
            )
          else ...[
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: selectedForeign,
              decoration: InputDecoration(
                labelText: _type == FxOperationType.sell
                    ? 'Devise remise au client'
                    : 'Devise apportée par le client',
              ),
              items: options
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _foreignCurrency = v;
                  _preview = null;
                  _previewError = null;
                });
                _schedulePreview(bloc.shopId, v);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _fromAmountCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _type == FxOperationType.sell
                    ? 'Client apporte (FCFA)'
                    : 'Client apporte ($selectedForeign)',
              ),
              onChanged: (_) {
                if (selectedForeign != null) {
                  _schedulePreview(bloc.shopId, selectedForeign);
                }
              },
            ),
            if (_type == FxOperationType.buy) ...[
              const SizedBox(height: AppSpacing.sm),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Client reçoit'),
                subtitle: Text('FCFA (calcul automatique)'),
              ),
            ] else ...[
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Client reçoit'),
                subtitle: Text(selectedForeign ?? '—'),
              ),
            ],
          ],
          if (_loadingPreview)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_previewError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _previewError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ]
          else if (preview != null && selectedForeign != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Contre-valeur : ${formatAmount(preview.toAmount, _toCurrency(selectedForeign))}',
            ),
            Text('Marge estimée : ${formatFcfa(preview.marginFcfa)}'),
            Text(
              'Taux : ${const FxCalculationService().formatRateLabel(preview.quoteCurrency, FxRateFraction(numerator: preview.appliedRateNumerator, denominator: preview.appliedRateDenominator))}',
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(labelText: 'Note (optionnel)'),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: onValidate,
            child: const Text('Valider l\'opération'),
          ),
        ],
      ),
    );
  }

  String? _resolveForeign(List<String> options) {
    if (options.isEmpty) return null;
    if (_foreignCurrency != null && options.contains(_foreignCurrency)) {
      return _foreignCurrency;
    }
    return options.first;
  }

  void _schedulePreview(int shopId, String foreignCurrency) {
    final requestId = ++_previewRequestId;
    setState(() {
      _loadingPreview = true;
      _previewError = null;
    });

    Future<void>.delayed(const Duration(milliseconds: 300), () async {
      if (!mounted || requestId != _previewRequestId) return;

      final amount =
          int.tryParse(_fromAmountCtrl.text.replaceAll(' ', '')) ?? 0;
      if (amount <= 0) {
        setState(() {
          _preview = null;
          _previewError = null;
          _loadingPreview = false;
        });
        return;
      }

      try {
        ensureFxExchangeDependencies();
        final preview = await sl<PreviewFxOperation>()(
          shopId: shopId,
          input: CreateFxOperationInput(
            operationType: _type,
            fromCurrency: _fromCurrency(foreignCurrency),
            fromAmount: amount,
            toCurrency: _toCurrency(foreignCurrency),
            toAmount: 0,
          ),
        );
        if (!mounted || requestId != _previewRequestId) return;
        setState(() {
          _preview = preview;
          _previewError = null;
          _loadingPreview = false;
        });
      } catch (error) {
        if (!mounted || requestId != _previewRequestId) return;
        setState(() {
          _preview = null;
          _previewError = friendlyErrorMessage(error);
          _loadingPreview = false;
        });
      }
    });
  }
}
