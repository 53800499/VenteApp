import '../licensing/domain/module_access_guard.dart';
import 'access_policy_resolver.dart';
import 'arike_action.dart';
import 'effective_setting.dart';
import 'effective_settings_resolver.dart';
import 'policy_decision.dart';
import 'settings_snapshot_controller.dart';

/// Façade unifiée d'accès et de configuration ARIKE pour l'interface utilisateur Flutter.
///
/// Elle sert de point d'entrée unique combinant [AccessPolicyResolver] et [EffectiveSettingsResolver].
class ArikeAccessFacade {
  ArikeAccessFacade({
    required this.settingsController,
    this.moduleAccessGuard,
  });

  final SettingsSnapshotController settingsController;
  final ModuleAccessGuard? moduleAccessGuard;

  /// Retourne le resolver de paramètres effectifs actif.
  EffectiveSettingsResolver get settingsResolver => settingsController.activeResolver;

  /// Retourne un [AccessPolicyResolver] configuré avec l'état courant.
  AccessPolicyResolver get accessResolver => AccessPolicyResolver(
        effectiveSettingsResolver: settingsResolver,
        moduleAccessGuard: moduleAccessGuard,
      );

  /// Évalue de manière centralisée si une [ArikeAction] peut être exécutée.
  PolicyDecision canExecute(
    ArikeAction action, {
    required Set<String> userPermissions,
    Map<String, dynamic>? contextData,
  }) {
    return accessResolver.evaluateAction(
      action: action,
      userPermissions: userPermissions,
      contextData: contextData,
    );
  }

  /// Vérifie rapidement si un module commercial est autorisé.
  bool isModuleEnabled(ArikeModule module) {
    if (moduleAccessGuard != null) {
      return moduleAccessGuard!.isModuleAuthorized(module);
    }
    return true;
  }

  /// Récupère directement un paramètre effectif avec ses métadonnées de verrouillage UI.
  EffectiveSetting<T> getSetting<T>(
      EffectiveSetting<T> Function(EffectiveSettingsResolver resolver) selector) {
    return selector(settingsResolver);
  }
}
