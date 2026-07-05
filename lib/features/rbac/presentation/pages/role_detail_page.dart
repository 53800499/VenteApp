import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../shared/components/action_feedback.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/rbac_entities.dart';
import '../../domain/usecases/rbac_usecases.dart';
import 'role_form_page.dart';

class RoleDetailPage extends StatefulWidget {
  const RoleDetailPage({
    super.key,
    required this.session,
    required this.roleCode,
    this.initialRole,
    this.assignableParentRoles = const [],
  });

  final AuthSession session;
  final String roleCode;
  final RoleCatalogItem? initialRole;
  final List<RoleCatalogItem> assignableParentRoles;

  @override
  State<RoleDetailPage> createState() => _RoleDetailPageState();
}

class _RoleDetailPageState extends State<RoleDetailPage> {
  RoleCatalogItem? _role;
  PermissionsCatalog? _catalog;
  bool _loading = false;
  bool _deleting = false;
  String? _error;

  bool get _canManage => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.rbacManage,
      );

  bool get _canEdit =>
      _canManage && _role != null && !_role!.isSystem && _role!.scope == 'shop';

  @override
  void initState() {
    super.initState();
    _role = widget.initialRole;
    if (_role == null) {
      _load();
    } else {
      _loadCatalog();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final role = await sl<GetRoleDetail>()(widget.roleCode);
      if (!mounted) return;
      setState(() {
        _role = role;
        _loading = false;
      });
      await _loadCatalog();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _loading = false;
      });
    }
  }

  Future<void> _loadCatalog() async {
    try {
      final catalog = await sl<GetPermissionsCatalog>()();
      if (!mounted) return;
      setState(() => _catalog = catalog);
    } catch (_) {}
  }

  Future<void> _openEdit() async {
    final role = _role;
    if (role == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RoleFormPage(
          existingRole: role,
          assignableParentRoles: widget.assignableParentRoles,
        ),
      ),
    );
    if (changed == true && mounted) {
      await _load();
      if (mounted) Navigator.pop(context, true);
    }
  }

  Future<void> _deleteRole() async {
    final role = _role;
    if (role == null) return;

    final confirmed = await ActionFeedback.confirm(
      context: context,
      title: 'Supprimer le rôle',
      message:
          'Supprimer « ${role.label} » ? Les utilisateurs avec ce rôle devront être réaffectés.',
      confirmLabel: 'Supprimer',
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await sl<DeleteShopRole>()(role.code);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      await ActionFeedback.showErrorDialog(
        context,
        title: 'Suppression impossible',
        message: friendlyErrorMessage(e),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = _role;
    return Scaffold(
      appBar: AppBar(
        title: Text(role?.label ?? widget.roleCode),
        actions: [
          if (_canEdit)
            IconButton(
              onPressed: _loading || _deleting ? null : _openEdit,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifier',
            ),
          if (_canEdit)
            IconButton(
              onPressed: _loading || _deleting ? null : _deleteRole,
              icon: _deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline),
              tooltip: 'Supprimer',
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: AppSpacing.md),
            FilledButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }

    final role = _role;
    if (role == null) {
      return const Center(child: Text('Rôle introuvable.'));
    }

    final allowed = role.permissions
        .where((p) => p.effect == RolePermissionEffect.allow)
        .map((p) => p.permissionCode)
        .toSet();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        if (role.description != null && role.description!.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(role.description!),
            ),
          ),
        if (role.isSystem)
          const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Rôle système — lecture seule.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Permissions accordées',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(
            children: [
              if (allowed.isEmpty)
                const ListTile(
                  title: Text('Aucune permission directe'),
                )
              else
                for (final code in allowed)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.check, size: 18),
                    title: Text(
                      _catalog?.permissions
                              .where((c) => c.code == code)
                              .map((c) => c.label)
                              .firstOrNull ??
                          code,
                    ),
                    subtitle: Text(code, style: const TextStyle(fontSize: 11)),
                  ),
            ],
          ),
        ),
        if (_canEdit) ...[
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: _openEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Modifier ce rôle'),
          ),
        ],
      ],
    );
  }
}
