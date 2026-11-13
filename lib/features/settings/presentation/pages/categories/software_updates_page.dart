import 'package:flutter/material.dart';
import '../../../../../app/di/injection_container.dart';
import '../../../../../app/theme/app_tokens.dart';
import '../../../../../core/updates/app_update_info.dart';
import '../../../../../core/updates/app_update_service.dart';
import '../../../../../shared/components/app_page_container.dart';

class SoftwareUpdatesPage extends StatefulWidget {
  const SoftwareUpdatesPage({super.key});

  @override
  State<SoftwareUpdatesPage> createState() => _SoftwareUpdatesPageState();
}

class _SoftwareUpdatesPageState extends State<SoftwareUpdatesPage> {
  final _service = sl<AppUpdateService>();

  bool _isChecking = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _currentStep = '';
  String? _errorMessage;
  AppUpdateInfo? _availableUpdate;
  DateTime? _lastCheckedTime;

  bool _autoCheckEnabled = true;
  bool _wifiOnly = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdate(silent: true);
  }

  Future<void> _checkForUpdate({bool silent = false}) async {
    if (_isChecking || _isDownloading) return;

    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    try {
      final update = await _service.checkForUpdate();
      if (mounted) {
        setState(() {
          _isChecking = false;
          _availableUpdate = update;
          _lastCheckedTime = DateTime.now();
        });

        if (!silent) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                update != null
                    ? 'Nouvelle version disponible : v${update.latestVersion} !'
                    : 'Votre application ARIKE est parfaitement à jour.',
              ),
              backgroundColor: update != null ? Colors.amber.shade800 : Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
          _errorMessage = 'Impossible de vérifier les mises à jour. Vérifiez votre connexion internet.';
        });
      }
    }
  }

  Future<void> _startUpdate() async {
    final update = _availableUpdate;
    if (update == null || _isDownloading) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _currentStep = 'Téléchargement du paquet sécurisé...';
      _errorMessage = null;
    });

    try {
      await _service.downloadAndInstallUpdate(
        update: update,
        onProgress: (p) {
          if (mounted) {
            setState(() {
              _downloadProgress = p;
              if (p < 0.90) {
                _currentStep = 'Téléchargement de la mise à jour (${(p * 100).toInt()}%)...';
              } else if (p < 1.0) {
                _currentStep = 'Vérification de l\'empreinte SHA-256...';
              } else {
                _currentStep = 'Sauvegarde de la base locale & Lancement de l\'installateur...';
              }
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _currentStep = 'Installation démarrée !';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Échec de la mise à jour : $e. Veuillez réessayer.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final platform = _service.currentPlatform;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mises à jour du logiciel'),
        actions: [
          IconButton(
            icon: _isChecking
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Vérifier maintenant',
            onPressed: (_isChecking || _isDownloading) ? null : () => _checkForUpdate(),
          ),
        ],
      ),
      body: AppPageContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Current App & Device Status Card
              _buildCurrentStatusCard(theme, platform),
              const SizedBox(height: AppSpacing.md),

              // 2. Update Available Banner or Download Card
              if (_availableUpdate != null) ...[
                _buildAvailableUpdateCard(theme),
                const SizedBox(height: AppSpacing.md),
              ],

              // 3. Security & Zero Data Loss Guarantee
              _buildSafetyGuaranteeCard(theme),
              const SizedBox(height: AppSpacing.md),

              // 4. Update Preferences
              _buildPreferencesCard(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStatusCard(ThemeData theme, String platform) {
    final hasUpdate = _availableUpdate != null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: hasUpdate
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: hasUpdate
              ? theme.colorScheme.primary.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: (hasUpdate ? theme.colorScheme.primary : Colors.green).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasUpdate ? Icons.system_update_rounded : Icons.check_circle_rounded,
                  color: hasUpdate ? theme.colorScheme.primary : Colors.green,
                  size: 32,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasUpdate ? 'Mise à jour disponible !' : 'ARIKE est à jour',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: hasUpdate ? theme.colorScheme.primary : Colors.green.shade800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Version installée : v${AppUpdateService.currentVersion} (Build ${AppUpdateService.currentBuild})',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Appareil : $platform • Canal officiel Supabase Storage',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_lastCheckedTime != null) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Dernière vérification : ${_formatTime(_lastCheckedTime!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton.icon(
                  onPressed: (_isChecking || _isDownloading) ? null : () => _checkForUpdate(),
                  icon: const Icon(Icons.sync_rounded, size: 16),
                  label: const Text('Vérifier', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 18),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvailableUpdateCard(ThemeData theme) {
    final update = _availableUpdate!;
    final sizeMb = update.fileSizeBytes != null
        ? (update.fileSizeBytes! / (1024 * 1024)).toStringAsFixed(1)
        : null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header of update card
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  'v${update.latestVersion}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (sizeMb != null)
                Text(
                  'Taille : $sizeMb Mo',
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              const Spacer(),
              if (update.forceUpdate)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Text(
                    'Obligatoire',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Release Notes
          const Text(
            'Nouveautés de cette version :',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: AppSpacing.xs),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Text(
              update.releaseNotes ?? '• Améliorations de performance et corrections de bugs.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Progress indicator during download
          if (_isDownloading) ...[
            LinearProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
              borderRadius: BorderRadius.circular(AppRadius.xs),
              minHeight: 8,
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _currentStep,
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ),
                Text(
                  '${(_downloadProgress * 100).toInt()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Action Button
          FilledButton.icon(
            onPressed: _isDownloading ? null : _startUpdate,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            ),
            icon: _isDownloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_rounded),
            label: Text(
              _isDownloading ? 'Installation en cours...' : 'Télécharger et Installer la mise à jour',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyGuaranteeCard(ThemeData theme) {
    const emeraldColor = Color(0xFF059669);
    const emeraldDarkColor = Color(0xFF065F46);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: emeraldColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: emeraldColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded, color: emeraldColor, size: 22),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Garantie Zéro Perte de Données',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: emeraldDarkColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Avant chaque mise à jour, ARIKE effectue automatiquement une copie de sauvegarde de sécurité de votre base de données locale (ventes, stocks, dettes, caisse). Vos données restent 100% conservées et protégées.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: emeraldDarkColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Row(
            children: [
              Icon(Icons.lock_rounded, size: 14, color: emeraldColor),
              SizedBox(width: 4),
              Text(
                'Vérification cryptographique SHA-256 activée',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: emeraldDarkColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
            child: Text(
              'Préférences de mise à jour',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          SwitchListTile(
            title: const Text('Recherche automatique'),
            subtitle: const Text('Vérifier si une nouvelle version existe à l\'ouverture d\'ARIKE'),
            value: _autoCheckEnabled,
            onChanged: (val) => setState(() => _autoCheckEnabled = val),
          ),
          const Divider(height: 1),
          SwitchListTile(
            title: const Text('Télécharger uniquement en Wi-Fi'),
            subtitle: const Text('Économiser les données mobiles lors des téléchargements'),
            value: _wifiOnly,
            onChanged: (val) => setState(() => _wifiOnly = val),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

