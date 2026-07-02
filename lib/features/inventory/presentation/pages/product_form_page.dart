import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/inventory_entities.dart';
import '../../domain/usecases/inventory_usecases.dart';
import '../widgets/inventory_feedback.dart';

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
  final _quantityController = TextEditingController(text: '0');
  final _alertThresholdController = TextEditingController();

  List<ProductCategory> _categories = [];
  int? _categoryId;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    if (product != null) {
      _nameController.text = product.name;
      _skuController.text = product.sku ?? '';
      _priceSellController.text = '${product.priceSell}';
      if (product.priceBuy != null) {
        _priceBuyController.text = '${product.priceBuy}';
      }
      _alertThresholdController.text = '${product.alertThreshold}';
      _categoryId = product.categoryId;
    }
    _loadCategories();
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
    _nameController.dispose();
    _skuController.dispose();
    _priceSellController.dispose();
    _priceBuyController.dispose();
    _quantityController.dispose();
    _alertThresholdController.dispose();
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
      if (isEdit) {
        await sl<UpdateProduct>()(
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
            clearPriceBuy: _priceBuyController.text.trim().isEmpty,
            alertThreshold: _alertThresholdController.text.trim().isEmpty
                ? null
                : _parseInt(_alertThresholdController.text),
          ),
        );
      } else {
        await sl<CreateProduct>()(
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
            initialQuantity: _parseInt(_quantityController.text) ?? 0,
            alertThreshold: _alertThresholdController.text.trim().isEmpty
                ? null
                : _parseInt(_alertThresholdController.text),
          ),
        );
      }

      if (!mounted) return;
      await InventoryFeedback.showSuccess(
        context: context,
        title: isEdit ? 'Produit mis à jour' : 'Produit créé',
        message: '« ${_nameController.text.trim()} » a été enregistré.',
      );
      if (mounted) Navigator.of(context).pop(true);
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
                  initialValue: _categoryId,
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
                    labelText: 'Prix de vente (FCFA)',
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
}
