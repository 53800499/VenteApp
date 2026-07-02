import 'package:equatable/equatable.dart';

import 'app_release_tier.dart';

enum SyncRunPhase {
  idle,
  running,
  completed,
}

/// État indicateur SFD §13.3 (V2/V3 uniquement si cloud activé).
enum SyncIndicatorState {
  /// V1 ou cloud désactivé — icône grise barrée
  disabled,
  /// Tout synchronisé
  synced,
  /// Éléments en attente dans `sync_queue`
  pending,
  /// Conflit à résoudre manuellement (V2/V3)
  conflict,
}

class SyncModuleResult extends Equatable {
  const SyncModuleResult({
    required this.module,
    required this.success,
    this.errorMessage,
  });

  final String module;
  final bool success;
  final String? errorMessage;

  @override
  List<Object?> get props => [module, success, errorMessage];
}

class SyncSnapshot extends Equatable {
  const SyncSnapshot({
    required this.phase,
    this.tier = AppReleaseTier.v1,
    this.cloudSyncEnabled = false,
    this.indicatorState = SyncIndicatorState.disabled,
    this.pendingQueueCount = 0,
    this.shopId,
    this.results = const [],
    this.lastCompletedAt,
    this.blockReason,
  });

  const SyncSnapshot.idle() : this(phase: SyncRunPhase.idle);

  final SyncRunPhase phase;
  final AppReleaseTier tier;
  final bool cloudSyncEnabled;
  final SyncIndicatorState indicatorState;
  final int pendingQueueCount;
  final int? shopId;
  final List<SyncModuleResult> results;
  final DateTime? lastCompletedAt;
  /// Raison affichée quand la sync serveur est bloquée (réseau, JWT…).
  final String? blockReason;

  int get pendingModules =>
      results.where((result) => !result.success).length;

  bool get hasFailures => pendingModules > 0;

  SyncSnapshot copyWith({
    SyncRunPhase? phase,
    AppReleaseTier? tier,
    bool? cloudSyncEnabled,
    SyncIndicatorState? indicatorState,
    int? pendingQueueCount,
    int? shopId,
    List<SyncModuleResult>? results,
    DateTime? lastCompletedAt,
    String? blockReason,
    bool clearBlockReason = false,
  }) {
    return SyncSnapshot(
      phase: phase ?? this.phase,
      tier: tier ?? this.tier,
      cloudSyncEnabled: cloudSyncEnabled ?? this.cloudSyncEnabled,
      indicatorState: indicatorState ?? this.indicatorState,
      pendingQueueCount: pendingQueueCount ?? this.pendingQueueCount,
      shopId: shopId ?? this.shopId,
      results: results ?? this.results,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      blockReason: clearBlockReason ? null : (blockReason ?? this.blockReason),
    );
  }

  @override
  List<Object?> get props => [
        phase,
        tier,
        cloudSyncEnabled,
        indicatorState,
        pendingQueueCount,
        shopId,
        results,
        lastCompletedAt,
        blockReason,
      ];
}
