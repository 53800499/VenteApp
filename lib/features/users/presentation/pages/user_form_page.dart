import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../../../core/utils/phone_util.dart';
import '../../domain/entities/user_entities.dart';
import '../widgets/assignable_role_picker.dart';
import '../widgets/user_feedback.dart';

class UserFormResult {
  const UserFormResult({
    required this.name,
    required this.phone,
    required this.pin,
    required this.roleCode,
  });

  final String name;
  final String phone;
  final String pin;
  final String roleCode;

  CreateShopUserInput toInput() => CreateShopUserInput(
        name: name,
        phone: phone,
        pin: pin,
        roleCode: roleCode,
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
  String? _roleCode;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final roleCode = _roleCode;
    if (roleCode == null || roleCode.isEmpty) {
      UserFeedback.showInfo(context, 'Choisissez un rôle.');
      return;
    }

    final name = _nameController.text.trim();
    final roleLabel = await _roleLabelFor(roleCode);
    if (!mounted) return;

    final confirmed = await UserFeedback.confirm(
      context: context,
      title: 'Créer l\'utilisateur',
      message: 'Ajouter « $name » comme $roleLabel ?',
    );
    if (confirmed != true || !mounted) return;

    Navigator.pop(
      context,
      UserFormResult(
        name: name,
        phone: _phoneController.text.trim(),
        pin: _pinController.text.trim(),
        roleCode: roleCode,
      ),
    );
  }

  Future<String> _roleLabelFor(String code) async {
    final roles = await AssignableRolesLoader.load();
    return roles.where((r) => r.code == code).map((r) => r.label).firstOrNull ??
        code;
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
            AssignableRoleDropdown(
              value: _roleCode,
              onChanged: (value) => setState(() => _roleCode = value),
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
