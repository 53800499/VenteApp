part of 'stock_transfer_bloc.dart';

enum StockTransferBlocStatus { initial, loading, loaded, refreshing, failure }

class StockTransferState extends Equatable {
  const StockTransferState({
    this.status = StockTransferBlocStatus.initial,
    this.outgoing = const [],
    this.incoming = const [],
    this.inTransit = const [],
    this.destinationShops = const [],
    this.selectedTransfer,
    this.reportSummary,
    this.errorMessage,
    this.isRefreshing = false,
  });

  final StockTransferBlocStatus status;
  final List<StockTransfer> outgoing;
  final List<StockTransfer> incoming;
  final List<StockTransfer> inTransit;
  final bool isRefreshing;
  final List<ShopOption> destinationShops;
  final StockTransfer? selectedTransfer;
  final StockTransferReportSummary? reportSummary;
  final String? errorMessage;

  StockTransferState copyWith({
    StockTransferBlocStatus? status,
    List<StockTransfer>? outgoing,
    List<StockTransfer>? incoming,
    List<StockTransfer>? inTransit,
    List<ShopOption>? destinationShops,
    StockTransfer? selectedTransfer,
    StockTransferReportSummary? reportSummary,
    String? errorMessage,
    bool? isRefreshing,
    bool clearError = false,
    bool clearSelectedTransfer = false,
    bool clearReportSummary = false,
  }) {
    return StockTransferState(
      status: status ?? this.status,
      outgoing: outgoing ?? this.outgoing,
      incoming: incoming ?? this.incoming,
      inTransit: inTransit ?? this.inTransit,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      destinationShops: destinationShops ?? this.destinationShops,
      selectedTransfer: clearSelectedTransfer
          ? null
          : (selectedTransfer ?? this.selectedTransfer),
      reportSummary:
          clearReportSummary ? null : (reportSummary ?? this.reportSummary),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        outgoing,
        incoming,
        inTransit,
        destinationShops,
        selectedTransfer,
        reportSummary,
        errorMessage,
        isRefreshing,
      ];
}
