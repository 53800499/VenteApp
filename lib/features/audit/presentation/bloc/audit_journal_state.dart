part of 'audit_journal_bloc.dart';

enum AuditJournalStatus { initial, loading, loaded, failure }

class AuditJournalState extends Equatable {
  const AuditJournalState({
    this.status = AuditJournalStatus.initial,
    this.items = const [],
    this.query = const AuditListQuery(),
    this.pagination,
    this.filterOptions,
    this.errorMessage,
    this.isLoadingMore = false,
    this.isExporting = false,
    this.exportErrorMessage,
    this.exportSuccess = false,
  });

  final AuditJournalStatus status;
  final List<AuditLogItem> items;
  final AuditListQuery query;
  final AuditLogPagination? pagination;
  final AuditFilterOptions? filterOptions;
  final String? errorMessage;
  final bool isLoadingMore;
  final bool isExporting;
  final String? exportErrorMessage;
  final bool exportSuccess;

  bool get hasMore => pagination?.hasMore ?? false;

  bool get hasActiveFilters =>
      query.module != null ||
      query.action != null ||
      query.userId != null ||
      query.from != null ||
      query.to != null;

  AuditJournalState copyWith({
    AuditJournalStatus? status,
    List<AuditLogItem>? items,
    AuditListQuery? query,
    AuditLogPagination? pagination,
    AuditFilterOptions? filterOptions,
    String? errorMessage,
    bool? isLoadingMore,
    bool? isExporting,
    String? exportErrorMessage,
    bool? exportSuccess,
    bool clearError = false,
    bool clearExportError = false,
  }) {
    return AuditJournalState(
      status: status ?? this.status,
      items: items ?? this.items,
      query: query ?? this.query,
      pagination: pagination ?? this.pagination,
      filterOptions: filterOptions ?? this.filterOptions,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isExporting: isExporting ?? this.isExporting,
      exportErrorMessage: clearExportError
          ? null
          : (exportErrorMessage ?? this.exportErrorMessage),
      exportSuccess: exportSuccess ?? this.exportSuccess,
    );
  }

  @override
  List<Object?> get props => [
        status,
        items,
        query,
        pagination,
        filterOptions,
        errorMessage,
        isLoadingMore,
        isExporting,
        exportErrorMessage,
        exportSuccess,
      ];
}
