import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/active_shop_context.dart';
import '../../../../core/responsive/responsive_builder.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/shop_entities.dart';
import '../bloc/shop_list_bloc.dart';
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
      body: BlocConsumer<ShopListBloc, ShopListState>(
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
          if (state.status == ShopListStatus.loading && !state.isRefreshing) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == ShopListStatus.failure && state.shops.isEmpty) {
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
            return const ResponsivePage(
              child: Center(child: Text('Aucune boutique active')),
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
                    onSwitch: () => _switchShop(context, shop.id),
                    onEdit: () => _openForm(context, shop: shop),
                    onSetDefault: () => context.read<ShopListBloc>().add(
                          ShopSetDefaultRequested(shop.id),
                        ),
                    onDeactivate: () => _confirmDeactivate(context, shop),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _switchShop(BuildContext context, int shopId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await performShopSwitch(context, serverShopId: shopId);
      if (!context.mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
    } on Failure catch (failure) {
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(error))),
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

  Future<void> _confirmDeactivate(BuildContext context, ManagedShop shop) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => const _DeactivateShopDialog(),
    );
    if (reason == null || !context.mounted) return;
    context.read<ShopListBloc>().add(
          ShopDeactivateRequested(shopId: shop.id, reason: reason),
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

class _DeactivateShopDialog extends StatefulWidget {
  const _DeactivateShopDialog();

  @override
  State<_DeactivateShopDialog> createState() => _DeactivateShopDialogState();
}

class _DeactivateShopDialogState extends State<_DeactivateShopDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Désactiver la boutique ?'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Motif (optionnel)',
          hintText: 'Fermeture temporaire…',
        ),
        maxLines: 2,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Désactiver'),
        ),
      ],
    );
  }
}
