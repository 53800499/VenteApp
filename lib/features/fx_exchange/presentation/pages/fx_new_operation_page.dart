import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../customers/domain/entities/customer_entities.dart';
import '../../../customers/domain/usecases/customer_usecases.dart';
import '../../../voice_input/domain/entities/voice_navigation_seeds.dart';
import '../../domain/entities/fx_exchange_entities.dart';
import '../../domain/services/fx_calculation_service.dart';
import '../../domain/usecases/fx_exchange_usecases.dart';
import '../bloc/fx_exchange_bloc.dart';

class FxNewOperationPage extends StatefulWidget {
  const FxNewOperationPage({super.key, this.voiceSeed});

  final VoiceFxSeed? voiceSeed;

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
  List<Customer> _customers = const [];
  int? _selectedCustomerId;
  bool _customersLoaded = false;
  bool _creatingCustomer = false;

  @override
  void initState() {
    super.initState();
    final seed = widget.voiceSeed;
    if (seed != null) {
      if (seed.operationTypeCode == 'buy') {
        _type = FxOperationType.buy;
      }
      _foreignCurrency = seed.foreignCurrency;
      if (seed.fromAmount != null) {
        _fromAmountCtrl.text = '${seed.fromAmount}';
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCustomers());
  }

  Future<void> _loadCustomers() async {
    try {
      final session = context.read<FxExchangeBloc>().session;
      final customers = await sl<ListCustomers>()(session: session);
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _customersLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _customersLoaded = true);
    }
  }

  Future<void> _showCreateCustomerSheet() async {
    final result = await showModalBottomSheet<_FxNewCustomerSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => const _FxCreateCustomerSheet(),
    );
    if (result == null || !mounted) return;

    setState(() => _creatingCustomer = true);
    try {
      final session = context.read<FxExchangeBloc>().session;
      final customer = await sl<CreateCustomer>().callFull(
        session: session,
        input: CreateCustomerInput(
          name: result.name,
          phone: result.phone,
        ),
      );
      if (!mounted) return;
      setState(() {
        _customers = [customer, ..._customers.where((c) => c.id != customer.id)];
        _selectedCustomerId = customer.id;
        _creatingCustomer = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _creatingCustomer = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
      );
    }
  }

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

  int? _fcfaAmount(FxOperationPreview preview) {
    if (_type == FxOperationType.sell) {
      return int.tryParse(_fromAmountCtrl.text.replaceAll(' ', ''));
    }
    return preview.toAmount;
  }

  bool _customerRequired(FxExchangeState state, FxOperationPreview preview) {
    final threshold = state.customerRequiredAboveFcfa;
    if (threshold <= 0) return false;
    final fcfa = _fcfaAmount(preview);
    return fcfa != null && fcfa >= threshold;
  }

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
    final requiresCustomer =
        preview != null && _customerRequired(bloc.state, preview);

    final canAdjust = PermissionGuard.can(
      bloc.session.user.permissions,
      Permission.fxExchangeAdjust,
    );

    VoidCallback? onValidate;
    if (selectedForeign != null &&
        preview != null &&
        !bloc.state.isSubmitting &&
        !_loadingPreview &&
        (!requiresCustomer || _selectedCustomerId != null)) {
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
              customerId: _selectedCustomerId,
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
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  'Type d’opération',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<FxOperationType>(
                  segments: const [
                    ButtonSegment(
                      value: FxOperationType.sell,
                      label: Text('Vente'),
                      icon: Icon(Icons.south_west, size: 16),
                    ),
                    ButtonSegment(
                      value: FxOperationType.buy,
                      label: Text('Achat'),
                      icon: Icon(Icons.north_east, size: 16),
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
                const SizedBox(height: AppSpacing.lg),
                if (options.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        'Aucune devise étrangère active. Activez-en une dans '
                        'Configuration FX.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  )
                else ...[
                  Text(
                    'Montants',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: selectedForeign,
                    decoration: InputDecoration(
                      labelText: _type == FxOperationType.sell
                          ? 'Devise remise au client'
                          : 'Devise apportée par le client',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.currency_exchange),
                    ),
                    items: options
                        .map(
                          (c) => DropdownMenuItem(value: c, child: Text(c)),
                        )
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
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.payments_outlined),
                    ),
                    onChanged: (_) {
                      if (selectedForeign != null) {
                        _schedulePreview(bloc.shopId, selectedForeign);
                      }
                    },
                  ),
                ],
                if (_loadingPreview)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_previewError != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Text(
                        _previewError!,
                        style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                ] else if (preview != null && selectedForeign != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.45),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Résultat',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Client reçoit · '
                            '${formatAmount(preview.toAmount, _toCurrency(selectedForeign))}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Marge estimée · ${formatFcfa(preview.marginFcfa)}',
                          ),
                          Text(
                            'Taux · ${const FxCalculationService().formatRateLabel(preview.quoteCurrency, FxRateFraction(numerator: preview.appliedRateNumerator, denominator: preview.appliedRateDenominator))}',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Text(
                      'Client',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _creatingCustomer
                          ? null
                          : _showCreateCustomerSheet,
                      icon: _creatingCustomer
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_outlined),
                      label: Text(
                        _creatingCustomer ? 'Création…' : 'Nouveau',
                      ),
                    ),
                  ],
                ),
                DropdownButtonFormField<int?>(
                  // ignore: deprecated_member_use
                  value: _selectedCustomerId,
                  decoration: InputDecoration(
                    labelText: requiresCustomer
                        ? 'Client (obligatoire)'
                        : 'Client (optionnel)',
                    helperText: requiresCustomer
                        ? 'Montant FCFA ≥ seuil boutique '
                            '(${formatFcfa(bloc.state.customerRequiredAboveFcfa)})'
                        : bloc.state.customerRequiredAboveFcfa > 0
                            ? 'Obligatoire à partir de '
                                '${formatFcfa(bloc.state.customerRequiredAboveFcfa)}'
                            : null,
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  items: [
                    DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        requiresCustomer
                            ? 'Sélectionner un client…'
                            : 'Sans client',
                      ),
                    ),
                    if (_customersLoaded && _customers.isEmpty)
                      const DropdownMenuItem<int?>(
                        value: null,
                        enabled: false,
                        child: Text('Aucun client en base'),
                      ),
                    ..._customers.map(
                      (c) => DropdownMenuItem<int?>(
                        value: c.id,
                        child: Text(
                          c.phone != null
                              ? '${c.name} (${c.phone})'
                              : c.name,
                        ),
                      ),
                    ),
                  ],
                  onChanged: _creatingCustomer
                      ? null
                      : (id) => setState(() => _selectedCustomerId = id),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Note (optionnel)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
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
                  onPressed: onValidate,
                  child: const Text('Valider l’opération'),
                ),
              ),
            ),
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
    final sessionId = context.read<FxExchangeBloc>().state.openSession?.id;
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
          sessionId: sessionId,
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

class _FxNewCustomerSheetResult {
  const _FxNewCustomerSheetResult({required this.name, this.phone});

  final String name;
  final String? phone;
}

class _FxCreateCustomerSheet extends StatefulWidget {
  const _FxCreateCustomerSheet();

  @override
  State<_FxCreateCustomerSheet> createState() => _FxCreateCustomerSheetState();
}

class _FxCreateCustomerSheetState extends State<_FxCreateCustomerSheet> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.length < 2) return;
    final phone = _phoneController.text.trim();
    Navigator.pop(
      context,
      _FxNewCustomerSheetResult(
        name: name,
        phone: phone.isEmpty ? null : phone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Nouveau client',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nom *',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.words,
            autofocus: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Téléphone (recommandé)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: _submit,
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
