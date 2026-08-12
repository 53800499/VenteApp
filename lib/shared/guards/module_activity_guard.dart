import 'package:flutter/material.dart';

import '../../app/di/injection_container.dart';
import '../../app/theme/app_tokens.dart';
import '../../features/auth/domain/entities/auth_entities.dart';
import '../../features/settings/data/datasources/local/settings_local_datasource.dart';

/// Widget-garde qui vérifie si un module est actif dans les paramètres boutique.
///
/// Si le module est désactivé, un écran d'avertissement remplace [child].
/// L'enfant est affiché immédiatement avant la fin du chargement (cache-first).
class ModuleActivityGuard extends StatefulWidget {
  const ModuleActivityGuard({
    super.key,
    required this.moduleKey,
    required this.session,
    required this.child,
    this.moduleName,
    this.moduleIcon,
  });

  /// Clé du module tel qu'il est défini dans [CommerceSettings.enabledModules].
  /// Exemples : 'SALES', 'INVENTORY', 'PROCUREMENT', 'DEBTS', 'CASH_SESSIONS', 'ORDERS_DELIVERIES'.
  final String moduleKey;

  final AuthSession session;
  final Widget child;

  /// Nom affiché dans le message de désactivation.
  final String? moduleName;

  /// Icône affichée dans le message de désactivation.
  final IconData? moduleIcon;

  @override
  State<ModuleActivityGuard> createState() => _ModuleActivityGuardState();
}

class _ModuleActivityGuardState extends State<ModuleActivityGuard> {
  // On démarre avec true pour un rendu immédiat (cache-first).
  // Le flag sera mis à jour après lecture des settings locaux.
  bool _isActive = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _checkModuleActivity();
  }

  Future<void> _checkModuleActivity() async {
    try {
      final config = await sl<SettingsLocalDatasource>()
          .loadConfiguration(widget.session.shop.id);
      if (mounted) {
        setState(() {
          _isActive = config.commerce.isModuleActive(widget.moduleKey);
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isActive = true; // sécurité : ne pas bloquer si erreur de lecture
          _loaded = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded && !_isActive) {
      return _ModuleDisabledView(
        moduleName: widget.moduleName ?? widget.moduleKey,
        moduleIcon: widget.moduleIcon ?? Icons.extension_off_outlined,
      );
    }
    return widget.child;
  }
}

class _ModuleDisabledView extends StatelessWidget {
  const _ModuleDisabledView({
    required this.moduleName,
    required this.moduleIcon,
  });

  final String moduleName;
  final IconData moduleIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.errorContainer,
              ),
              child: Icon(
                moduleIcon,
                size: 40,
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Module désactivé',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Le module « $moduleName » est actuellement désactivé pour cette boutique.\n\n'
              'Activez-le depuis Paramètres → section correspondante pour accéder à cette fonctionnalité.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton.tonal(
              onPressed: () {},
              child: const Text('Aller dans les paramètres'),
            ),
          ],
        ),
      ),
    );
  }
}
