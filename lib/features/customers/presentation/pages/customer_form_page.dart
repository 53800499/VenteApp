import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared/components/ui_primitives.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/customer_entities.dart';
import '../../domain/usecases/customer_usecases.dart';
import '../widgets/customer_feedback.dart';

class CustomerFormPage extends StatefulWidget {
  const CustomerFormPage({
    super.key,
    required this.session,
    this.customer,
  });

  final AuthSession session;
  final Customer? customer;

  bool get isEditing => customer != null;

  @override
  State<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends State<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _noteController;
  bool _submitting = false;
  bool _isShared = false;
  String? _errorMessage;

  bool get _canShare =>
      widget.session.user.role == UserRole.owner;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _phoneController =
        TextEditingController(text: widget.customer?.phone ?? '');
    _addressController =
        TextEditingController(text: widget.customer?.address ?? '');
    _noteController = TextEditingController(text: widget.customer?.note ?? '');
    _isShared = widget.customer?.isShared ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Modifier le client' : 'Nouveau client'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) {
                if (v == null || v.trim().length < 2) {
                  return 'Au moins 2 caractères';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Téléphone (recommandé)',
                hintText: '01XXXXXXXX',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Adresse',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            if (_canShare) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Visibilité du client',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Boutique locale'),
                    icon: Icon(Icons.store_outlined),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Partagé'),
                    icon: Icon(Icons.share_outlined),
                  ),
                ],
                selected: {_isShared},
                onSelectionChanged: _submitting
                    ? null
                    : (selection) =>
                        setState(() => _isShared = selection.first),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _isShared
                    ? 'Visible dans toutes les boutiques du patron. '
                      'Seule la boutique d\'origine peut modifier ou archiver.'
                    : 'Visible uniquement dans la boutique active.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: AppSpacing.md),
              ErrorBanner(message: _errorMessage!),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? CustomerFeedback.inlineLoader()
                  : Text(widget.isEditing ? 'Enregistrer' : 'Créer le client'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final isEdit = widget.isEditing;
    final name = _nameController.text.trim();
    final confirmed = await CustomerFeedback.confirm(
      context: context,
      title: isEdit ? 'Enregistrer les modifications' : 'Créer le client',
      message: isEdit
          ? 'Mettre à jour « $name » ?'
          : 'Créer le client « $name » ?',
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final phone = _phoneController.text.trim();
      final address = _addressController.text.trim();
      final note = _noteController.text.trim();

      if (isEdit) {
        await sl<UpdateCustomer>()(
          session: widget.session,
          customerId: widget.customer!.id,
          input: UpdateCustomerInput(
            name: name,
            phone: phone.isEmpty ? '' : phone,
            address: address.isEmpty ? '' : address,
            note: note.isEmpty ? '' : note,
            isShared: _canShare ? _isShared : null,
          ),
        );
      } else {
        await sl<CreateCustomer>().callFull(
          session: widget.session,
          input: CreateCustomerInput(
            name: name,
            phone: phone.isEmpty ? null : phone,
            address: address.isEmpty ? null : address,
            note: note.isEmpty ? null : note,
            isShared: _canShare && _isShared,
          ),
        );
      }

      if (!mounted) return;
      await CustomerFeedback.showSuccess(
        context: context,
        title: isEdit ? 'Client mis à jour' : 'Client créé',
        message: '« $name » a été enregistré.',
      );
      if (mounted) Navigator.of(context).pop(true);
    } on Failure catch (e) {
      if (!mounted) return;
      final message = friendlyErrorMessage(e);
      await CustomerFeedback.showErrorDialog(
        context,
        title: 'Enregistrement impossible',
        message: message,
      );
      setState(() {
        _errorMessage = message;
        _submitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      const message = 'Échec de l\'enregistrement.';
      await CustomerFeedback.showErrorDialog(
        context,
        title: 'Enregistrement impossible',
        message: message,
      );
      setState(() {
        _errorMessage = message;
        _submitting = false;
      });
    }
  }
}
