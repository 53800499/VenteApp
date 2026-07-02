part of 'report_bloc.dart';

enum ReportStatus { initial, loading, success, failure }

class ReportState extends Equatable {
  const ReportState({
    this.status = ReportStatus.initial,
    this.query = const ReportQuery(),
    this.report,
    this.errorMessage,
  });

  final ReportStatus status;
  final ReportQuery query;
  final Report? report;
  final String? errorMessage;

  ReportState copyWith({
    ReportStatus? status,
    ReportQuery? query,
    Report? report,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ReportState(
      status: status ?? this.status,
      query: query ?? this.query,
      report: report ?? this.report,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, query, report, errorMessage];
}
