part of 'customer_list_bloc.dart';

sealed class CustomerListEvent extends Equatable {
  const CustomerListEvent();

  @override
  List<Object?> get props => [];
}

final class CustomerListLoadRequested extends CustomerListEvent {
  const CustomerListLoadRequested();
}

final class CustomerListRefreshRequested extends CustomerListEvent {
  const CustomerListRefreshRequested();
}

/// Relecture locale déclenchée par la fin d'un cycle de synchronisation
/// (les données distantes sont déjà en base — pas de pull réseau redondant).
final class CustomerListSyncRefreshRequested extends CustomerListEvent {
  const CustomerListSyncRefreshRequested();
}

final class CustomerListSearchChanged extends CustomerListEvent {
  const CustomerListSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class CustomerListDebtFilterToggled extends CustomerListEvent {
  const CustomerListDebtFilterToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

final class CustomerListSortChanged extends CustomerListEvent {
  const CustomerListSortChanged(this.sort);

  final CustomerSort sort;

  @override
  List<Object?> get props => [sort];
}

final class CustomerListShowDebtorsToggled extends CustomerListEvent {
  const CustomerListShowDebtorsToggled(this.enabled);

  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}
