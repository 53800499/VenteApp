import '../../../../core/database/app_database.dart';
import '../../domain/entities/dashboard_entities.dart';

class DashboardSaleMapper {
  const DashboardSaleMapper._();

  static TodaySaleRow fromSale(Sale sale, {String? customerName}) {
    return TodaySaleRow(
      id: sale.id,
      totalAmount: sale.totalAmount,
      amountCash: sale.amountCash,
      amountMomo: sale.amountMomo,
      amountCredit: sale.amountCredit,
      createdAt: sale.createdAt,
      customerId: sale.customerId,
      customerName: customerName,
      paymentMethod: sale.paymentMethod,
    );
  }
}
