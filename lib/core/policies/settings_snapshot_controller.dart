import 'dart:async';
import 'package:flutter/foundation.dart';

import 'admin_policy.dart';
import 'app_preferences.dart';
import 'arike_policy_engine.dart';
import 'arike_settings_snapshot.dart';
import 'configuration_sync_dto.dart';
import 'effective_settings_resolver.dart';

/// Contrôleur in-memory réactif assurant l'initialisation et la mise à jour
/// atomique du [ArikeSettingsSnapshot] et de son [EffectiveSettingsResolver].
class SettingsSnapshotController extends ValueNotifier<ArikeSettingsSnapshot> {
  SettingsSnapshotController._([ArikeSettingsSnapshot? initial])
      : engine = ArikePolicyEngine(initial ?? ArikeSettingsSnapshot.defaultSnapshot()),
        super(initial ?? ArikeSettingsSnapshot.defaultSnapshot()) {
    _activeResolver = EffectiveSettingsResolver(
      preferences: AppPreferences.defaultPreferences,
      baseSnapshot: value,
    );
  }

  static SettingsSnapshotController? _instance;

  static SettingsSnapshotController get instance {
    _instance ??= SettingsSnapshotController._();
    return _instance!;
  }

  final ArikePolicyEngine engine;
  late EffectiveSettingsResolver _activeResolver;

  EffectiveSettingsResolver get activeResolver => _activeResolver;

  final StreamController<ArikeSettingsSnapshot> _streamController =
      StreamController<ArikeSettingsSnapshot>.broadcast();

  Stream<ArikeSettingsSnapshot> get snapshotStream => _streamController.stream;

  /// Met à jour la configuration à partir d'un resolver réévalué.
  void updateFromResolver(EffectiveSettingsResolver resolver, {int? version}) {
    _activeResolver = resolver;
    final resolvedSnapshot = resolver.resolveToSnapshot(overrideVersion: version);
    swapSnapshotAtomically(resolvedSnapshot);
  }

  /// Applique un payload de synchronisation de configuration [ConfigurationSyncDto].
  void updateFromSyncDto({
    required ConfigurationSyncDto syncDto,
    required AppPreferences preferences,
    required ArikeSettingsSnapshot shopBaseSnapshot,
  }) {
    final resolver = EffectiveSettingsResolver(
      preferences: preferences,
      baseSnapshot: shopBaseSnapshot,
      adminPolicies: syncDto.adminPolicies,
      featureFlags: {
        for (final flag in syncDto.featureFlags)
          if (flag['key'] is String) flag['key'] as String: flag['enabled'] as bool? ?? false,
      },
    );

    updateFromResolver(resolver, version: syncDto.configurationVersion);
  }

  /// Remplace de manière atomique le snapshot en mémoire et notifie tous les écouteurs.
  void swapSnapshotAtomically(ArikeSettingsSnapshot newSnapshot) {
    if (newSnapshot.version < value.version && newSnapshot.version > 0) {
      debugPrint(
        'SettingsSnapshotController: Ignoré snapshot version obsolète (${newSnapshot.version} < ${value.version})',
      );
      return;
    }

    value = newSnapshot;
    engine.updateSnapshot(newSnapshot);
    _streamController.add(newSnapshot);
    debugPrint(
      'SettingsSnapshotController: Snapshot mis à jour vers v${newSnapshot.version} (${newSnapshot.updatedAt.toIso8601String()})',
    );
  }

  @override
  void dispose() {
    _streamController.close();
    super.dispose();
  }
}
