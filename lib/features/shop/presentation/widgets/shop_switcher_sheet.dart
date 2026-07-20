import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/auth/cloud_session_coordinator.dart';
import '../../../../core/auth/cloud_session_repair_service.dart';
import '../../../../core/auth/widgets/cloud_session_guard.dart';
import '../../../../core/auth/widgets/cloud_session_pin_repair_dialog.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/remote_api_guard.dart';
import '../../../../core/storage/last_shop_storage.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../auth/domain/usecases/auth_usecases.dart';
import '../../../rbac/domain/usecases/refresh_session_permissions.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../shop/domain/usecases/shop_usecases.dart';
import '../widgets/shop_feedback.dart';

/// Bascule la boutique active côté serveur et met à jour la session locale.
///
/// Avant de basculer, tente un flush « best effort » des écritures en attente
/// de la boutique courante (voir [SyncService.flushPendingBeforeSwitch]). Si des
/// données ne peuvent pas être envoyées (hors ligne / délai dépassé), l'utilisateur
/// est informé et peut confirmer le changement malgré tout.
///
/// Retourne `true` si la boutique a effectivement changé, `false` si l'opération
/// a été annulée ou n'était pas nécessaire.
Future<bool> performShopSwitch(
  BuildContext context, {
  required int serverShopId,
}) async {
  final authBloc = context.read<AuthBloc>();
  final state = authBloc.state;
  if (state is! AuthAuthenticated) return false;
  if (state.session.shop.apiShopId == serverShopId) return false;

  // Opération à confiance serveur : bloquée au Niveau 3 (>7 j sans validation).
  if (!await ensureCloudTrustedOperation(
    context,
    actionLabel: 'Changer de boutique',
  )) {
    return false;
  }
  if (!context.mounted) return false;

  // S'assurer que la session cloud est utilisable avant flush + switch.
  // Sinon l'utilisateur voit « session en ligne expirée » sans comprendre pourquoi.
  if (!await _ensureCloudReadyForShopSwitch(context)) {
    return false;
  }
  if (!context.mounted) return false;

  final syncService = sl<SyncService>();
  syncService.pauseSync();

  try {
    // Flush « best effort » des écritures en attente de la boutique courante
    // afin qu'elles ne restent pas bloquées jusqu'au prochain retour dessus.
    final currentLocalShopId = state.session.shop.id;
    final flush = await ShopFeedback.runWithBlockingLoader<ShopFlushOutcome>(
      context: context,
      message: 'Envoi des données en attente…',
      action: () => syncService.flushPendingBeforeSwitch(
        shopId: currentLocalShopId,
      ),
    );
    if (!context.mounted) return false;

    if (flush != null && flush.hadPending && !flush.fullyFlushed) {
      final remaining = flush.pendingAfter;
      final proceed = await ShopFeedback.confirm(
        context: context,
        title: 'Données non synchronisées',
        message: flush.wasOffline
            ? '$remaining élément(s) de cette boutique ne sont pas encore '
                'envoyés (hors ligne). Ils seront synchronisés automatiquement '
                'plus tard. Changer de boutique quand même ?'
            : '$remaining élément(s) de cette boutique ne sont pas encore '
                'envoyés. Ils seront synchronisés automatiquement plus tard. '
                'Changer de boutique quand même ?',
        confirmLabel: 'Changer quand même',
        cancelLabel: 'Rester',
      );
      if (proceed != true || !context.mounted) return false;
    }

    // Synchroniser le catalogue, basculer côté serveur puis rafraîchir la session.
    final refreshed = await ShopFeedback.runWithBlockingLoader<AuthSession>(
      context: context,
      message: 'Changement de boutique en cours…',
      action: () async {
        try {
          await sl<ListShops>()();
        } catch (_) {
          // Best-effort : le switch peut quand même créer la boutique manquante.
        }

        final session = await sl<SwitchShop>()(shopId: serverShopId);
        AuthSession result = session;

        try {
          await sl<ListShops>()();
        } catch (_) {
          // Rafraîchir les métadonnées après le switch serveur.
        }

        try {
          final updated = await sl<RefreshSessionPermissions>()();
          if (updated != null) result = updated;
        } catch (_) {
          // Droits du switchShop conservés si /rbac/me échoue.
        }

        return result;
      },
    );
    if (!context.mounted || refreshed == null) return false;

    authBloc.add(AuthSessionRefreshed(refreshed));
    await sl<LastShopStorage>().save(refreshed.shop.id);
    syncService.resumeSync(shopId: refreshed.shop.id);
    return true;
  } finally {
    if (syncService.isPaused) {
      final current = authBloc.state;
      if (current is AuthAuthenticated) {
        syncService.resumeSync(shopId: current.session.shop.id);
      } else {
        syncService.resumeSync();
      }
    }
  }
}

/// Répare / rafraîchit la session cloud avant un switch boutique.
Future<bool> _ensureCloudReadyForShopSwitch(BuildContext context) async {
  final repair = sl<CloudSessionRepairService>();
  try {
    await sl<RemoteApiGuard>().ensureReady(
      timeout: const Duration(seconds: 20),
    );
    repair.clearAwaitingState();
    sl<CloudSessionCoordinator>().markCloudSessionValid();
    return true;
  } on CloudReconnectRequiredFailure {
    if (!context.mounted) return false;
    final restored = await showCloudSessionPinRepairDialog(context);
    if (restored) return true;
    if (!context.mounted) return false;
    await ShopFeedback.showErrorDialog(
      context,
      title: 'Session cloud requise',
      message:
          'Pour changer de boutique, saisissez votre PIN afin de rétablir '
          'la session en ligne, puis réessayez.',
    );
    return false;
  } on Failure catch (e) {
    if (!context.mounted) return false;
    await ShopFeedback.showErrorDialog(
      context,
      title: 'Changement impossible',
      message: friendlyErrorMessage(e),
    );
    return false;
  } catch (error) {
    if (!context.mounted) return false;
    await ShopFeedback.showErrorDialog(
      context,
      title: 'Changement impossible',
      message: friendlyErrorMessage(error),
    );
    return false;
  }
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
      final switched = await performShopSwitch(context, serverShopId: shop.id);
      if (!mounted) return;
      if (!switched) return;
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
              if (_switchingShopId != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      ShopFeedback.inlineLoader(size: 18),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Changement de boutique en cours…',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.primary,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
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
