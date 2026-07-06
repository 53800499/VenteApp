import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/active_shop_context.dart';
import '../../../../core/network/widgets/offline_mode_banner.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/components/empty_list_placeholder.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/shop_entities.dart';
import '../bloc/shop_list_bloc.dart';
import '../widgets/shop_feedback.dart';
import '../widgets/shop_switcher_sheet.dart';
import 'shop_form_page.dart';

class ShopListPage extends StatelessWidget {
  const ShopListPage({super.key, required this.session});

  final AuthSession session;

  bool get _canCreate =>
      session.user.role == UserRole.owner ||
      PermissionGuard.can(session.user.permissions, Permission.shopsCreate);

  bool get _canUpdate =>
      session.user.role == UserRole.owner ||
      PermissionGuard.can(session.user.permissions, Permission.shopsUpdate);

  bool get _canDeactivate =>
      session.user.role == UserRole.owner ||
      PermissionGuard.can(session.user.permissions, Permission.shopsDeactivate);

  bool get _canSwitch =>
      session.user.role == UserRole.owner ||
      PermissionGuard.can(session.user.permissions, Permission.shopsSwitch);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ShopListBloc(
        listShops: sl(),
        createShop: sl(),
        updateShop: sl(),
        deactivateShop: sl(),
        setDefaultShop: sl(),
        activeServerShopId:
            session.shop.serverShopId ?? sl<ActiveShopContext>().serverShopId,
      )..add(const ShopListLoadRequested()),
      child: _ShopListView(
        session: session,
        canCreate: _canCreate,
        canUpdate: _canUpdate,
        canDeactivate: _canDeactivate,
        canSwitch: _canSwitch,
      ),
    );
  }
}

class _ShopListView extends StatelessWidget {
  const _ShopListView({
    required this.session,
    required this.canCreate,
    required this.canUpdate,
    required this.canDeactivate,
    required this.canSwitch,
  });

  final AuthSession session;
  final bool canCreate;
  final bool canUpdate;
  final bool canDeactivate;
  final bool canSwitch;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes boutiques')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(context),
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle boutique'),
            )
          : null,
      body: Column(
        children: [
          const OfflineModeBanner(
            onlinePreferredMessage: OfflineModeBanner.adminCacheMessage,
          ),
          BlocBuilder<ShopListBloc, ShopListState>(
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
            child: BlocConsumer<ShopListBloc, ShopListState>(
              listenWhen: (prev, curr) {
                if (prev.errorMessage != curr.errorMessage &&
                    curr.errorMessage != null &&
                    curr.status == ShopListStatus.loaded) {
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
                    state.status == ShopListStatus.loaded) {
                  await ShopFeedback.showErrorDialog(
                    context,
                    title: 'Action impossible',
                    message: state.errorMessage!,
                  );
                  if (context.mounted) {
                    context
                        .read<ShopListBloc>()
                        .add(const ShopFeedbackDismissed());
                  }
                  return;
                }
                if (state.successMessage != null) {
                  await ShopFeedback.showSuccess(
                    context: context,
                    title: state.successMessage!,
                  );
                  if (context.mounted) {
                    context
                        .read<ShopListBloc>()
                        .add(const ShopFeedbackDismissed());
                  }
                }
              },
              builder: (context, state) {
                if (state.status == ShopListStatus.loading &&
                    !state.isRefreshing) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: AppSpacing.md),
                        Text('Chargement des boutiques…'),
                      ],
                    ),
                  );
                }

                if (state.status == ShopListStatus.failure &&
                    state.shops.isEmpty) {
                  return ResponsivePage(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(state.errorMessage ?? 'Erreur de chargement'),
                          const SizedBox(height: AppSpacing.md),
                          FilledButton(
                            onPressed: () => context
                                .read<ShopListBloc>()
                                .add(const ShopListLoadRequested()),
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final shops = state.activeShops;
                if (shops.isEmpty) {
                  return ResponsivePage(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        context
                            .read<ShopListBloc>()
                            .add(const ShopListRefreshRequested());
                        await context.read<ShopListBloc>().stream.firstWhere(
                              (s) => !s.isRefreshing,
                            );
                      },
                      child: EmptyListPlaceholder(
                        embedded: true,
                        icon: Icons.store_outlined,
                        title: 'Aucune boutique active',
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    context
                        .read<ShopListBloc>()
                        .add(const ShopListRefreshRequested());
                    await context.read<ShopListBloc>().stream.firstWhere(
                          (s) => !s.isRefreshing,
                        );
                  },
                  child: ResponsivePage(
                    padding: EdgeInsets.zero,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: shops.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final shop = shops[index];
                        final isActive = shop.id == state.activeServerShopId;
                        return _ManagedShopTile(
                          shop: shop,
                          isActive: isActive,
                          canUpdate: canUpdate,
                          canDeactivate: canDeactivate,
                          canSwitch: canSwitch && !isActive,
                          isBusy: state.isSubmitting,
                          onSwitch: () => _switchShop(context, shop),
                          onEdit: () => _openForm(context, shop: shop),
                          onSetDefault: () =>
                              _confirmSetDefault(context, shop),
                          onDeactivate: () => _confirmDeactivate(context, shop),
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

  Future<void> _switchShop(BuildContext context, ManagedShop shop) async {
    final confirmed = await ShopFeedback.confirm(
      context: context,
      title: 'Changer de boutique',
      message: 'Utiliser « ${shop.name} » comme boutique active ?',
      confirmLabel: 'Utiliser',
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await performShopSwitch(context, serverShopId: shop.id);
      if (!context.mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on Failure catch (e) {
      if (!context.mounted) return;
      await ShopFeedback.showErrorDialog(
        context,
        title: 'Changement impossible',
        message: friendlyErrorMessage(e),
      );
    } catch (error) {
      if (!context.mounted) return;
      await ShopFeedback.showErrorDialog(
        context,
        title: 'Changement impossible',
        message: friendlyErrorMessage(error),
      );
    }
  }

  Future<void> _openForm(BuildContext context, {ManagedShop? shop}) async {
    final bloc = context.read<ShopListBloc>();
    final result = await Navigator.of(context).push<ShopFormResult>(
      MaterialPageRoute(
        builder: (_) => ShopFormPage(shop: shop),
      ),
    );
    if (result == null || !context.mounted) return;

    if (shop == null) {
      bloc.add(ShopCreateRequested(result.toCreateInput()));
    } else {
      bloc.add(ShopUpdateRequested(
        shopId: shop.id,
        input: result.toUpdateInput(),
      ));
    }
  }

  Future<void> _confirmSetDefault(
    BuildContext context,
    ManagedShop shop,
  ) async {
    final confirmed = await ShopFeedback.confirm(
      context: context,
      title: 'Boutique par défaut',
      message: 'Définir « ${shop.name} » comme boutique par défaut ?',
    );
    if (confirmed != true || !context.mounted) return;
    context.read<ShopListBloc>().add(ShopSetDefaultRequested(shop.id));
  }

  Future<void> _confirmDeactivate(
    BuildContext context,
    ManagedShop shop,
  ) async {
    final reason = await ShopFeedback.confirmWithReason(
      context: context,
      title: 'Désactiver la boutique ?',
      hint: 'Motif (optionnel)',
      confirmLabel: 'Désactiver',
      minLength: 0,
    );
    if (reason == null || !context.mounted) return;
    context.read<ShopListBloc>().add(
          ShopDeactivateRequested(
            shopId: shop.id,
            reason: reason.isEmpty ? null : reason,
          ),
        );
  }
}

class _ManagedShopTile extends StatelessWidget {
  const _ManagedShopTile({
    required this.shop,
    required this.isActive,
    required this.canUpdate,
    required this.canDeactivate,
    required this.canSwitch,
    required this.isBusy,
    required this.onSwitch,
    required this.onEdit,
    required this.onSetDefault,
    required this.onDeactivate,
  });

  final ManagedShop shop;
  final bool isActive;
  final bool canUpdate;
  final bool canDeactivate;
  final bool canSwitch;
  final bool isBusy;
  final VoidCallback onSwitch;
  final VoidCallback onEdit;
  final VoidCallback onSetDefault;
  final VoidCallback onDeactivate;

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
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(Icons.store, color: colorScheme.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      if (shop.address != null && shop.address!.isNotEmpty)
                        Text(
                          shop.address!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (shop.isDefault)
                        Text(
                          'Par défaut',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: colorScheme.primary,
                              ),
                        ),
                    ],
                  ),
                ),
                if (isActive)
                  Chip(
                    label: const Text('Active'),
                    backgroundColor: colorScheme.primaryContainer,
                  ),
              ],
            ),
            if (canSwitch || canUpdate || canDeactivate) ...[
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  if (canSwitch)
                    FilledButton.tonal(
                      onPressed: isBusy ? null : onSwitch,
                      child: const Text('Utiliser'),
                    ),
                  if (canUpdate)
                    OutlinedButton(
                      onPressed: isBusy ? null : onEdit,
                      child: const Text('Modifier'),
                    ),
                  if (!shop.isDefault && canSwitch)
                    OutlinedButton(
                      onPressed: isBusy ? null : onSetDefault,
                      child: const Text('Par défaut'),
                    ),
                  if (canDeactivate && !isActive)
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
