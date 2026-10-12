import '../entities/stock_valuation_entities.dart';
import '../../data/datasources/local/stock_valuation_local_datasource.dart';

class GetStockValuationSummary {
  const GetStockValuationSummary(this._datasource);

  final StockValuationLocalDatasource _datasource;

  Future<StockValuationSummary> call({required int shopId}) =>
      _datasource.loadStockValuationSummary(shopId);
}

class GetProductSalesVelocity {
  const GetProductSalesVelocity(this._datasource);

  final StockValuationLocalDatasource _datasource;

  Future<ProductSalesVelocity> call({
    required int shopId,
    required int productId,
  }) =>
      _datasource.loadProductSalesVelocity(
        shopId: shopId,
        productId: productId,
      );
}
