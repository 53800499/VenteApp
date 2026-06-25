import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../shop/domain/entities/shop_entities.dart';
import '../../../shop/domain/usecases/shop_usecases.dart';
import '../../domain/entities/user_entities.dart';
import '../bloc/user_list_bloc.dart';
import 'user_form_page.dart';

class UserListPage extends StatelessWidget {
  const UserListPage({super.key, required this.session});

  final AuthSession session;

  bool get _canCreate =>
      session.user.role == UserRole.owner ||
      PermissionGuard.can(session.user.permissions, Permission.usersCreate);

  bool get _canChangeRole =>
      session.user.role == UserRole.owner ||
      PermissionGuard.can(session.user.permissions, Permission.usersUpdateRole);

  bool get _canDeactivate =>
      session.user.role == UserRole.owner ||
      PermissionGuard.can(session.user.permissions, Permission.usersDeactivate);

  bool get _canAssignShop =>
      session.user.role == UserRole.owner ||
      PermissionGuard.can(session.user.permissions, Permission.usersAssignShop);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => UserListBloc(
        listShopUsers: sl(),
        createShopUser: sl(),
        changeUserRole: sl(),
        deactivateShopUser: sl(),
        assignUserShop: sl(),
        currentUserId: session.user.apiUserId,
      )..add(const UserListLoadRequested()),
      child: _UserListView(
        session: session,
        canCreate: _canCreate,
        canChangeRole: _canChangeRole,
        canDeactivate: _canDeactivate,
        canAssignShop: _canAssignShop,
      ),
    );
  }
}

class _UserListView extends StatelessWidget {
  const _UserListView({
    required this.session,
    required this.canCreate,
    required this.canChangeRole,
    required this.canDeactivate,
    required this.canAssignShop,
  });

  final AuthSession session;
  final bool canCreate;
  final bool canChangeRole;
  final bool canDeactivate;
  final bool canAssignShop;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Équipe')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _openCreateForm(context),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Ajouter'),
            )
          : null,
      body: BlocConsumer<UserListBloc, UserListState>(
        listener: (context, state) {
          if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.errorMessage!)),
            );
          }
          if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.successMessage!)),
            );
          }
        },
        builder: (context, state) {
          if (state.status == UserListStatus.loading && !state.isRefreshing) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == UserListStatus.failure && state.users.isEmpty) {
            return ResponsivePage(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(state.errorMessage ?? 'Erreur de chargement'),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton(
                      onPressed: () => context
                          .read<UserListBloc>()
                          .add(const UserListLoadRequested()),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }

          final users = state.users.where((u) => u.isActive).toList();
          if (users.isEmpty) {
            return const ResponsivePage(
              child: Center(child: Text('Aucun utilisateur actif')),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context
                  .read<UserListBloc>()
                  .add(const UserListRefreshRequested());
              await context.read<UserListBloc>().stream.firstWhere(
                    (s) => !s.isRefreshing,
                  );
            },
            child: ResponsivePage(
              padding: EdgeInsets.zero,
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.md),
                itemCount: users.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final isSelf = user.id == session.user.apiUserId;
                  return _UserTile(
                    user: user,
                    isSelf: isSelf,
                    isBusy: state.isSubmitting,
                    canChangeRole: canChangeRole && !isSelf && user.role != UserRole.owner,
                    canDeactivate: canDeactivate && !isSelf && user.role != UserRole.owner,
                    canAssignShop: canAssignShop && !isSelf && user.role != UserRole.owner,
                    onChangeRole: () => _changeRole(context, user),
                    onDeactivate: () => _deactivate(context, user),
                    onAssignShop: () => _assignShop(context, user),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openCreateForm(BuildContext context) async {
    final result = await Navigator.of(context).push<UserFormResult>(
      MaterialPageRoute(builder: (_) => const UserFormPage()),
    );
    if (result == null || !context.mounted) return;
    context.read<UserListBloc>().add(UserCreateRequested(result.toInput()));
  }

  Future<void> _changeRole(BuildContext context, ShopUser user) async {
    final role = await showDialog<UserRole>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Rôle de ${user.name}'),
        children: [
          for (final r in [UserRole.seller, UserRole.viewer])
            if (r != user.role)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, r),
                child: Text(r.label),
              ),
        ],
      ),
    );
    if (role == null || !context.mounted) return;
    context.read<UserListBloc>().add(
          UserChangeRoleRequested(userId: user.id, role: role),
        );
  }

  Future<void> _deactivate(BuildContext context, ShopUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Désactiver ${user.name} ?'),
        content: const Text('Cet utilisateur ne pourra plus se connecter.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Désactiver'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    context.read<UserListBloc>().add(UserDeactivateRequested(userId: user.id));
  }

  Future<void> _assignShop(BuildContext context, ShopUser user) async {
    List<ManagedShop> shops;
    try {
      final result = await sl<ListShops>()();
      shops = result.activeShops;
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de charger les boutiques : $e')),
      );
      return;
    }

    if (shops.length < 2) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune autre boutique disponible.')),
      );
      return;
    }

    if (!context.mounted) return;
    final shopId = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Réaffecter ${user.name}'),
        children: [
          for (final shop in shops)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, shop.id),
              child: Text(shop.name),
            ),
        ],
      ),
    );
    if (shopId == null || !context.mounted) return;
    context.read<UserListBloc>().add(
          UserAssignShopRequested(userId: user.id, shopId: shopId),
        );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.isSelf,
    required this.isBusy,
    required this.canChangeRole,
    required this.canDeactivate,
    required this.canAssignShop,
    required this.onChangeRole,
    required this.onDeactivate,
    required this.onAssignShop,
  });

  final ShopUser user;
  final bool isSelf;
  final bool isBusy;
  final bool canChangeRole;
  final bool canDeactivate;
  final bool canAssignShop;
  final VoidCallback onChangeRole;
  final VoidCallback onDeactivate;
  final VoidCallback onAssignShop;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.secondaryContainer,
                  child: Text(
                    user.name.isNotEmpty
                        ? user.name.characters.first.toUpperCase()
                        : '?',
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        user.roleLabel,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (isSelf)
                        Text(
                          'Vous',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                              ),
                        ),
                    ],
                  ),
                ),
                if (user.biometricEnabled)
                  Icon(Icons.fingerprint, color: colorScheme.outline, size: 20),
              ],
            ),
            if (canChangeRole || canDeactivate || canAssignShop) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  if (canChangeRole)
                    OutlinedButton(
                      onPressed: isBusy ? null : onChangeRole,
                      child: const Text('Changer rôle'),
                    ),
                  if (canAssignShop)
                    OutlinedButton(
                      onPressed: isBusy ? null : onAssignShop,
                      child: const Text('Réaffecter'),
                    ),
                  if (canDeactivate)
                    TextButton(
                      onPressed: isBusy ? null : onDeactivate,
                      child: Text(
                        'Désactiver',
                        style: TextStyle(color: colorScheme.error),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
