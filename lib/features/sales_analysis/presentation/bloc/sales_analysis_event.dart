part of 'sales_analysis_bloc.dart';

sealed class SalesAnalysisEvent extends Equatable {
  const SalesAnalysisEvent();

  @override
  List<Object?> get props => [];
}

class SalesAnalysisLoadRequested extends SalesAnalysisEvent {
  const SalesAnalysisLoadRequested();
}

/// Rechargement déclenché par la fin d'un cycle de synchronisation : recalcule
/// l'analyse sans repasser par l'état « chargement » (les données actuelles
/// restent affichées pendant l'actualisation).
class SalesAnalysisSyncRefreshRequested extends SalesAnalysisEvent {
  const SalesAnalysisSyncRefreshRequested();
}

class SalesAnalysisPeriodChanged extends SalesAnalysisEvent {
  const SalesAnalysisPeriodChanged({
    required this.period,
    this.customFrom,
    this.customTo,
  });

  final ReportPeriodPreset period;
  final int? customFrom;
  final int? customTo;

  @override
  List<Object?> get props => [period, customFrom, customTo];
}

class SalesAnalysisTabChanged extends SalesAnalysisEvent {
  const SalesAnalysisTabChanged(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}
