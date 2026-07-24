import '../../domain/entities/sales_order.dart';
import '../../../sales/domain/entities/sale_entities.dart';

abstract class SalesOrderRepository {
  Future<List<SalesOrder>> listOrders({
    required int shopId,
    SalesOrderStatus? status,
    String? search,
  });

  Future<SalesOrder?> findOrder({
    required int shopId,
    required int id,
  });

  Future<String> nextOrderNumber(int shopId);

  Future<SalesOrder> createOrder({
    required int shopId,
    required int userId,
    required int customerId,
    required List<SalesOrderLineInput> items,
    String? notes,
  });

  Future<SalesOrder> updateDraft({
    required int shopId,
    required int userId,
    required int orderId,
    int? customerId,
    List<SalesOrderLineInput>? items,
    String? notes,
  });

  Future<SalesOrder> confirmOrder({
    required int shopId,
    required int userId,
    required int orderId,
  });

  Future<SalesOrder> markPreparing({
    required int shopId,
    required int userId,
    required int orderId,
  });

  Future<SalesOrder> cancelOrder({
    required int shopId,
    required int userId,
    required int orderId,
    String? reason,
  });

  Future<SalesOrder> closeOrder({
    required int shopId,
    required int userId,
    required int orderId,
  });

  Future<SalesOrderDeliverResult> deliver({
    required int shopId,
    required int userId,
    required int orderId,
    required List<DeliveryLineInput> lines,
    required PaymentMethod paymentMethod,
    String? notes,
    String? driverName,
    String? vehiclePlate,
    SalesOrderRemainingReason? remainingReason,
    int? amountCash,
    int? amountMomo,
    int? amountCredit,
  });

  Future<SalesOrderFulfillmentReport> fulfillmentReport({
    required int shopId,
    required int fromMs,
    required int toMs,
  });

  /// Pull incrémental depuis le cloud.
  Future<void> syncFromRemote({
    required int shopId,
    bool force = false,
    int? importUserId,
  });

  /// Rafraîchit une commande depuis le cloud (détail).
  Future<SalesOrder?> refreshOrderFromRemote({
    required int shopId,
    required int orderId,
    int? importUserId,
  });
}
