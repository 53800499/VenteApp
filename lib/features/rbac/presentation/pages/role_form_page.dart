import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/auth/widgets/cloud_session_guard.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../shared/components/action_feedback.dart';
import '../../domain/entities/rbac_entities.dart';
import '../../domain/usecases/rbac_usecases.dart';
import '../widgets/role_permissions_editor.dart';

class RoleFormPage extends StatefulWidget {
  const RoleFormPage({
    super.key,
    this.existingRole,
    this.assignableParentRoles = const [],
  });

  final RoleCatalogItem? existingRole;
  final List<RoleCatalogItem> assignableParentRoles;

  bool get isEditing => existingRole != null;

  @override
  State<RoleFormPage> createState() => _RoleFormPageState();
}

class _RoleFormPageState extends State<RoleFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _slugController = TextEditingController();
  final _labelController = TextEditingController();
  final _descriptionController = TextEditingController();

  PermissionsCatalog? _catalog;
  Map<String, RolePermissionEffect> _selected = {};
  String? _parentRoleCode;
  bool _loadingCatalog = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final role = widget.existingRole;
    if (role != null) {
      _labelController.text = role.label;
      _descriptionController.text = role.description ?? '';
      _selected = RolePermissionsEditor.fromGrants(role.permissions);
      if (role.parentRoles.isNotEmpty) {
        _parentRoleCode = role.parentRoles.first;
      }
    }
    _loadCatalog();
  }

  @override
  void dispose() {
    _slugController.dispose();
    _labelController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final catalog = await sl<GetPermissionsCatalog>()();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _loadingCatalog = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _loadingCatalog = false;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selected.isEmpty) {
      ActionFeedback.showInfo(
        context,
        'Sélectionnez au moins une permission.',
      );
      return;
    }

    if (!await ensureCloudTrustedOperation(
      context,
      actionLabel: widget.isEditing ? 'Modifier un rôle' : 'Créer un rôle',
    )) {
      return;
    }
    if (!mounted) return;

    setState(() => _saving = true);
    try {
      final grants = RolePermissionsEditor.toGrants(_selected);
      if (widget.isEditing) {
        await sl<UpdateShopRole>()(
          widget.existingRole!.code,
          UpdateShopRoleInput(
            label: _labelController.text.trim(),
            description: _descriptionController.text.trim(),
            permissions: grants,
          ),
        );
      } else {
        await sl<CreateShopRole>()(
          CreateShopRoleInput(
            slug: _slugController.text.trim(),
            label: _labelController.text.trim(),
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            parentRoleCode: _parentRoleCode,
            permissions: grants,
          ),
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      await ActionFeedback.showErrorDialog(
        context,
        title: 'Enregistrement impossible',
        message: friendlyErrorMessage(e),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Modifier le rôle' : 'Nouveau rôle'),
      ),
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: FilledButton(
            onPressed: _saving || _loadingCatalog ? null : _submit,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.isEditing ? 'Enregistrer' : 'Créer'),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingCatalog) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: _loadCatalog, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    final catalog = _catalog!;
    final parents = widget.assignableParentRoles
        .where((r) => r.code != widget.existingRole?.code)
        .toList();

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (!widget.isEditing) ...[
            TextFormField(
              controller: _slugController,
              decoration: const InputDecoration(
                labelText: 'Identifiant (slug)',
                hintText: 'caissier',
                helperText: 'Lettres minuscules, chiffres et _ (3 à 31 car.)',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                LengthLimitingTextInputFormatter(31),
              ],
              validator: (value) {
                final v = value?.trim() ?? '';
                if (!RegExp(r'^[a-z][a-z0-9_]{2,30}$').hasMatch(v)) {
                  return 'Identifiant invalide.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          TextFormField(
            controller: _labelController,
            decoration: const InputDecoration(
              labelText: 'Nom affiché',
              hintText: 'Caissier',
            ),
            validator: (value) {
              if (value == null || value.trim().length < 2) {
                return 'Nom requis (2 caractères min.).';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description (optionnel)',
            ),
            maxLines: 2,
          ),
          if (!widget.isEditing && parents.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              initialValue: _parentRoleCode,
              decoration: const InputDecoration(
                labelText: 'Hériter d\'un rôle (optionnel)',
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Aucun'),
                ),
                for (final role in parents)
                  DropdownMenuItem<String?>(
                    value: role.code,
                    child: Text(role.label),
                  ),
              ],
              onChanged: (value) => setState(() => _parentRoleCode = value),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Permissions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          RolePermissionsEditor(
            catalog: catalog,
            selected: _selected,
            onChanged: (value) => setState(() => _selected = value),
          ),
        ],
      ),
    );
  }
}
