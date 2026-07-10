part of 'sale_list_bloc.dart';

sealed class SaleListEvent extends Equatable {
  const SaleListEvent();

  @override
  List<Object?> get props => [];
}

final class SaleListLoadRequested extends SaleListEvent {
  const SaleListLoadRequested();
}

final class SaleListRefreshRequested extends SaleListEvent {
  const SaleListRefreshRequested();
}

final class SaleListLocalRefreshRequested extends SaleListEvent {
  const SaleListLocalRefreshRequested();
}

final class SaleListSyncRefreshRequested extends SaleListEvent {
  const SaleListSyncRefreshRequested();
}

final class SaleListSearchChanged extends SaleListEvent {
  const SaleListSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}
