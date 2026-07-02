import 'package:flutter/material.dart';

import '../../../../app/di/injection_container.dart';
import '../../../../app/theme/app_tokens.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/sync/sync_conflict_service.dart';
import '../../../../core/sync/sync_service.dart';
import '../../../../shared/components/action_feedback.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/components/action_feedback.dart';
import '../../../auth/domain/entities/auth_entities.dart';

/// ECR-20 — Résolution des conflits de synchronisation.
class SyncConflictsPage extends StatefulWidget {
  const SyncConflictsPage({super.key, required this.session});

  final AuthSession session;

  @override
  State<SyncConflictsPage> createState() => _SyncConflictsPageState();
}

class _SyncConflictsPageState extends State<SyncConflictsPage> {
  List<SyncConflictView> _conflicts = const [];
  bool _loading = true;
  String? _error;
  String? _resolvingKey;

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
      final items = await sl<SyncConflictService>().listConflicts(
        shopId: widget.session.shop.id,
      );
      if (!mounted) return;
      setState(() {
        _conflicts = items;
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
    if (widget.session.user.role != UserRole.owner) {
      return Scaffold(
        appBar: AppBar(title: const Text('Conflits de synchronisation')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Seul le patron peut résoudre les conflits de synchronisation.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Conflits de synchronisation')),
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

    if (_conflicts.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text('Aucun conflit en attente.'),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(
                  alpha: 0.35,
                ),
            child: const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text(
                'Les ventes et dettes sont fusionnées automatiquement '
                'lorsque possible. Les conflits ci-dessous nécessitent '
                'votre choix.',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ..._conflicts.map(_buildConflictCard),
        ],
      ),
    );
  }

  Widget _buildConflictCard(SyncConflictView conflict) {
    final resolving = _resolvingKey == conflict.key;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_entityLabel(conflict.entityTable)} #${conflict.recordId}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (conflict.operation != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text('Opération : ${conflict.operation}'),
            ],
            if (conflict.localDetails != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Version locale', style: Theme.of(context).textTheme.labelLarge),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  conflict.localDetails!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
            if (conflict.serverMessage != null ||
                conflict.serverDetails != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Version serveur', style: Theme.of(context).textTheme.labelLarge),
              if (conflict.serverMessage != null) Text(conflict.serverMessage!),
              if (conflict.serverDetails != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: AppSpacing.xs),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer.withValues(
                          alpha: 0.25,
                        ),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    conflict.serverDetails!,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
            ],
            const SizedBox(height: AppSpacing.md),
            if (resolving)
              const Center(child: CircularProgressIndicator())
            else
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  FilledButton(
                    onPressed: () => _resolve(conflict, keepLocal: true),
                    child: const Text('Garder la mienne'),
                  ),
                  OutlinedButton(
                    onPressed: () => _resolve(conflict, keepLocal: false),
                    child: const Text('Garder serveur'),
                  ),
                  if (conflict.canMerge)
                    TextButton(
                      onPressed: () => _merge(conflict),
                      child: const Text('Fusionner'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _entityLabel(String table) {
    return switch (table) {
      'customers' => 'Client',
      'products' => 'Produit',
      'categories' => 'Catégorie',
      'sales' => 'Vente',
      'debts' => 'Dette',
      _ => table,
    };
  }

  Future<void> _resolve(SyncConflictView conflict, {required bool keepLocal}) async {
    final label = keepLocal ? 'garder votre version' : 'accepter la version serveur';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer'),
        content: Text('Voulez-vous $label pour cet élément ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _resolvingKey = conflict.key);
    try {
      final service = sl<SyncConflictService>();
      if (keepLocal) {
        await service.keepLocal(
          shopId: widget.session.shop.id,
          userId: widget.session.user.id,
          conflict: conflict,
        );
      } else {
        await service.keepServer(
          shopId: widget.session.shop.id,
          userId: widget.session.user.id,
          conflict: conflict,
        );
      }
      if (keepLocal) {
        sl<SyncService>().scheduleSync(shopId: widget.session.shop.id);
      }
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      await ActionFeedback.showSuccess(
        context: context,
        title: keepLocal ? 'Version locale conservée' : 'Version serveur acceptée',
        message: keepLocal
            ? 'La resynchronisation a été lancée.'
            : 'Le conflit a été résolu.',
      );
    } on Failure catch (e) {
      if (!mounted) return;
      await ActionFeedback.showErrorDialog(
        context,
        title: 'Résolution impossible',
        message: friendlyErrorMessage(e),
      );
    } catch (e) {
      if (!mounted) return;
      await ActionFeedback.showErrorDialog(
        context,
        title: 'Résolution impossible',
        message: friendlyErrorMessage(e),
      );
    } finally {
      if (mounted) setState(() => _resolvingKey = null);
    }
  }

  Future<void> _merge(SyncConflictView conflict) async {
    final confirmed = await ActionFeedback.confirm(
      context: context,
      title: 'Fusionner',
      message: conflict.isAutoMerged
          ? 'Accepter la fusion automatique pour cet élément ?'
          : 'Tenter une fusion puis resynchroniser ?',
      confirmLabel: 'Fusionner',
    );
    if (confirmed != true || !mounted) return;

    setState(() => _resolvingKey = conflict.key);
    try {
      await sl<SyncConflictService>().merge(
        shopId: widget.session.shop.id,
        userId: widget.session.user.id,
        conflict: conflict,
      );
      if (conflict.queueId != null) {
        sl<SyncService>().scheduleSync(shopId: widget.session.shop.id);
      }
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      await ActionFeedback.showSuccess(
        context: context,
        title: 'Fusion effectuée',
        message: 'Le conflit a été traité.',
      );
    } on Failure catch (e) {
      if (!mounted) return;
      await ActionFeedback.showErrorDialog(
        context,
        title: 'Fusion impossible',
        message: friendlyErrorMessage(e),
      );
    } catch (e) {
      if (!mounted) return;
      await ActionFeedback.showErrorDialog(
        context,
        title: 'Fusion impossible',
        message: friendlyErrorMessage(e),
      );
    } finally {
      if (mounted) setState(() => _resolvingKey = null);
    }
  }
}
