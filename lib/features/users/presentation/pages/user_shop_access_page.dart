import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/auth/widgets/cloud_session_guard.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/network/widgets/offline_mode_banner.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/components/action_feedback.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../shop/domain/usecases/shop_usecases.dart';
import '../../domain/entities/user_entities.dart';
import '../../domain/usecases/user_usecases.dart';
import '../widgets/assignable_role_picker.dart';

class UserShopAccessPage extends StatefulWidget {
  const UserShopAccessPage({
    super.key,
    required this.session,
    required this.userId,
    required this.userName,
    required this.globalRoleCode,
  });

  final AuthSession session;
  final int userId;
  final String userName;
  final String globalRoleCode;

  @override
  State<UserShopAccessPage> createState() => _UserShopAccessPageState();
}

class _ShopAccessEditorRow {
  _ShopAccessEditorRow({
    required this.shopId,
    required this.shopName,
    required this.enabled,
    this.accessRole,
  });

  final int shopId;
  final String shopName;
  bool enabled;
  String? accessRole;
}

class _UserShopAccessPageState extends State<UserShopAccessPage> {
  UserShopAccess? _access;
  List<_ShopAccessEditorRow> _rows = const [];
  List<AssignableRole> _assignableRoles = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _canManage => PermissionGuard.can(
        widget.session.user.permissions,
        Permission.usersAssignShop,
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
      final shopsFuture = sl<ListShops>()();
      final accessFuture = sl<GetUserShopAccess>()(widget.userId);
      final rolesFuture = AssignableRolesLoader.load();

      final shopsResult = await shopsFuture;
      final access = await accessFuture;
      final roles = await rolesFuture;

      final grantByShopId = {
        for (final shop in access.shops) shop.shopId: shop,
      };

      final rows = shopsResult.activeShops
          .map(
            (shop) => _ShopAccessEditorRow(
              shopId: shop.id,
              shopName: shop.name,
              enabled: grantByShopId.containsKey(shop.id),
              accessRole: grantByShopId[shop.id]?.accessRole,
            ),
          )
          .toList()
        ..sort((a, b) => a.shopName.compareTo(b.shopName));

      if (!mounted) return;
      setState(() {
        _access = access;
        _rows = rows;
        _assignableRoles = roles;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_canManage) return;

    final selected = _rows.where((row) => row.enabled).toList();
    if (selected.isEmpty) {
      ActionFeedback.showErrorMessage(
        context,
        'Au moins une boutique doit rester autorisée.',
      );
      return;
    }

    if (!await ensureCloudTrustedOperation(
      context,
      actionLabel: 'Enregistrer les accès boutiques',
    )) {
      return;
    }
    if (!mounted) return;

    setState(() => _saving = true);
    try {
      final updated = await sl<SyncUserShopAccess>()(
        userId: widget.userId,
        grants: selected
            .map(
              (row) => ShopAccessGrant(
                shopId: row.shopId,
                accessRole: row.accessRole,
              ),
            )
            .toList(),
      );
      if (!mounted) return;
      setState(() {
        _access = updated;
        _saving = false;
      });
      await ActionFeedback.showSuccess(
        context: context,
        title: 'Accès boutiques mis à jour.',
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ActionFeedback.showError(context, error);
    }
  }

  String _roleLabelForCode(String code) {
    return _assignableRoles
            .where((role) => role.code == code)
            .map((role) => role.label)
            .firstOrNull ??
        code;
  }

  @override
  Widget build(BuildContext context) {
    if (!_canManage) {
      return Scaffold(
        appBar: AppBar(title: Text('Boutiques — ${widget.userName}')),
        body: const Center(
          child: Text('Vous n\'avez pas la permission de gérer les accès.'),
        ),
      );
    }

    final access = _access;
    final globalRoleLabel =
        access?.roleLabel ?? _roleLabelForCode(widget.globalRoleCode);

    return Scaffold(
      appBar: AppBar(title: Text('Boutiques — ${widget.userName}')),
      body: Column(
        children: [
          const OfflineModeBanner(
            onlinePreferredMessage: OfflineModeBanner.adminCacheMessage,
          ),
          if (_saving) const LinearProgressIndicator(),
          Expanded(child: _buildBody(globalRoleLabel)),
        ],
      ),
      floatingActionButton: !_loading && _error == null
          ? FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Enregistrer'),
            )
          : null,
    );
  }

  Widget _buildBody(String globalRoleLabel) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: AppSpacing.md),
            Text('Chargement des accès…'),
          ],
        ),
      );
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

    if (_rows.isEmpty) {
      return const Center(child: Text('Aucune boutique disponible.'));
    }

    return ResponsivePage(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rôle global',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    globalRoleLabel,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Cochez les boutiques accessibles. Vous pouvez définir un rôle '
                    'spécifique par boutique, sinon le rôle global s\'applique.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final row in _rows) _buildShopTile(row, globalRoleLabel),
        ],
      ),
    );
  }

  Widget _buildShopTile(_ShopAccessEditorRow row, String globalRoleLabel) {
    final effectiveLabel = row.accessRole == null
        ? globalRoleLabel
        : _roleLabelForCode(row.accessRole!);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        children: [
          CheckboxListTile(
            value: row.enabled,
            onChanged: (value) {
              setState(() {
                row.enabled = value ?? false;
                if (!row.enabled) {
                  row.accessRole = null;
                }
              });
            },
            title: Text(row.shopName),
            subtitle: row.enabled
                ? Text('Rôle effectif : $effectiveLabel')
                : const Text('Accès refusé'),
            secondary: const Icon(Icons.store_outlined),
          ),
          if (row.enabled && _assignableRoles.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: DropdownButtonFormField<String?>(
                key: ValueKey('role-${row.shopId}-${row.accessRole}'),
                initialValue: row.accessRole,
                decoration: InputDecoration(
                  labelText: 'Rôle dans cette boutique',
                  helperText: row.accessRole == null
                      ? 'Hérite du rôle global ($globalRoleLabel)'
                      : 'Rôle spécifique : ${_roleLabelForCode(row.accessRole!)}',
                ),
                items: [
                  DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Rôle global ($globalRoleLabel)'),
                  ),
                  for (final role in _assignableRoles)
                    if (role.code != widget.globalRoleCode)
                      DropdownMenuItem<String?>(
                        value: role.code,
                        child: Text(role.label),
                      ),
                ],
                onChanged: (value) {
                  setState(() => row.accessRole = value);
                },
              ),
            ),
        ],
      ),
    );
  }
}
