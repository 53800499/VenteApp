part of 'report_bloc.dart';

enum ReportStatus { initial, loading, success, failure }

class ReportState extends Equatable {
  const ReportState({
    this.status = ReportStatus.initial,
    this.query = const ReportQuery(),
    this.report,
    this.errorMessage,
    this.isRefreshing = false,
  });

  final ReportStatus status;
  final ReportQuery query;
  final Report? report;
  final String? errorMessage;
  final bool isRefreshing;

  ReportState copyWith({
    ReportStatus? status,
    ReportQuery? query,
    Report? report,
    String? errorMessage,
    bool? isRefreshing,
    bool clearError = false,
  }) {
    return ReportState(
      status: status ?? this.status,
      query: query ?? this.query,
      report: report ?? this.report,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }

  @override
  List<Object?> get props => [status, query, report, errorMessage, isRefreshing];
}
