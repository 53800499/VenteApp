import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../domain/entities/procurement.dart';
import '../bloc/procurement_bloc.dart';
import '../widgets/procurement_feedback.dart';

/// Ouvre le formulaire fournisseur (création ou édition).
Future<bool?> openSupplierFormPage(
  BuildContext context, {
  Supplier? supplier,
}) {
  return Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: context.read<ProcurementBloc>(),
        child: SupplierFormPage(supplier: supplier),
      ),
    ),
  );
}

class SupplierFormPage extends StatefulWidget {
  const SupplierFormPage({super.key, this.supplier});

  final Supplier? supplier;

  bool get isEditing => supplier != null;

  @override
  State<SupplierFormPage> createState() => _SupplierFormPageState();
}

class _SupplierFormPageState extends State<SupplierFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  bool _submitPending = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplier?.name ?? '');
    _phoneController = TextEditingController(text: widget.supplier?.phone ?? '');
    _emailController = TextEditingController(text: widget.supplier?.email ?? '');
    _addressController =
        TextEditingController(text: widget.supplier?.address ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String? _optionalText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final confirmed = await ProcurementFeedback.confirm(
      context: context,
      title: widget.isEditing
          ? 'Enregistrer les modifications ?'
          : 'Créer le fournisseur ?',
      message: widget.isEditing
          ? 'Mettre à jour le fournisseur « $name » ?'
          : 'Ajouter « $name » à votre liste de fournisseurs ?',
      confirmLabel: widget.isEditing ? 'Enregistrer' : 'Créer',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _submitPending = true);

    final bloc = context.read<ProcurementBloc>();
    if (widget.isEditing) {
      bloc.add(
        ProcurementSupplierUpdateSubmitted(
          id: widget.supplier!.id,
          name: name,
          phone: _optionalText(_phoneController.text),
          email: _optionalText(_emailController.text),
          address: _optionalText(_addressController.text),
          isActive: widget.supplier!.isActive,
        ),
      );
    } else {
      bloc.add(
        ProcurementSupplierCreateSubmitted(
          name: name,
          phone: _optionalText(_phoneController.text),
          email: _optionalText(_emailController.text),
          address: _optionalText(_addressController.text),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ProcurementBloc, ProcurementState>(
      listenWhen: (prev, curr) => _submitPending && prev.status != curr.status,
      listener: (context, state) async {
        if (!_submitPending) return;

        if (state.status == ProcurementStatus.failure &&
            state.errorMessage != null) {
          setState(() => _submitPending = false);
          await ProcurementFeedback.showErrorDialog(
            context,
            title: 'Enregistrement impossible',
            message: state.errorMessage!,
          );
          return;
        }

        if (state.status == ProcurementStatus.loaded) {
          _submitPending = false;
          if (!context.mounted) return;

          final name = _nameController.text.trim();
          await ProcurementFeedback.showSuccess(
            context: context,
            title: widget.isEditing
                ? 'Fournisseur mis à jour'
                : 'Fournisseur créé',
            message: '« $name » a été enregistré.',
          );
          if (context.mounted) Navigator.pop(context, true);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isEditing ? 'Modifier le fournisseur' : 'Nouveau fournisseur',
          ),
        ),
        body: BlocBuilder<ProcurementBloc, ProcurementState>(
          builder: (context, state) {
            final isBusy = _submitPending ||
                state.status == ProcurementStatus.refreshing;

            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  Text(
                    'Informations',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextFormField(
                    controller: _nameController,
                    enabled: !isBusy,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nom *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le nom du fournisseur est obligatoire.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _phoneController,
                    enabled: !isBusy,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _emailController,
                    enabled: !isBusy,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextFormField(
                    controller: _addressController,
                    enabled: !isBusy,
                    decoration: const InputDecoration(
                      labelText: 'Adresse',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FilledButton(
                    onPressed: isBusy ? null : _submit,
                    child: isBusy
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: ProcurementFeedback.inlineLoader(),
                          )
                        : Text(
                            widget.isEditing ? 'Enregistrer' : 'Créer le fournisseur',
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
