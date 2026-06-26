import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/phone_util.dart';
import '../../../../shared/enums/user_role.dart';
import '../../domain/entities/user_entities.dart';

class UserFormResult {
  const UserFormResult({
    required this.name,
    required this.phone,
    required this.pin,
    required this.role,
  });

  final String name;
  final String phone;
  final String pin;
  final UserRole role;

  CreateShopUserInput toInput() => CreateShopUserInput(
        name: name,
        phone: phone,
        pin: pin,
        role: role,
      );
}

class UserFormPage extends StatefulWidget {
  const UserFormPage({super.key});

  @override
  State<UserFormPage> createState() => _UserFormPageState();
}

class _UserFormPageState extends State<UserFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  UserRole _role = UserRole.seller;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      UserFormResult(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        pin: _pinController.text.trim(),
        role: _role,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvel utilisateur')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom complet',
                hintText: 'Amina Koffi',
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
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'WhatsApp',
                hintText: '+229 01 97 00 00 00',
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Le numéro WhatsApp est requis.';
                }
                if (!isValidPhone(value)) {
                  return 'Numéro invalide (indicatif pays requis, ex. +229…).';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _pinController,
              decoration: const InputDecoration(
                labelText: 'Code PIN',
                hintText: '4 à 6 chiffres',
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              validator: (value) {
                if (value == null || value.length < 4 || value.length > 6) {
                  return 'PIN de 4 à 6 chiffres requis.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<UserRole>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Rôle'),
              items: const [
                DropdownMenuItem(
                  value: UserRole.seller,
                  child: Text('Vendeur'),
                ),
                DropdownMenuItem(
                  value: UserRole.viewer,
                  child: Text('Lecteur'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _role = value);
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: _submit,
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }
}
