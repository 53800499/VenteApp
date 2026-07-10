import 'package:flutter/material.dart';

import '../../../app/di/injection_container.dart';
import '../../../app/theme/app_tokens.dart';
import '../../../features/auth/domain/entities/auth_entities.dart';
import '../../../features/help/presentation/pages/help_article_page.dart';
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
        'Sync cloud désactivée (mode local)',
      );
    }

    return switch (snapshot.indicatorState) {
      SyncIndicatorState.synced => (
          Icons.cloud_done_outlined,
          colorScheme.primary,
          'Données synchronisées avec le serveur',
        ),
      SyncIndicatorState.pending => (
          Icons.cloud_upload_outlined,
          colorScheme.tertiary,
          snapshot.blockReason ??
              (snapshot.pendingQueueCount > 0
                  ? '${snapshot.pendingQueueCount} opération(s) en attente d\'envoi'
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
    if (!snapshot.cloudSyncEnabled) {
      _showLocalOnlySheet(context);
      return;
    }

    final copy = _SyncStatusCopy.fromSnapshot(snapshot);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final maxHeight = MediaQuery.sizeOf(context).height * 0.88;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(copy.icon, color: copy.accentColor(scheme), size: 28),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          copy.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    copy.summary,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      height: AppSizes.lineHeightBody,
                    ),
                  ),
                  if (snapshot.blockReason != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 20,
                            color: scheme.onErrorContainer,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              snapshot.blockReason!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Que faire ?',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...copy.steps.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _StepBadge(number: entry.key + 1),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    height: AppSizes.lineHeightBody,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  if (copy.tip != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lightbulb_outline,
                            size: 20,
                            color: scheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              copy.tip!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _TechnicalDetailsCard(snapshot: snapshot),
                  if (snapshot.results.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Détail par module',
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ...snapshot.results.map(
                      (r) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          r.success
                              ? Icons.check_circle_outline
                              : Icons.error_outline,
                          color: r.success ? scheme.primary : scheme.error,
                        ),
                        title: Text(r.module),
                        subtitle:
                            r.errorMessage != null ? Text(r.errorMessage!) : null,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const HelpArticlePage(articleId: 'sync_offline'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('Guide complet : sync & hors ligne'),
                  ),
                  if (snapshot.indicatorState == SyncIndicatorState.conflict &&
                      session != null) ...[
                    const SizedBox(height: AppSpacing.sm),
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
                    const SizedBox(height: AppSpacing.sm),
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

  void _showLocalOnlySheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      color: Theme.of(context).colorScheme.outline,
                      size: 28,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Mode local uniquement',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'La synchronisation cloud n\'est pas activée sur cet appareil. '
                  'Toutes vos ventes, stocks et clients sont enregistrés sur '
                  'le téléphone. Aucune copie n\'est envoyée au serveur tant '
                  'que le cloud n\'est pas configuré.',
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Que faire ?',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                const _StepRow(
                  number: 1,
                  text:
                      'Pour activer le cloud : Plus → Connexion serveur, puis '
                      'connectez-vous via WhatsApp.',
                ),
                const _StepRow(
                  number: 2,
                  text:
                      'En attendant, exportez régulièrement une sauvegarde '
                      '(Plus → Paramètres → Sauvegarde).',
                ),
                const SizedBox(height: AppSpacing.lg),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const HelpArticlePage(articleId: 'sync_offline'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.menu_book_outlined),
                  label: const Text('En savoir plus'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Text(
        '$number',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onPrimaryContainer,
            ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepBadge(number: number),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _TechnicalDetailsCard extends StatelessWidget {
  const _TechnicalDetailsCard({required this.snapshot});

  final SyncSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informations techniques',
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('Niveau application : ${snapshot.tier.label}'),
          Text('État : ${_statusLabel(snapshot)}'),
          if (snapshot.pendingQueueCount > 0)
            Text('File d\'attente : ${snapshot.pendingQueueCount} opération(s)'),
          if (snapshot.lastCompletedAt != null)
            Text(
              'Dernière synchronisation réussie : '
              '${_formatTime(snapshot.lastCompletedAt!)}',
            ),
        ],
      ),
    );
  }

  String _statusLabel(SyncSnapshot snapshot) {
    if (snapshot.phase == SyncRunPhase.running) {
      return 'synchronisation en cours';
    }
    return switch (snapshot.indicatorState) {
      SyncIndicatorState.synced => 'à jour',
      SyncIndicatorState.pending => 'en attente d\'envoi',
      SyncIndicatorState.conflict => 'conflit à résoudre',
      SyncIndicatorState.disabled => 'désactivée',
    };
  }

  String _formatTime(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _SyncStatusCopy {
  const _SyncStatusCopy({
    required this.icon,
    required this.title,
    required this.summary,
    required this.steps,
    this.tip,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String summary;
  final List<String> steps;
  final String? tip;
  final _SyncAccent? accent;

  Color accentColor(ColorScheme scheme) => switch (accent) {
        _SyncAccent.success => scheme.primary,
        _SyncAccent.warning => scheme.tertiary,
        _SyncAccent.error => scheme.error,
        _SyncAccent.neutral => scheme.outline,
        null => scheme.primary,
      };

  factory _SyncStatusCopy.fromSnapshot(SyncSnapshot snapshot) {
    if (snapshot.phase == SyncRunPhase.running) {
      return const _SyncStatusCopy(
        icon: Icons.cloud_sync_outlined,
        accent: _SyncAccent.warning,
        title: 'Synchronisation en cours',
        summary:
            'VenteApp envoie vos dernières opérations (ventes, stock, clients…) '
            'vers le serveur cloud. Vous pouvez continuer à travailler pendant '
            'ce transfert.',
        steps: [
          'Attendez la fin du transfert (l\'icône redevient verte).',
          'Si la sync reste bloquée plus de 2 minutes, vérifiez votre connexion internet.',
          'Touchez « Relancer la synchronisation » si nécessaire.',
        ],
        tip:
            'Vos données restent enregistrées sur l\'appareil même si la sync échoue.',
      );
    }

    if (snapshot.blockReason != null) {
      return _SyncStatusCopy(
        icon: Icons.cloud_off_outlined,
        accent: _SyncAccent.error,
        title: 'Connexion serveur interrompue',
        summary:
            'L\'application fonctionne en local : vos ventes et stocks sont '
            'sauvegardés sur cet appareil, mais ne sont pas envoyés au serveur '
            'pour le moment.',
        steps: [
          'Vérifiez votre connexion internet (Wi‑Fi ou données mobiles).',
          'Si une bannière orange s\'affiche, touchez « Réessayer » ou saisissez votre code PIN.',
          'En dernier recours : Plus → déconnexion puis reconnexion WhatsApp.',
          'Touchez « Relancer la synchronisation » une fois la connexion rétablie.',
        ],
        tip:
            'Aucune vente n\'est perdue : tout sera synchronisé dès que la session cloud sera rétablie.',
      );
    }

    return switch (snapshot.indicatorState) {
      SyncIndicatorState.synced => const _SyncStatusCopy(
          icon: Icons.cloud_done_outlined,
          accent: _SyncAccent.success,
          title: 'Tout est synchronisé',
          summary:
              'Les données de cette boutique sur votre téléphone correspondent '
              'au serveur cloud. Vos collègues sur d\'autres appareils voient '
              'les mêmes chiffres après leur propre synchronisation.',
          steps: [
            'Continuez à vendre normalement — la sync se déclenche automatiquement.',
            'Touchez l\'icône cloud à tout moment pour vérifier l\'état.',
            'Consultez Plus → Aide & guides pour les procédures détaillées par module.',
          ],
          tip:
              'Une sync automatique a lieu après chaque vente importante et à la reconnexion réseau.',
        ),
      SyncIndicatorState.pending => _SyncStatusCopy(
          icon: Icons.cloud_upload_outlined,
          accent: _SyncAccent.warning,
          title: snapshot.pendingQueueCount > 0
              ? '${snapshot.pendingQueueCount} opération(s) en attente'
              : 'Envoi au serveur en attente',
          summary:
              'Des modifications faites sur cet appareil n\'ont pas encore été '
              'transmises au serveur. Elles sont en file d\'attente et seront '
              'envoyées dès que possible.',
          steps: [
            'Vérifiez que vous êtes connecté à internet.',
            'Laissez l\'application ouverte quelques instants pour laisser la file se vider.',
            'Touchez « Relancer la synchronisation » pour forcer l\'envoi.',
            'Si le compteur ne diminue pas, consultez le détail par module ci-dessous.',
          ],
          tip:
              'Travaillez sereinement : les opérations en attente sont stockées localement.',
        ),
      SyncIndicatorState.conflict => const _SyncStatusCopy(
          icon: Icons.warning_amber_outlined,
          accent: _SyncAccent.error,
          title: 'Conflit à résoudre',
          summary:
              'La même donnée a été modifiée sur cet appareil et sur le serveur '
              '(ou un autre téléphone) en même temps. Le patron doit choisir '
              'quelle version conserver.',
          steps: [
            'Touchez « Résoudre les conflits » (réservé au propriétaire).',
            'Comparez la version locale et la version serveur pour chaque élément.',
            'Choisissez la version correcte, puis validez.',
            'Relancez la synchronisation pour confirmer que tout est à jour.',
          ],
          tip:
              'Évitez de modifier le même produit ou la même vente sur deux appareils en même temps.',
        ),
      SyncIndicatorState.disabled => const _SyncStatusCopy(
          icon: Icons.cloud_off_outlined,
          accent: _SyncAccent.neutral,
          title: 'Synchronisation désactivée',
          summary:
              'Le cloud n\'est pas actif. L\'application fonctionne uniquement en local.',
          steps: [
            'Pour activer : Plus → Connexion serveur.',
            'Connectez-vous via WhatsApp pour obtenir une session cloud.',
            'Sauvegardez régulièrement vos données en local.',
          ],
        ),
    };
  }
}

enum _SyncAccent { success, warning, error, neutral }
