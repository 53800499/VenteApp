import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/network/widgets/offline_mode_banner.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../shop/domain/entities/shop_entities.dart';
import '../../../shop/domain/usecases/shop_usecases.dart';
import '../../../rbac/presentation/pages/user_permissions_page.dart';
import '../../domain/entities/user_entities.dart';
import '../bloc/user_list_bloc.dart';
import '../widgets/assignable_role_picker.dart';
import '../widgets/user_feedback.dart';
import 'user_form_page.dart';

class UserListPage extends StatelessWidget {
  const UserListPage({super.key, required this.session});

  final AuthSession session;

  bool get _canRead =>
      PermissionGuard.can(session.user.permissions, Permission.usersRead);

  bool get _canCreate =>
      PermissionGuard.can(session.user.permissions, Permission.usersCreate);

  bool get _canChangeRole =>
      PermissionGuard.can(session.user.permissions, Permission.usersUpdateRole);

  bool get _canDeactivate =>
      PermissionGuard.can(session.user.permissions, Permission.usersDeactivate);

  bool get _canAssignShop =>
      PermissionGuard.can(session.user.permissions, Permission.usersAssignShop);

  bool get _canViewPermissions =>
      PermissionGuard.can(session.user.permissions, Permission.usersRead) ||
      PermissionGuard.can(session.user.permissions, Permission.rbacRead);

  @override
  Widget build(BuildContext context) {
    if (!_canRead) {
      return Scaffold(
        appBar: AppBar(title: const Text('Équipe')),
        body: const Center(
          child: Text('Vous n\'avez pas accès à la gestion de l\'équipe.'),
        ),
      );
    }

    return BlocProvider(
      create: (_) => UserListBloc(
        listShopUsers: sl(),
        createShopUser: sl(),
        changeUserRole: sl(),
        deactivateShopUser: sl(),
        assignUserShop: sl(),
        currentUserId: session.user.id,
        localShopId: session.shop.id,
      )..add(const UserListLoadRequested()),
      child: _UserListView(
        session: session,
        canCreate: _canCreate,
        canChangeRole: _canChangeRole,
        canDeactivate: _canDeactivate,
        canAssignShop: _canAssignShop,
        canViewPermissions: _canViewPermissions,
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
    required this.canViewPermissions,
  });

  final AuthSession session;
  final bool canCreate;
  final bool canChangeRole;
  final bool canDeactivate;
  final bool canAssignShop;
  final bool canViewPermissions;

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
      body: Column(
        children: [
          const OfflineModeBanner(
            onlinePreferredMessage: OfflineModeBanner.adminCacheMessage,
          ),
          BlocBuilder<UserListBloc, UserListState>(
            buildWhen: (prev, curr) =>
                prev.isRefreshing != curr.isRefreshing ||
                prev.isSubmitting != curr.isSubmitting,
            builder: (context, state) {
              if (!state.isRefreshing && !state.isSubmitting) {
                return const SizedBox.shrink();
              }
              return const LinearProgressIndicator();
            },
          ),
          Expanded(
            child: BlocConsumer<UserListBloc, UserListState>(
              listenWhen: (prev, curr) {
                if (prev.errorMessage != curr.errorMessage &&
                    curr.errorMessage != null &&
                    curr.status == UserListStatus.loaded) {
                  return true;
                }
                if (prev.successMessage != curr.successMessage &&
                    curr.successMessage != null) {
                  return true;
                }
                return false;
              },
              listener: (context, state) async {
                if (state.errorMessage != null &&
                    state.status == UserListStatus.loaded) {
                  await UserFeedback.showErrorDialog(
                    context,
                    title: 'Action impossible',
                    message: state.errorMessage!,
                  );
                  if (context.mounted) {
                    context
                        .read<UserListBloc>()
                        .add(const UserFeedbackDismissed());
                  }
                  return;
                }
                if (state.successMessage != null) {
                  await UserFeedback.showSuccess(
                    context: context,
                    title: state.successMessage!,
                  );
                  if (context.mounted) {
                    context
                        .read<UserListBloc>()
                        .add(const UserFeedbackDismissed());
                  }
                }
              },
              builder: (context, state) {
                if (state.status == UserListStatus.loading &&
                    !state.isRefreshing) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: AppSpacing.md),
                        Text('Chargement de l\'équipe…'),
                      ],
                    ),
                  );
                }

                if (state.status == UserListStatus.failure &&
                    state.users.isEmpty) {
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
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final isSelf = user.id == session.user.apiUserId;
                        return _UserTile(
                          user: user,
                          isSelf: isSelf,
                          isBusy: state.isSubmitting,
                          canChangeRole: canChangeRole &&
                              !isSelf &&
                              !user.isOwner,
                          canDeactivate: canDeactivate &&
                              !isSelf &&
                              !user.isOwner,
                          canAssignShop: canAssignShop &&
                              !isSelf &&
                              !user.isOwner,
                          canViewPermissions: canViewPermissions,
                          onChangeRole: () => _changeRole(context, user),
                          onDeactivate: () => _deactivate(context, user),
                          onAssignShop: () => _assignShop(context, user),
                          onViewPermissions: () => _viewPermissions(context, user),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
    final role = await showAssignableRolePicker(
      context: context,
      title: 'Rôle de ${user.name}',
      currentRoleCode: user.roleCode,
    );
    if (role == null || !context.mounted) return;

    final confirmed = await UserFeedback.confirm(
      context: context,
      title: 'Changer le rôle',
      message: 'Passer ${user.name} au rôle « ${role.label} » ?',
    );
    if (confirmed != true || !context.mounted) return;

    context.read<UserListBloc>().add(
          UserChangeRoleRequested(userId: user.id, roleCode: role.code),
        );
  }

  Future<void> _deactivate(BuildContext context, ShopUser user) async {
    final confirmed = await UserFeedback.confirm(
      context: context,
      title: 'Désactiver ${user.name} ?',
      message: 'Cet utilisateur ne pourra plus se connecter.',
      confirmLabel: 'Désactiver',
      isDestructive: true,
    );
    if (confirmed != true || !context.mounted) return;

    context.read<UserListBloc>().add(UserDeactivateRequested(userId: user.id));
  }

  Future<void> _viewPermissions(BuildContext context, ShopUser user) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserPermissionsPage(
          session: session,
          userId: user.id,
          userName: user.name,
        ),
      ),
    );
  }

  Future<void> _assignShop(BuildContext context, ShopUser user) async {
    List<ManagedShop>? shops;
    try {
      shops = await UserFeedback.runWithBlockingLoader(
        context: context,
        message: 'Chargement des boutiques…',
        action: () async {
          final result = await sl<ListShops>()();
          return result.activeShops;
        },
      );
    } catch (error) {
      if (!context.mounted) return;
      await UserFeedback.showErrorDialog(
        context,
        title: 'Chargement impossible',
        message: friendlyErrorMessage(error),
      );
      return;
    }

    if (!context.mounted || shops == null) return;

    if (shops.length < 2) {
      UserFeedback.showInfo(
        context,
        'Aucune autre boutique disponible.',
      );
      return;
    }

    final selectedShop = await showDialog<ManagedShop>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Réaffecter ${user.name}'),
        children: [
          for (final shop in shops!)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, shop),
              child: Text(shop.name),
            ),
        ],
      ),
    );
    if (selectedShop == null || !context.mounted) return;

    final confirmed = await UserFeedback.confirm(
      context: context,
      title: 'Réaffecter',
      message:
          'Réaffecter ${user.name} à la boutique « ${selectedShop.name} » ?',
    );
    if (confirmed != true || !context.mounted) return;

    context.read<UserListBloc>().add(
          UserAssignShopRequested(
            userId: user.id,
            shopId: selectedShop.id,
          ),
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
    required this.canViewPermissions,
    required this.onChangeRole,
    required this.onDeactivate,
    required this.onAssignShop,
    required this.onViewPermissions,
  });

  final ShopUser user;
  final bool isSelf;
  final bool isBusy;
  final bool canChangeRole;
  final bool canDeactivate;
  final bool canAssignShop;
  final bool canViewPermissions;
  final VoidCallback onChangeRole;
  final VoidCallback onDeactivate;
  final VoidCallback onAssignShop;
  final VoidCallback onViewPermissions;

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
            if (canChangeRole || canDeactivate || canAssignShop || canViewPermissions) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  if (canViewPermissions)
                    OutlinedButton(
                      onPressed: isBusy ? null : onViewPermissions,
                      child: const Text('Droits'),
                    ),
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
