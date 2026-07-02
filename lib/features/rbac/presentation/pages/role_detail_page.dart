import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/rbac_entities.dart';
import '../../domain/usecases/rbac_usecases.dart';

class RoleDetailPage extends StatefulWidget {
  const RoleDetailPage({
    super.key,
    required this.session,
    required this.roleCode,
    this.initialRole,
  });

  final AuthSession session;
  final String roleCode;
  final RoleCatalogItem? initialRole;

  @override
  State<RoleDetailPage> createState() => _RoleDetailPageState();
}

class _RoleDetailPageState extends State<RoleDetailPage> {
  RoleCatalogItem? _role;
  PermissionsCatalog? _catalog;
  bool _loading = false;
  String? _error;

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

  @override
  Widget build(BuildContext context) {
    final role = _role;
    return Scaffold(
      appBar: AppBar(
        title: Text(role?.label ?? widget.roleCode),
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
        const SizedBox(height: AppSpacing.md),
        Text(
          'Permissions accordées',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Column(
            children: [
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
        if (!PermissionGuard.can(
          widget.session.user.permissions,
          Permission.rbacManage,
        ))
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.md),
            child: Text(
              'La modification des rôles personnalisés nécessite rbac:manage.',
              style: TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}
