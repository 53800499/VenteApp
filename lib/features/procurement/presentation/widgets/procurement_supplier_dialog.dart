import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/app_tokens.dart';
import '../../domain/entities/procurement.dart';
import '../bloc/procurement_bloc.dart';
import '../widgets/procurement_feedback.dart';

Future<void> showProcurementSupplierDialog(
  BuildContext context, {
  Supplier? supplier,
}) async {
  final nameController = TextEditingController(text: supplier?.name);
  final phoneController = TextEditingController(text: supplier?.phone);
  final emailController = TextEditingController(text: supplier?.email);
  final addressController = TextEditingController(text: supplier?.address);

  await showDialog<void>(
    context: context,
    builder: (diagContext) => AlertDialog(
      title: Text(
        supplier == null ? 'Ajouter un fournisseur' : 'Modifier le fournisseur',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nom *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Adresse',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(diagContext),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          onPressed: () async {
            final name = nameController.text.trim();
            if (name.isEmpty) {
              ProcurementFeedback.showErrorMessage(
                diagContext,
                'Le nom du fournisseur est obligatoire.',
              );
              return;
            }

            final isCreate = supplier == null;
            final confirmed = await ProcurementFeedback.confirm(
              context: diagContext,
              title: isCreate ? 'Créer le fournisseur ?' : 'Enregistrer les modifications ?',
              message: isCreate
                  ? 'Ajouter « $name » à votre liste de fournisseurs ?'
                  : 'Mettre à jour le fournisseur « $name » ?',
              confirmLabel: isCreate ? 'Créer' : 'Enregistrer',
            );
            if (confirmed != true || !diagContext.mounted) return;

            if (isCreate) {
              diagContext.read<ProcurementBloc>().add(
                    ProcurementSupplierCreateSubmitted(
                      name: name,
                      phone: phoneController.text.trim(),
                      email: emailController.text.trim(),
                      address: addressController.text.trim(),
                    ),
                  );
            } else {
              diagContext.read<ProcurementBloc>().add(
                    ProcurementSupplierUpdateSubmitted(
                      id: supplier.id,
                      name: name,
                      phone: phoneController.text.trim(),
                      email: emailController.text.trim(),
                      address: addressController.text.trim(),
                    ),
                  );
            }
            if (diagContext.mounted) Navigator.pop(diagContext);
          },
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );

  nameController.dispose();
  phoneController.dispose();
  emailController.dispose();
  addressController.dispose();
}
