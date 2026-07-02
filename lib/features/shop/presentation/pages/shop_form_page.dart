import 'package:flutter/material.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../domain/entities/shop_entities.dart';
import '../widgets/shop_feedback.dart';

class ShopFormResult {
  const ShopFormResult({
    required this.name,
    this.address,
    this.phone,
  });

  final String name;
  final String? address;
  final String? phone;

  CreateShopInput toCreateInput() => CreateShopInput(
        name: name,
        address: address,
        phone: phone,
      );

  UpdateShopInput toUpdateInput() => UpdateShopInput(
        name: name,
        address: address,
        phone: phone,
      );
}

class ShopFormPage extends StatefulWidget {
  const ShopFormPage({super.key, this.shop});

  final ManagedShop? shop;

  @override
  State<ShopFormPage> createState() => _ShopFormPageState();
}

class _ShopFormPageState extends State<ShopFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _phoneController;

  bool get _isEdit => widget.shop != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.shop?.name ?? '');
    _addressController = TextEditingController(text: widget.shop?.address ?? '');
    _phoneController = TextEditingController(text: widget.shop?.phone ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final confirmed = await ShopFeedback.confirm(
      context: context,
      title: _isEdit ? 'Enregistrer les modifications' : 'Créer la boutique',
      message: _isEdit
          ? 'Mettre à jour « $name » ?'
          : 'Créer la boutique « $name » ?',
    );
    if (confirmed != true || !mounted) return;

    Navigator.pop(
      context,
      ShopFormResult(
        name: name,
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Modifier la boutique' : 'Nouvelle boutique'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom de la boutique',
                hintText: 'Boutique Akpakpa',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().length < 2) {
                  return 'Le nom doit contenir au moins 2 caractères.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Adresse (optionnel)',
                hintText: 'Cotonou, Akpakpa',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Téléphone (optionnel)',
                hintText: '+22990123456',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _submit,
              child: Text(_isEdit ? 'Enregistrer' : 'Créer la boutique'),
            ),
          ],
        ),
      ),
    );
  }
}
