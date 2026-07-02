import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/network/widgets/offline_mode_banner.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/rbac_entities.dart';
import '../../domain/usecases/rbac_usecases.dart';
import 'role_detail_page.dart';

class RolesCatalogPage extends StatefulWidget {
  const RolesCatalogPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<RolesCatalogPage> createState() => _RolesCatalogPageState();
}

class _RolesCatalogPageState extends State<RolesCatalogPage> {
  List<RoleCatalogItem> _roles = const [];
  bool _loading = true;
  String? _error;

  bool get _canRead => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.rbacRead,
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
      final roles = await sl<ListRoles>()();
      if (!mounted) return;
      setState(() {
        _roles = roles;
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
        appBar: AppBar(title: const Text('Rôles & permissions')),
        body: const Center(
          child: Text('Vous n\'avez pas accès aux rôles.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Rôles & permissions')),
      body: Column(
        children: [
          const OfflineModeBanner(
            onlinePreferredMessage: OfflineModeBanner.adminCacheMessage,
          ),
          Expanded(child: _buildBody()),
        ],
      ),
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

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _roles.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final role = _roles[index];
          return Card(
            child: ListTile(
              leading: Icon(
                role.isSystem ? Icons.shield_outlined : Icons.tune_outlined,
              ),
              title: Text(role.label),
              subtitle: Text(
                [
                  role.code,
                  if (role.parentRoles.isNotEmpty)
                    'Hérite de : ${role.parentRoles.join(', ')}',
                  '${role.permissions.length} permission(s)',
                ].join('\n'),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RoleDetailPage(
                    session: widget.session,
                    roleCode: role.code,
                    initialRole: role,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
