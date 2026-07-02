part of 'audit_journal_bloc.dart';

sealed class AuditJournalEvent extends Equatable {
  const AuditJournalEvent();

  @override
  List<Object?> get props => [];
}

class AuditJournalLoadRequested extends AuditJournalEvent {
  const AuditJournalLoadRequested();
}

class AuditJournalLoadMoreRequested extends AuditJournalEvent {
  const AuditJournalLoadMoreRequested();
}

class AuditJournalFiltersChanged extends AuditJournalEvent {
  const AuditJournalFiltersChanged(this.query);

  final AuditListQuery query;

  @override
  List<Object?> get props => [query];
}

class AuditJournalFiltersCleared extends AuditJournalEvent {
  const AuditJournalFiltersCleared();
}

class AuditJournalExportRequested extends AuditJournalEvent {
  const AuditJournalExportRequested();
}
