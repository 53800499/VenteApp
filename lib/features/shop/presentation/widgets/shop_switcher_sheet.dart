import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/storage/last_shop_storage.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../auth/domain/usecases/auth_usecases.dart';
import '../../../rbac/domain/usecases/refresh_session_permissions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../widgets/shop_feedback.dart';

/// Bascule la boutique active côté serveur et met à jour la session locale.
Future<void> performShopSwitch(
  BuildContext context, {
  required int serverShopId,
}) async {
  final authBloc = context.read<AuthBloc>();
  final state = authBloc.state;
  if (state is! AuthAuthenticated) return;
  if (state.session.shop.apiShopId == serverShopId) return;

  final session = await sl<SwitchShop>()(shopId: serverShopId);
  if (!context.mounted) return;
  AuthSession refreshed = session;
  try {
    final updated = await sl<RefreshSessionPermissions>()();
    if (updated != null) refreshed = updated;
  } catch (_) {
    // Droits du switchShop conservés si /rbac/me échoue.
  }
  if (!context.mounted) return;
  authBloc.add(AuthSessionRefreshed(refreshed));
  await sl<LastShopStorage>().save(refreshed.shop.id);
}

/// Feuille modale : liste des boutiques du patron pour changer de contexte.
class ShopSwitcherSheet extends StatefulWidget {
  const ShopSwitcherSheet({super.key, required this.session});

  final AuthSession session;

  static Future<void> show(BuildContext context, AuthSession session) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ShopSwitcherSheet(session: session),
    );
  }

  @override
  State<ShopSwitcherSheet> createState() => _ShopSwitcherSheetState();
}

class _ShopSwitcherSheetState extends State<ShopSwitcherSheet> {
  OwnedShopList? _shops;
  String? _error;
  bool _loading = true;
  int? _switchingShopId;

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final shops = await sl<ListOwnedShops>()();
      if (!mounted) return;
      setState(() {
        _shops = shops;
        _loading = false;
      });
    } on Failure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e);
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

  Future<void> _selectShop(OwnedShop shop) async {
    if (_switchingShopId != null) return;
    if (shop.id == widget.session.shop.apiShopId) {
      Navigator.pop(context);
      return;
    }

    final confirmed = await ShopFeedback.confirm(
      context: context,
      title: 'Changer de boutique',
      message: 'Utiliser « ${shop.name} » comme boutique active ?',
      confirmLabel: 'Utiliser',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _switchingShopId = shop.id);
    try {
      await performShopSwitch(context, serverShopId: shop.id);
      if (!mounted) return;
      Navigator.pop(context);
      await ShopFeedback.showSuccess(
        context: context,
        title: 'Boutique changée',
        message: '« ${shop.name} » est maintenant la boutique active.',
      );
    } on Failure catch (e) {
      if (!mounted) return;
      await ShopFeedback.showErrorDialog(
        context,
        title: 'Changement impossible',
        message: friendlyErrorMessage(e),
      );
    } catch (error) {
      if (!mounted) return;
      await ShopFeedback.showErrorDialog(
        context,
        title: 'Changement impossible',
        message: friendlyErrorMessage(error),
      );
    } finally {
      if (mounted) setState(() => _switchingShopId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeId = widget.session.shop.apiShopId;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Changer de boutique',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Vous restez patron sur toutes vos boutiques.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: AppSpacing.md),
                      Text('Chargement des boutiques…'),
                    ],
                  ),
                ),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: AppSpacing.sm),
                    FilledButton(
                      onPressed: _loadShops,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              )
            else ...[
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _shops!.activeShops.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, index) {
                    final shop = _shops!.activeShops[index];
                    final isActive = shop.id == activeId;
                    final isBusy = _switchingShopId == shop.id;

                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        side: isActive
                            ? BorderSide(color: colorScheme.primary)
                            : BorderSide.none,
                      ),
                      tileColor: isActive
                          ? colorScheme.primaryContainer.withValues(alpha: 0.35)
                          : colorScheme.surfaceContainerHighest,
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(Icons.store, color: colorScheme.primary),
                      ),
                      title: Text(shop.name),
                      subtitle: shop.address != null && shop.address!.isNotEmpty
                          ? Text(shop.address!)
                          : null,
                      trailing: isBusy
                          ? ShopFeedback.inlineLoader(size: 24)
                          : isActive
                              ? Icon(Icons.check_circle, color: colorScheme.primary)
                              : const Icon(Icons.chevron_right),
                      onTap: isBusy ? null : () => _selectShop(shop),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
