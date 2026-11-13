import 'package:flutter/material.dart';
import '../../../app/theme/app_tokens.dart';
import 'app_update_info.dart';
import 'app_update_service.dart';

class AppUpdateDialog extends StatefulWidget {
  const AppUpdateDialog({
    super.key,
    required this.update,
    required this.service,
  });

  final AppUpdateInfo update;
  final AppUpdateService service;

  static Future<void> show({
    required BuildContext context,
    required AppUpdateInfo update,
    required AppUpdateService service,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !update.forceUpdate,
      builder: (ctx) => AppUpdateDialog(update: update, service: service),
    );
  }

  @override
  State<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends State<AppUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _errorMessage;

  Future<void> _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
    });

    try {
      await widget.service.downloadAndInstallUpdate(
        update: widget.update,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Échec du téléchargement. Veuillez réessayer.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final update = widget.update;

    return PopScope(
      canPop: !update.forceUpdate && !_isDownloading,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        titlePadding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        actionsPadding: const EdgeInsets.all(AppSpacing.md),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(Icons.system_update_rounded, color: theme.colorScheme.primary, size: 28),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mise à jour ARIKE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(
                    'Version ${AppUpdateService.currentVersion} → ${update.latestVersion}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (update.forceUpdate)
                Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 20),
                      const SizedBox(width: AppSpacing.xs),
                      const Expanded(
                        child: Text(
                          'Cette mise à jour est requise pour assurer la compatibilité.',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              const Text('Nouveautés & améliorations :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: AppSpacing.xs),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    update.releaseNotes ?? '• Améliorations de performance et corrections de bugs.',
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Safety & Zero Data Loss Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: Color(0xFF059669)),
                    const SizedBox(width: AppSpacing.xs),
                    const Expanded(
                      child: Text(
                        'Sauvegarde SQLite automatique incluse · Zéro perte de données',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isDownloading) ...[
                const SizedBox(height: AppSpacing.md),
                LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _progress >= 0.95
                      ? 'Vérification SHA-256 & Sauvegarde locale...'
                      : _progress > 0
                          ? 'Téléchargement sécurisé : ${(_progress * 100).toInt()}%'
                          : 'Préparation du téléchargement...',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (!update.forceUpdate && !_isDownloading)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Plus tard'),
            ),
          FilledButton.icon(
            onPressed: _isDownloading ? null : _startUpdate,
            icon: _isDownloading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(_isDownloading ? 'Installation...' : 'Mettre à jour maintenant'),
          ),
        ],
      ),
    );
  }
}

