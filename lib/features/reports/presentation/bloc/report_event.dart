part of 'report_bloc.dart';

sealed class ReportEvent extends Equatable {
  const ReportEvent();

  @override
  List<Object?> get props => [];
}

class ReportLoadRequested extends ReportEvent {
  const ReportLoadRequested();
}

class ReportPeriodChanged extends ReportEvent {
  const ReportPeriodChanged(this.period);

  final ReportPeriodPreset period;

  @override
  List<Object?> get props => [period];
}

class ReportCustomRangeSelected extends ReportEvent {
  const ReportCustomRangeSelected({
    required this.fromMs,
    required this.toMs,
  });

  final int fromMs;
  final int toMs;

  @override
  List<Object?> get props => [fromMs, toMs];
}

class ReportTopSortChanged extends ReportEvent {
  const ReportTopSortChanged(this.sort);

  final ReportTopSort sort;

  @override
  List<Object?> get props => [sort];
}

class ReportConsolidatedToggled extends ReportEvent {
  const ReportConsolidatedToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}
