import 'package:flutter/material.dart';

import '../../../app/di/injection_container.dart';
import '../../../features/auth/domain/entities/auth_entities.dart';
import '../../../features/sync/presentation/pages/sync_conflicts_page.dart';
import '../app_release_tier.dart';
import '../sync_service.dart';
import '../sync_snapshot.dart';

/// Indicateur cloud SFD §13.3 — branché sur [SyncService.snapshots].
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key, this.session});

  final AuthSession? session;

  @override
  Widget build(BuildContext context) {
    final syncService = sl<SyncService>();

    return StreamBuilder<SyncSnapshot>(
      stream: syncService.snapshots,
      initialData: syncService.currentSnapshot,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const SyncSnapshot.idle();
        return _SyncStatusIcon(snapshot: data, session: session);
      },
    );
  }
}

class _SyncStatusIcon extends StatelessWidget {
  const _SyncStatusIcon({required this.snapshot, this.session});

  final SyncSnapshot snapshot;
  final AuthSession? session;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (icon, color, tooltip) = _resolve(colorScheme);

    final badge = snapshot.pendingQueueCount > 0 &&
            snapshot.indicatorState == SyncIndicatorState.pending
        ? snapshot.pendingQueueCount
        : null;

    Widget child = Icon(icon, color: color, size: 22);

    if (snapshot.phase == SyncRunPhase.running) {
      child = SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colorScheme.primary,
        ),
      );
    }

    if (badge != null) {
      child = Badge(
        label: Text('$badge'),
        child: child,
      );
    }

    return IconButton(
      onPressed: () => _showDetails(context),
      icon: child,
      tooltip: tooltip,
    );
  }

  (IconData, Color, String) _resolve(ColorScheme colorScheme) {
    if (!snapshot.cloudSyncEnabled ||
        snapshot.indicatorState == SyncIndicatorState.disabled) {
      return (
        Icons.cloud_off_outlined,
        colorScheme.outline,
        'Sync cloud désactivée (V1)',
      );
    }

    return switch (snapshot.indicatorState) {
      SyncIndicatorState.synced => (
          Icons.cloud_done_outlined,
          colorScheme.primary,
          'Tout est synchronisé',
        ),
      SyncIndicatorState.pending => (
          Icons.cloud_upload_outlined,
          colorScheme.tertiary,
          snapshot.blockReason ??
              (snapshot.pendingQueueCount > 0
                  ? '${snapshot.pendingQueueCount} élément(s) en attente'
                  : 'Synchronisation en cours'),
        ),
      SyncIndicatorState.conflict => (
          Icons.cloud_off_outlined,
          colorScheme.error,
          'Conflit de synchronisation — action requise',
        ),
      SyncIndicatorState.disabled => (
          Icons.cloud_off_outlined,
          colorScheme.outline,
          'Sync cloud désactivée',
        ),
    };
  }

  void _showDetails(BuildContext context) {
    if (!snapshot.cloudSyncEnabled) return;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(
                'Synchronisation cloud',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text('Niveau : ${snapshot.tier.label}'),
              Text(_statusLabel(snapshot)),
              if (snapshot.pendingQueueCount > 0)
                Text('File d\'attente : ${snapshot.pendingQueueCount}'),
              if (snapshot.blockReason != null) ...[
                const SizedBox(height: 8),
                Text(
                  snapshot.blockReason!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
              if (snapshot.lastCompletedAt != null)
                Text(
                  'Dernière sync : ${_formatTime(snapshot.lastCompletedAt!)}',
                ),
              if (snapshot.results.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Modules',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                ...snapshot.results.map(
                  (r) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      r.success ? Icons.check_circle_outline : Icons.error_outline,
                      color: r.success
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.error,
                    ),
                    title: Text(r.module),
                    subtitle: r.errorMessage != null ? Text(r.errorMessage!) : null,
                  ),
                ),
              ],
              if (snapshot.indicatorState == SyncIndicatorState.conflict &&
                  session != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            SyncConflictsPage(session: session!),
                      ),
                    );
                  },
                  icon: const Icon(Icons.merge_type_outlined),
                  label: const Text('Résoudre les conflits'),
                ),
              ],
              if (session != null &&
                  snapshot.cloudSyncEnabled &&
                  snapshot.phase != SyncRunPhase.running) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    sl<SyncService>().scheduleSync(shopId: session!.shop.id);
                  },
                  icon: const Icon(Icons.sync_outlined),
                  label: const Text('Relancer la synchronisation'),
                ),
              ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _statusLabel(SyncSnapshot snapshot) {
    if (snapshot.phase == SyncRunPhase.running) {
      return 'État : synchronisation en cours…';
    }
    return switch (snapshot.indicatorState) {
      SyncIndicatorState.synced => 'État : à jour',
      SyncIndicatorState.pending => 'État : éléments en attente',
      SyncIndicatorState.conflict => 'État : conflit à résoudre',
      SyncIndicatorState.disabled => 'État : désactivée',
    };
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
