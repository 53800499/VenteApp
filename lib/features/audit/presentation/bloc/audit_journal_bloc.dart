import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/exception_mapper.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../domain/entities/audit_entities.dart';
import '../../domain/usecases/audit_usecases.dart';
import '../services/audit_pdf_exporter.dart';

part 'audit_journal_event.dart';
part 'audit_journal_state.dart';

class AuditJournalBloc extends Bloc<AuditJournalEvent, AuditJournalState> {
  AuditJournalBloc({
    required ListAuditLogs listAuditLogs,
    required GetAuditFilterOptions getFilterOptions,
    required ExportAuditLogs exportAuditLogs,
    required AuditPdfExporter pdfExporter,
    required AuthSession session,
  })  : _listAuditLogs = listAuditLogs,
        _getFilterOptions = getFilterOptions,
        _exportAuditLogs = exportAuditLogs,
        _pdfExporter = pdfExporter,
        _session = session,
        super(const AuditJournalState()) {
    on<AuditJournalLoadRequested>(_onLoad);
    on<AuditJournalLoadMoreRequested>(_onLoadMore);
    on<AuditJournalFiltersChanged>(_onFiltersChanged);
    on<AuditJournalFiltersCleared>(_onFiltersCleared);
    on<AuditJournalExportRequested>(_onExport);
  }

  final ListAuditLogs _listAuditLogs;
  final GetAuditFilterOptions _getFilterOptions;
  final ExportAuditLogs _exportAuditLogs;
  final AuditPdfExporter _pdfExporter;
  final AuthSession _session;

  AuthSession get session => _session;

  Future<void> _onLoad(
    AuditJournalLoadRequested event,
    Emitter<AuditJournalState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AuditJournalStatus.loading,
        clearError: true,
        query: state.query.copyWith(page: 1),
      ),
    );
    await _fetch(emit, reset: true);
  }

  Future<void> _onLoadMore(
    AuditJournalLoadMoreRequested event,
    Emitter<AuditJournalState> emit,
  ) async {
    if (state.isLoadingMore || !state.hasMore) return;
    emit(state.copyWith(isLoadingMore: true, clearError: true));
    await _fetch(
      emit,
      reset: false,
      page: state.query.page + 1,
    );
  }

  Future<void> _onFiltersChanged(
    AuditJournalFiltersChanged event,
    Emitter<AuditJournalState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AuditJournalStatus.loading,
        query: event.query.copyWith(page: 1),
        clearError: true,
      ),
    );
    await _fetch(emit, reset: true);
  }

  Future<void> _onFiltersCleared(
    AuditJournalFiltersCleared event,
    Emitter<AuditJournalState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AuditJournalStatus.loading,
        query: const AuditListQuery(),
        clearError: true,
      ),
    );
    await _fetch(emit, reset: true);
  }

  Future<void> _onExport(
    AuditJournalExportRequested event,
    Emitter<AuditJournalState> emit,
  ) async {
    emit(
      state.copyWith(
        isExporting: true,
        exportSuccess: false,
        clearExportError: true,
      ),
    );
    try {
      final result = await _exportAuditLogs(
        shopId: _session.shop.id,
        query: state.query.copyWith(
          page: 1,
          limit: AppConstants.apiAuditExportLimit,
        ),
      );
      await _pdfExporter.sharePdf(
        shopName: _session.shop.name,
        export: result,
      );
      emit(
        state.copyWith(
          isExporting: false,
          exportSuccess: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          isExporting: false,
          exportErrorMessage: friendlyErrorMessage(error),
        ),
      );
    }
  }

  Future<void> _fetch(
    Emitter<AuditJournalState> emit, {
    required bool reset,
    int? page,
  }) async {
    final query = state.query.copyWith(page: page ?? state.query.page);
    try {
      var filters = state.filterOptions;
      filters ??= await _getFilterOptions();

      final result = await _listAuditLogs(
        shopId: _session.shop.id,
        query: query,
      );

      final items =
          reset ? result.items : [...state.items, ...result.items];

      emit(
        state.copyWith(
          status: AuditJournalStatus.loaded,
          items: items,
          query: query,
          pagination: result.pagination,
          filterOptions: filters,
          isLoadingMore: false,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: state.items.isEmpty
              ? AuditJournalStatus.failure
              : AuditJournalStatus.loaded,
          errorMessage: friendlyErrorMessage(error),
          isLoadingMore: false,
        ),
      );
    }
  }
}
