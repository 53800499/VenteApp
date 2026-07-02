import '../../domain/entities/customer_entities.dart';
import '../../../../core/database/app_database.dart' as db;

class CustomerMapper {
  const CustomerMapper._();

  static Customer fromRow(
    db.Customer row, {
    int balanceDue = 0,
    int openDebtsCount = 0,
    int purchaseCount = 0,
    int totalPurchases = 0,
    int lifetimePurchaseCount = 0,
    int lifetimeTotalPurchases = 0,
    int? lifetimeLastActivityAt,
    int? lastActivityAt,
    String? phoneWarning,
  }) {
    return Customer(
      id: row.id,
      shopId: row.shopId,
      name: row.name,
      phone: row.phone,
      address: row.address,
      note: row.note,
      isArchived: row.isArchived,
      isShared: row.isShared,
      balanceDue: balanceDue,
      openDebtsCount: openDebtsCount,
      purchaseCount: purchaseCount,
      totalPurchases: totalPurchases,
      lifetimePurchaseCount: lifetimePurchaseCount,
      lifetimeTotalPurchases: lifetimeTotalPurchases,
      lifetimeLastActivityAt: lifetimeLastActivityAt,
      lastActivityAt: lastActivityAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      serverId: row.serverId,
      phoneWarning: phoneWarning,
    );
  }

  static CustomerSaleSummary saleFromRow(
    db.Sale row, {
    String? shopName,
  }) {
    return CustomerSaleSummary(
      id: row.id,
      receiptNumber: row.receiptNumber,
      totalAmount: row.totalAmount,
      status: row.status,
      createdAt: row.createdAt,
      shopId: row.shopId,
      shopName: shopName,
    );
  }
}
