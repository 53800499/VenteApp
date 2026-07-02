import '../../../../shared/enums/user_role.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../entities/sale_entities.dart';
import '../repositories/sale_repository.dart';

class ListSales {
  ListSales(this._repository);

  final SaleRepository _repository;

  Future<List<SaleListRow>> call({
    required AuthSession session,
    SaleListFilters filters = const SaleListFilters(),
  }) {
    return _repository.listSales(
      shopId: session.shop.id,
      filters: filters,
    );
  }
}

class GetSale {
  GetSale(this._repository);

  final SaleRepository _repository;

  Future<Sale> call({
    required AuthSession session,
    required int saleId,
  }) {
    return _repository.getSale(shopId: session.shop.id, saleId: saleId);
  }
}

class ListSaleCustomers {
  ListSaleCustomers(this._repository);

  final SaleRepository _repository;

  Future<List<SaleCustomerOption>> call({
    required AuthSession session,
    String search = '',
  }) {
    return _repository.listCustomers(
      shopId: session.shop.id,
      search: search,
    );
  }
}

class CreateStandardSale {
  CreateStandardSale(this._repository);

  final SaleRepository _repository;

  Future<Sale> call({
    required AuthSession session,
    required CreateStandardSaleInput input,
  }) {
    return _repository.createStandardSale(
      shopId: session.shop.id,
      userId: session.user.id,
      serverShopId: session.shop.apiShopId,
      serverUserId: session.user.apiUserId,
      input: input,
    );
  }
}

class CreateQuickSale {
  CreateQuickSale(this._repository);

  final SaleRepository _repository;

  Future<Sale> call({
    required AuthSession session,
    required CreateQuickSaleInput input,
  }) {
    return _repository.createQuickSale(
      shopId: session.shop.id,
      userId: session.user.id,
      input: input,
    );
  }
}

class CancelSale {
  CancelSale(this._repository);

  final SaleRepository _repository;

  Future<void> call({
    required AuthSession session,
    required int saleId,
    required String reason,
  }) {
    return _repository.cancelSale(
      shopId: session.shop.id,
      userId: session.user.id,
      saleId: saleId,
      reason: reason,
      isOwner: session.user.role == UserRole.owner,
    );
  }
}

class ConvertQuickSaleToStandard {
  ConvertQuickSaleToStandard(this._repository);

  final SaleRepository _repository;

  Future<Sale> call({
    required AuthSession session,
    required int saleId,
    required ConvertQuickSaleInput input,
  }) {
    return _repository.convertQuickSaleToStandard(
      shopId: session.shop.id,
      userId: session.user.id,
      saleId: saleId,
      input: input,
    );
  }
}
