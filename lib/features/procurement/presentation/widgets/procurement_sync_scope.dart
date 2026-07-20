import 'package:flutter/material.dart';

import '../../domain/entities/procurement_sync_entities.dart';

/// Portée sync cloud pour le module approvisionnement (badges + bannière).
class ProcurementSyncScope extends InheritedWidget {
  const ProcurementSyncScope({
    super.key,
    required this.overview,
    required this.onRefresh,
    required super.child,
  });

  final ProcurementSyncOverview overview;
  final VoidCallback onRefresh;

  static ProcurementSyncScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ProcurementSyncScope>();
  }

  static ProcurementSyncOverview overviewOf(BuildContext context) {
    return maybeOf(context)?.overview ?? const ProcurementSyncOverview();
  }

  @override
  bool updateShouldNotify(ProcurementSyncScope oldWidget) {
    return oldWidget.overview != overview;
  }
}
