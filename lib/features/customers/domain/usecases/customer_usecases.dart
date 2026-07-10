import '../../../auth/domain/entities/auth_entities.dart';
import '../../../sales/domain/entities/sale_entities.dart';
import '../entities/customer_entities.dart';
import '../repositories/customer_repository.dart';

class ListCustomers {
  ListCustomers(this._repository);

  final CustomerRepository _repository;

  Future<List<Customer>> call({
    required AuthSession session,
    CustomerListFilters filters = const CustomerListFilters(),
  }) {
    return _repository.listCustomers(
      shopId: session.shop.id,
      filters: filters,
    );
  }
}

class GetCustomer {
  GetCustomer(this._repository);

  final CustomerRepository _repository;

  Future<CustomerDetail> call({
    required AuthSession session,
    required int customerId,
    bool force = false,
  }) {
    return _repository.getCustomer(
      shopId: session.shop.id,
      customerId: customerId,
      force: force,
    );
  }
}

class ListCustomerSales {
  ListCustomerSales(this._repository);

  final CustomerRepository _repository;

  Future<List<CustomerSaleSummary>> call({
    required AuthSession session,
    required int customerId,
  }) {
    return _repository.listCustomerSales(
      shopId: session.shop.id,
      customerId: customerId,
    );
  }
}

class ListCustomerSalesLifetime {
  ListCustomerSalesLifetime(this._repository);

  final CustomerRepository _repository;

  Future<List<CustomerSaleSummary>> call({
    required AuthSession session,
    required int customerId,
  }) {
    return _repository.listCustomerSalesLifetime(
      shopId: session.shop.id,
      customerId: customerId,
    );
  }
}

class ListDebtors {
  ListDebtors(this._repository);

  final CustomerRepository _repository;

  Future<DebtorsOverview> call({required AuthSession session}) {
    return _repository.listDebtors(shopId: session.shop.id);
  }
}

class GetDebtReminder {
  GetDebtReminder(this._repository);

  final CustomerRepository _repository;

  Future<DebtReminder> call({
    required AuthSession session,
    required int customerId,
  }) {
    return _repository.getDebtReminder(
      shopId: session.shop.id,
      customerId: customerId,
      shopName: session.shop.name,
    );
  }
}

class CreateCustomer {
  CreateCustomer(this._repository);

  final CustomerRepository _repository;

  Future<SaleCustomerOption> call({
    required AuthSession session,
    required CreateCustomerInput input,
  }) async {
    final customer = await _repository.createCustomer(
      shopId: session.shop.id,
      serverShopId: session.shop.apiShopId,
      input: input,
    );
    return SaleCustomerOption(
      id: customer.id,
      name: customer.name,
      phone: customer.phone,
    );
  }

  Future<Customer> callFull({
    required AuthSession session,
    required CreateCustomerInput input,
  }) {
    return _repository.createCustomer(
      shopId: session.shop.id,
      serverShopId: session.shop.apiShopId,
      input: input,
    );
  }
}

class UpdateCustomer {
  UpdateCustomer(this._repository);

  final CustomerRepository _repository;

  Future<Customer> call({
    required AuthSession session,
    required int customerId,
    required UpdateCustomerInput input,
  }) {
    return _repository.updateCustomer(
      shopId: session.shop.id,
      customerId: customerId,
      input: input,
    );
  }
}

class ArchiveCustomer {
  ArchiveCustomer(this._repository);

  final CustomerRepository _repository;

  Future<void> call({
    required AuthSession session,
    required int customerId,
  }) {
    return _repository.archiveCustomer(
      shopId: session.shop.id,
      customerId: customerId,
    );
  }
}
