import '../entities/customer_entities.dart';

abstract class CustomerRepository {
  Future<List<Customer>> listCustomers({
    required int shopId,
    CustomerListFilters filters = const CustomerListFilters(),
  });

  Future<CustomerDetail> getCustomer({
    required int shopId,
    required int customerId,
    bool force = false,
  });

  Future<List<CustomerSaleSummary>> listCustomerSales({
    required int shopId,
    required int customerId,
  });

  Future<List<CustomerSaleSummary>> listCustomerSalesLifetime({
    required int shopId,
    required int customerId,
  });

  Future<DebtorsOverview> listDebtors({required int shopId});

  Future<DebtReminder> getDebtReminder({
    required int shopId,
    required int customerId,
    required String shopName,
  });

  Future<Customer> createCustomer({
    required int shopId,
    required CreateCustomerInput input,
    int? serverShopId,
  });

  Future<Customer> updateCustomer({
    required int shopId,
    required int customerId,
    required UpdateCustomerInput input,
  });

  Future<void> archiveCustomer({
    required int shopId,
    required int customerId,
  });

  Future<void> syncFromRemote({required int shopId, bool force = false});
}
