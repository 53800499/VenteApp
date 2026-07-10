import '../entities/sale_entities.dart';

abstract class SaleRepository {
  Future<List<SaleListRow>> listSales({
    required int shopId,
    SaleListFilters filters = const SaleListFilters(),
  });

  Future<Sale> getSale({
    required int shopId,
    required int saleId,
  });

  Future<List<SaleCustomerOption>> listCustomers({
    required int shopId,
    String search = '',
  });

  Future<Sale> createStandardSale({
    required int shopId,
    required int userId,
    required CreateStandardSaleInput input,
    int? serverShopId,
    int? serverUserId,
  });

  Future<Sale> createQuickSale({
    required int shopId,
    required int userId,
    required CreateQuickSaleInput input,
  });

  Future<void> cancelSale({
    required int shopId,
    required int userId,
    required int saleId,
    required String reason,
    required bool isOwner,
  });

  Future<Sale> convertQuickSaleToStandard({
    required int shopId,
    required int userId,
    required int saleId,
    required ConvertQuickSaleInput input,
  });

  Future<void> syncFromRemote({required int shopId, bool force = false});
}
