import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../core/storage/form_draft_storage.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/inventory_entities.dart';
import '../../domain/usecases/inventory_usecases.dart';
import '../../../settings/data/datasources/local/settings_local_datasource.dart';
import '../widgets/inventory_feedback.dart';
import '../../../calculators/domain/entities/calculator_entities.dart';
import '../../../calculators/domain/repositories/calculators_repository.dart';
import '../../../calculators/presentation/utils/calculator_form_validators.dart';
import '../../../../app/theme/app_colors.dart';

class ProductFormPage extends StatefulWidget {
  const ProductFormPage({
    super.key,
    required this.session,
    this.product,
  });

  final AuthSession session;
  final Product? product;

  bool get isEditing => product != null;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _priceSellController = TextEditingController();
  final _priceBuyController = TextEditingController();
  final _priceSemiWholesaleController = TextEditingController();
  final _priceWholesaleController = TextEditingController();
  final _quantityController = TextEditingController(text: '0');
  final _alertThresholdController = TextEditingController();

  // Calculators configuration inputs
  String? _calculatorType;
  final _tileLengthController = TextEditingController(text: '60');
  final _tileWidthController = TextEditingController(text: '60');
  final _piecesPerBoxController = TextEditingController(text: '1');
  final _wastePercentController = TextEditingController(text: '10');

  final _coverageController = TextEditingController(text: '10');
  final _coatsController = TextEditingController(text: '2');
  final _volumeController = TextEditingController(text: '15');

  final _cementDosageController = TextEditingController(text: '350');
  final _bagWeightController = TextEditingController(text: '50');
  final _sandController = TextEditingController(text: '400');
  final _gravelController = TextEditingController(text: '800');

  List<ProductCategory> _categories = [];
  int? _categoryId;
  bool _isLoading = false;
  bool _pricingTiersEnabled = false;
  bool _calculatorsModuleEnabled = false;
  String? _errorMessage;
  bool _draftRestored = false;
  bool _submittedSuccessfully = false;
  late final String _draftKey;

  @override
  void initState() {
    super.initState();
    _draftKey = FormDraftStorage.productKey(
      widget.session.shop.id,
      productId: widget.product?.id,
    );
    final product = widget.product;
    if (product != null) {
      _nameController.text = product.name;
      _skuController.text = product.sku ?? '';
      _priceSellController.text = '${product.priceSell}';
      if (product.priceSemiWholesale != null) {
        _priceSemiWholesaleController.text = '${product.priceSemiWholesale}';
      }
      if (product.priceWholesale != null) {
        _priceWholesaleController.text = '${product.priceWholesale}';
      }
      if (product.priceBuy != null) {
        _priceBuyController.text = '${product.priceBuy}';
      }
      _alertThresholdController.text = '${product.alertThreshold}';
      _categoryId = product.categoryId;
    }
    _loadCategories();
    _loadPricingSettings();
    _loadCalculatorsModuleStatus();
    _loadCalculatorConfig();
    unawaited(_restoreDraft());
  }

  bool _hasDraftContent() {
    return _nameController.text.trim().isNotEmpty ||
        _skuController.text.trim().isNotEmpty ||
        _priceSellController.text.trim().isNotEmpty ||
        _priceBuyController.text.trim().isNotEmpty ||
        _priceSemiWholesaleController.text.trim().isNotEmpty ||
        _priceWholesaleController.text.trim().isNotEmpty ||
        (_quantityController.text.trim().isNotEmpty &&
            _quantityController.text.trim() != '0') ||
        _alertThresholdController.text.trim().isNotEmpty;
  }

  Future<void> _persistDraftIfNeeded() async {
    if (!_hasDraftContent()) {
      await sl<FormDraftStorage>().clear(_draftKey);
      return;
    }
    await sl<FormDraftStorage>().save(_draftKey, {
      'name': _nameController.text,
      'sku': _skuController.text,
      'priceSell': _priceSellController.text,
      'priceBuy': _priceBuyController.text,
      'priceSemiWholesale': _priceSemiWholesaleController.text,
      'priceWholesale': _priceWholesaleController.text,
      'quantity': _quantityController.text,
      'alertThreshold': _alertThresholdController.text,
      'categoryId': _categoryId,
      'calculatorType': _calculatorType,
      'calculatorMeta': {
        'tileLength': _tileLengthController.text,
        'tileWidth': _tileWidthController.text,
        'piecesPerBox': _piecesPerBoxController.text,
        'wastePercent': _wastePercentController.text,
        'coverage': _coverageController.text,
        'coats': _coatsController.text,
        'volume': _volumeController.text,
        'cementDosage': _cementDosageController.text,
        'bagWeight': _bagWeightController.text,
        'sand': _sandController.text,
        'gravel': _gravelController.text,
      },
    });
  }

  Future<void> _restoreDraft() async {
    final draft = await sl<FormDraftStorage>().read(_draftKey);
    if (!mounted || draft == null) return;
    if (_nameController.text.trim().isEmpty && draft['name'] is String) {
      _nameController.text = draft['name'] as String;
    }
    if (draft['sku'] is String) _skuController.text = draft['sku'] as String;
    if (draft['priceSell'] is String) {
      _priceSellController.text = draft['priceSell'] as String;
    }
    if (draft['priceBuy'] is String) {
      _priceBuyController.text = draft['priceBuy'] as String;
    }
    if (draft['priceSemiWholesale'] is String) {
      _priceSemiWholesaleController.text = draft['priceSemiWholesale'] as String;
    }
    if (draft['priceWholesale'] is String) {
      _priceWholesaleController.text = draft['priceWholesale'] as String;
    }
    if (draft['quantity'] is String) {
      _quantityController.text = draft['quantity'] as String;
    }
    if (draft['alertThreshold'] is String) {
      _alertThresholdController.text = draft['alertThreshold'] as String;
    }
    if (draft['categoryId'] is int) _categoryId = draft['categoryId'] as int;
    if (draft['calculatorType'] is String) {
      _calculatorType = draft['calculatorType'] as String;
    }
    void applyMeta(String key, TextEditingController controller) {
      final meta = draft['calculatorMeta'];
      if (meta is Map && meta[key] is String) {
        controller.text = meta[key] as String;
      }
    }
    applyMeta('tileLength', _tileLengthController);
    applyMeta('tileWidth', _tileWidthController);
    applyMeta('piecesPerBox', _piecesPerBoxController);
    applyMeta('wastePercent', _wastePercentController);
    applyMeta('coverage', _coverageController);
    applyMeta('coats', _coatsController);
    applyMeta('volume', _volumeController);
    applyMeta('cementDosage', _cementDosageController);
    applyMeta('bagWeight', _bagWeightController);
    applyMeta('sand', _sandController);
    applyMeta('gravel', _gravelController);

    if (_nameController.text.trim().isNotEmpty && mounted) {
      setState(() => _draftRestored = true);
    }
  }

  Future<void> _loadCalculatorsModuleStatus() async {
    try {
      final enabled = await sl<CalculatorsRepository>().isModuleEnabled(
        shopId: widget.session.shop.id,
      );
      if (mounted) {
        setState(() {
          _calculatorsModuleEnabled = enabled;
          if (!enabled) _calculatorType = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _calculatorsModuleEnabled = false;
          _calculatorType = null;
        });
      }
    }
  }

  Future<void> _loadPricingSettings() async {
    final config =
        await sl<SettingsLocalDatasource>().loadConfiguration(widget.session.shop.id);
    if (mounted) {
      setState(() => _pricingTiersEnabled = config.commerce.pricingTiersEnabled);
    }
  }

  Future<void> _loadCalculatorConfig() async {
    final prod = widget.product;
    if (prod == null) return;

    try {
      final repo = sl<CalculatorsRepository>();
      final config = await repo.getProductConfig(
        shopId: widget.session.shop.id,
        productId: prod.id,
      );
      if (config != null && mounted) {
        setState(() {
          _calculatorType = config.calculatorType;
          final meta = config.metadata;
          if (config.calculatorType == 'tile') {
            _tileLengthController.text = '${meta['tileLengthCm'] ?? '60'}';
            _tileWidthController.text = '${meta['tileWidthCm'] ?? '60'}';
            _piecesPerBoxController.text = '${meta['piecesPerBox'] ?? '1'}';
            _wastePercentController.text = '${meta['wastePercent'] ?? '10'}';
          } else if (config.calculatorType == 'paint') {
            _coverageController.text = '${meta['coveragePerLiter'] ?? '10'}';
            _coatsController.text = '${meta['coatsCount'] ?? '2'}';
            _volumeController.text = '${meta['bucketVolume'] ?? '15'}';
            _wastePercentController.text = '${meta['wastePercent'] ?? '5'}';
          } else if (config.calculatorType == 'concrete') {
            _cementDosageController.text = '${meta['cementDosage'] ?? '350'}';
            _bagWeightController.text = '${meta['bagWeight'] ?? '50'}';
            _sandController.text = '${meta['sandProportion'] ?? '400'}';
            _gravelController.text = '${meta['gravelProportion'] ?? '800'}';
            _wastePercentController.text = '${meta['wastePercent'] ?? '5'}';
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCategories() async {
    final categories =
        await sl<ListCategories>()(shopId: widget.session.shop.id);
    setState(() {
      _categories = categories;
      _categoryId ??= categories.firstOrNull?.id;
    });
  }

  @override
  void dispose() {
    if (!_submittedSuccessfully) {
      unawaited(_persistDraftIfNeeded());
    }
    _nameController.dispose();
    _skuController.dispose();
    _priceSellController.dispose();
    _priceSemiWholesaleController.dispose();
    _priceWholesaleController.dispose();
    _priceBuyController.dispose();
    _quantityController.dispose();
    _alertThresholdController.dispose();

    _tileLengthController.dispose();
    _tileWidthController.dispose();
    _piecesPerBoxController.dispose();
    _wastePercentController.dispose();

    _coverageController.dispose();
    _coatsController.dispose();
    _volumeController.dispose();

    _cementDosageController.dispose();
    _bagWeightController.dispose();
    _sandController.dispose();
    _gravelController.dispose();

    super.dispose();
  }

  int? _parseInt(String value) => int.tryParse(value.trim());

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) {
      setState(() => _errorMessage = 'Sélectionnez une catégorie.');
      return;
    }

    final isEdit = widget.isEditing;
    final confirmed = await InventoryFeedback.confirm(
      context: context,
      title: isEdit ? 'Enregistrer les modifications' : 'Créer le produit',
      message: isEdit
          ? 'Mettre à jour « ${_nameController.text.trim()} » ?'
          : 'Créer le produit « ${_nameController.text.trim()} » ?',
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      int productId;
      if (isEdit) {
        final prod = await sl<UpdateProduct>()(
          shopId: widget.session.shop.id,
          productId: widget.product!.id,
          input: UpdateProductInput(
            name: _nameController.text.trim(),
            categoryId: _categoryId,
            sku: _skuController.text.trim(),
            priceSell: _parseInt(_priceSellController.text),
            priceBuy: _priceBuyController.text.trim().isEmpty
                ? null
                : _parseInt(_priceBuyController.text),
            priceSemiWholesale: _pricingTiersEnabled &&
                    _priceSemiWholesaleController.text.trim().isNotEmpty
                ? _parseInt(_priceSemiWholesaleController.text)
                : null,
            priceWholesale: _pricingTiersEnabled &&
                    _priceWholesaleController.text.trim().isNotEmpty
                ? _parseInt(_priceWholesaleController.text)
                : null,
            clearPriceBuy: _priceBuyController.text.trim().isEmpty,
            alertThreshold: _alertThresholdController.text.trim().isEmpty
                ? null
                : _parseInt(_alertThresholdController.text),
          ),
        );
        productId = prod.id;
      } else {
        final prod = await sl<CreateProduct>()(
          shopId: widget.session.shop.id,
          userId: widget.session.user.id,
          input: CreateProductInput(
            name: _nameController.text.trim(),
            categoryId: _categoryId!,
            sku: _skuController.text.trim().isEmpty
                ? null
                : _skuController.text.trim(),
            priceSell: _parseInt(_priceSellController.text)!,
            priceBuy: _priceBuyController.text.trim().isEmpty
                ? null
                : _parseInt(_priceBuyController.text),
            priceSemiWholesale: _pricingTiersEnabled &&
                    _priceSemiWholesaleController.text.trim().isNotEmpty
                ? _parseInt(_priceSemiWholesaleController.text)
                : null,
            priceWholesale: _pricingTiersEnabled &&
                    _priceWholesaleController.text.trim().isNotEmpty
                ? _parseInt(_priceWholesaleController.text)
                : null,
            initialQuantity: _parseInt(_quantityController.text) ?? 0,
            alertThreshold: _alertThresholdController.text.trim().isEmpty
                ? null
                : _parseInt(_alertThresholdController.text),
          ),
        );
        productId = prod.id;
      }

      // Save business calculator link if module actif et type sélectionné
      if (_calculatorsModuleEnabled && _calculatorType != null) {
        Map<String, dynamic> metadata = {};
        if (_calculatorType == 'tile') {
          metadata = {
            'tileLengthCm': double.tryParse(_tileLengthController.text) ?? 60.0,
            'tileWidthCm': double.tryParse(_tileWidthController.text) ?? 60.0,
            'piecesPerBox': int.tryParse(_piecesPerBoxController.text) ?? 1,
            'wastePercent': double.tryParse(_wastePercentController.text) ?? 10.0,
          };
        } else if (_calculatorType == 'paint') {
          metadata = {
            'coveragePerLiter': double.tryParse(_coverageController.text) ?? 10.0,
            'coatsCount': int.tryParse(_coatsController.text) ?? 2,
            'bucketVolume': double.tryParse(_volumeController.text) ?? 15.0,
            'wastePercent': double.tryParse(_wastePercentController.text) ?? 5.0,
          };
        } else if (_calculatorType == 'concrete') {
          metadata = {
            'cementDosage': double.tryParse(_cementDosageController.text) ?? 350.0,
            'bagWeight': double.tryParse(_bagWeightController.text) ?? 50.0,
            'sandProportion': double.tryParse(_sandController.text) ?? 400.0,
            'gravelProportion': double.tryParse(_gravelController.text) ?? 800.0,
            'wastePercent': double.tryParse(_wastePercentController.text) ?? 5.0,
          };
        }

        await sl<CalculatorsRepository>().saveProductConfig(
          config: CalculatorProductData(
            id: 0,
            shopId: widget.session.shop.id,
            productId: productId,
            calculatorType: _calculatorType!,
            metadata: metadata,
            createdAt: 0,
            updatedAt: 0,
          ),
        );
      }

      if (!mounted) return;
      await InventoryFeedback.showSuccess(
        context: context,
        title: isEdit ? 'Produit mis à jour' : 'Produit créé',
        message: '« ${_nameController.text.trim()} » a été enregistré.',
      );
      if (mounted) {
        _submittedSuccessfully = true;
        await sl<FormDraftStorage>().clear(_draftKey);
        Navigator.of(context).pop(true);
      }
    } on Failure catch (e) {
      if (mounted) {
        await InventoryFeedback.showErrorDialog(
          context,
          title: 'Enregistrement impossible',
          message: e.message,
        );
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
        await _persistDraftIfNeeded();
      }
    } catch (_) {
      if (mounted) {
        const message = 'Enregistrement impossible.';
        await InventoryFeedback.showErrorDialog(
          context,
          title: 'Enregistrement impossible',
          message: message,
        );
        setState(() {
          _errorMessage = message;
          _isLoading = false;
        });
        await _persistDraftIfNeeded();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Modifier le produit' : 'Nouveau produit'),
      ),
      body: SafeArea(
        child: ResponsiveFormPage(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom du produit',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 2) ? 'Min. 2 caractères' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<int>(
                  value: _categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Catégorie',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _categories
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(c.name),
                        ),
                      )
                      .toList(),
                  onChanged: _isLoading
                      ? null
                      : (value) => setState(() => _categoryId = value),
                  validator: (v) => v == null ? 'Catégorie requise' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _skuController,
                  decoration: const InputDecoration(
                    labelText: 'Référence / SKU (optionnel)',
                    prefixIcon: Icon(Icons.tag_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _priceSellController,
                  decoration: const InputDecoration(
                    labelText: 'Prix catalogue — détail (FCFA)',
                    prefixIcon: Icon(Icons.sell_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    final n = _parseInt(v ?? '');
                    if (n == null || n <= 0) return 'Prix invalide';
                    return null;
                  },
                ),
                if (_pricingTiersEnabled) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _priceSemiWholesaleController,
                    decoration: const InputDecoration(
                      labelText: 'Prix demi-gros (optionnel)',
                      prefixIcon: Icon(Icons.store_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _priceWholesaleController,
                    decoration: const InputDecoration(
                      labelText: 'Prix gros (optionnel)',
                      prefixIcon: Icon(Icons.warehouse_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _priceBuyController,
                  decoration: const InputDecoration(
                    labelText: 'Prix d\'achat (optionnel)',
                    prefixIcon: Icon(Icons.shopping_cart_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                if (!widget.isEditing) ...[
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantité initiale',
                      prefixIcon: Icon(Icons.inventory_outlined),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      final n = _parseInt(v ?? '');
                      if (n == null || n < 0) return 'Quantité invalide';
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _alertThresholdController,
                  decoration: const InputDecoration(
                    labelText: 'Seuil d\'alerte (défaut boutique)',
                    prefixIcon: Icon(Icons.notifications_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_calculatorsModuleEnabled) _buildCalculatorSettingsSection(),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  ErrorBanner(message: _errorMessage!),
                ],
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _isLoading ? null : _submit,
                  child: _isLoading
                      ? InventoryFeedback.inlineLoader()
                      : Text(widget.isEditing ? 'Enregistrer' : 'Créer le produit'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildCalculatorSettingsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Calculateur métier lié',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppColors.seed,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _calculatorType,
              decoration: const InputDecoration(
                labelText: 'Type de calculateur',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Aucun')),
                DropdownMenuItem(value: 'tile', child: Text('Carrelage — dimensions et cartons')),
                DropdownMenuItem(value: 'paint', child: Text('Peinture — rendement et fûts')),
                DropdownMenuItem(value: 'concrete', child: Text('Béton & mortier — dosage ciment')),
              ],
              selectedItemBuilder: (context) => [
                const Text('Aucun', overflow: TextOverflow.ellipsis),
                Text(
                  CalculatorTypeLabels.shortLabel('tile'),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  CalculatorTypeLabels.shortLabel('paint'),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  CalculatorTypeLabels.shortLabel('concrete'),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _calculatorType = val;
                });
              },
            ),
            if (_calculatorType != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              if (_calculatorType == 'tile') _buildTileSettingsFields(),
              if (_calculatorType == 'paint') _buildPaintSettingsFields(),
              if (_calculatorType == 'concrete') _buildConcreteSettingsFields(),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildTileSettingsFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paramètres par défaut pour carrelage',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _tileLengthController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Longueur (cm)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _tileWidthController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Largeur (cm)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _piecesPerBoxController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Pièces / Carton'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _wastePercentController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Marge perte (%)'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPaintSettingsFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paramètres par défaut pour peinture',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _coverageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Rendement (m²/L)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _coatsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Couches par défaut'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _volumeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Volume pot (L)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _wastePercentController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Marge perte (%)'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConcreteSettingsFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paramètres par défaut pour béton',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _cementDosageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Dosage ciment (kg/m³)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _bagWeightController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Poids sac (kg)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _sandController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Sable (L/m³)'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _gravelController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Gravier (L/m³)'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _wastePercentController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Marge perte (%)'),
        ),
      ],
    );
  }
}
