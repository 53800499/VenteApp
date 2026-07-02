import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/network/widgets/offline_mode_banner.dart';
import '../../../../shared/components/action_feedback.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../../shared/utils/permission_labels.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/rbac_entities.dart';
import '../../domain/usecases/rbac_usecases.dart';
import '../../../users/domain/entities/user_entities.dart';
import '../../../users/domain/usecases/user_usecases.dart';

class UserPermissionsPage extends StatefulWidget {
  const UserPermissionsPage({
    super.key,
    required this.session,
    required this.userId,
    required this.userName,
  });

  final AuthSession session;
  final int userId;
  final String userName;

  @override
  State<UserPermissionsPage> createState() => _UserPermissionsPageState();
}

class _UserPermissionsPageState extends State<UserPermissionsPage> {
  UserAssignment? _assignment;
  UserEffectivePermissions? _effective;
  PermissionsCatalog? _catalog;
  List<UserPermissionOverride> _overrides = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _canOverride => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.rbacOverride,
      );

  bool get _canRead => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.usersRead,
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final assignment = await sl<GetUserAssignment>()(widget.userId);
      final effective = await sl<GetUserEffectivePermissions>()(widget.userId);
      PermissionsCatalog? catalog;
      try {
        catalog = await sl<GetPermissionsCatalog>()();
      } catch (_) {
        catalog = null;
      }
      if (!mounted) return;
      setState(() {
        _assignment = assignment;
        _effective = effective;
        _catalog = catalog;
        _overrides = List.of(assignment.overrides);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canRead) {
      return Scaffold(
        appBar: AppBar(title: Text('Droits — ${widget.userName}')),
        body: const Center(
          child: Text('Vous n\'avez pas accès à cette fiche.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('Droits — ${widget.userName}')),
      body: Column(
        children: [
          const OfflineModeBanner(
            onlinePreferredMessage: OfflineModeBanner.adminCacheMessage,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: _canOverride && !_loading && _error == null
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : _addOverride,
              icon: const Icon(Icons.add_moderator_outlined),
              label: const Text('Exception'),
            )
          : null,
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

    final assignment = _assignment!;
    final effective = _effective!;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(assignment.roleLabel),
              subtitle: Text('Boutique : ${assignment.shopName}'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Permissions effectives',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          ..._buildPermissionGroups(effective.permissions),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Exceptions (overrides)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_overrides.isEmpty)
            const Text('Aucune exception — droits du rôle uniquement.')
          else
            ..._overrides.map(_buildOverrideTile),
          if (_canOverride && _overrides.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _saving ? null : _saveOverrides,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Enregistrer les exceptions'),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildPermissionGroups(Set<Permission> permissions) {
    final byModule = <String, List<Permission>>{};
    for (final p in permissions) {
      final module = permissionModuleCode(p);
      byModule.putIfAbsent(module, () => []).add(p);
    }

    final moduleOrder = _catalog?.modules.map((m) => m.code).toList() ??
        byModule.keys.toList()
          ..sort();

    return [
      for (final module in moduleOrder)
        if (byModule[module]?.isNotEmpty == true) ...[
          Text(
            _catalog?.modules
                    .where((m) => m.code == module)
                    .map((m) => m.label)
                    .firstOrNull ??
                permissionModuleLabel(module),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Card(
            child: Column(
              children: [
                for (final p in byModule[module]!)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.check_circle_outline, size: 18),
                    title: Text(
                      _catalog?.permissions
                              .where((c) => c.code == p.code)
                              .map((c) => c.label)
                              .firstOrNull ??
                          permissionLabel(p),
                    ),
                    subtitle: Text(p.code, style: const TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
    ];
  }

  Widget _buildOverrideTile(UserPermissionOverride override) {
    final label = _catalog?.permissions
            .where((c) => c.code == override.permissionCode)
            .map((c) => c.label)
            .firstOrNull ??
        override.permissionCode;

    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: Text(
          override.effect == PermissionOverrideEffect.grant
              ? 'Accordé en exception'
              : 'Refusé en exception',
        ),
        trailing: _canOverride
            ? IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _saving
                    ? null
                    : () => setState(() {
                          _overrides = _overrides
                              .where(
                                (o) =>
                                    o.permissionCode != override.permissionCode,
                              )
                              .toList();
                        }),
              )
            : null,
      ),
    );
  }

  Future<void> _addOverride() async {
    final catalog = _catalog;
    if (catalog == null || catalog.permissions.isEmpty) {
      ActionFeedback.showInfo(
        context,
        'Catalogue des permissions indisponible hors ligne.',
      );
      return;
    }

    final picked = await showDialog<PermissionCatalogItem>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Choisir une permission'),
        children: [
          SizedBox(
            height: 360,
            width: double.maxFinite,
            child: ListView(
              children: [
                for (final item in catalog.permissions)
                  SimpleDialogOption(
                    onPressed: () => Navigator.pop(ctx, item),
                    child: Text(item.label),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null || !mounted) return;

    final effect = await showDialog<PermissionOverrideEffect>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Effet de l\'exception'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, PermissionOverrideEffect.grant),
            child: const Text('Accorder (grant)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, PermissionOverrideEffect.deny),
            child: const Text('Refuser (deny)'),
          ),
        ],
      ),
    );
    if (effect == null || !mounted) return;

    setState(() {
      _overrides = [
        ..._overrides.where((o) => o.permissionCode != picked.code),
        UserPermissionOverride(
          permissionCode: picked.code,
          effect: effect,
        ),
      ];
    });
  }

  Future<void> _saveOverrides() async {
    setState(() => _saving = true);
    try {
      await sl<ReplaceUserPermissionOverrides>()(
        userId: widget.userId,
        overrides: _overrides,
        reason: 'Mise à jour depuis l\'application mobile',
      );
      if (!mounted) return;
      await ActionFeedback.showSuccess(
        context: context,
        title: 'Exceptions enregistrées',
        message: 'Les droits personnalisés ont été mis à jour.',
      );
      await _load();
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
}
