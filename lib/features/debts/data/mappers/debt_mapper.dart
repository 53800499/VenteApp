import '../../../../core/database/app_database.dart' as db;
import '../../domain/entities/debt_entities.dart';
import '../models/debt_api_models.dart';

class DebtMapper {
  const DebtMapper._();

  static Debt fromRow(
    db.Debt row, {
    String? customerName,
    String? receiptNumber,
    bool isCritical = false,
  }) {
    return Debt(
      id: row.id,
      shopId: row.shopId,
      customerId: row.customerId,
      customerName: customerName,
      saleId: row.saleId,
      receiptNumber: receiptNumber,
      originalAmount: row.originalAmount,
      amountPaid: row.amountPaid,
      amountRemaining: row.amountRemaining,
      status: DebtStatusX.fromCode(row.status),
      createdAt: row.createdAt,
      dueAt: row.dueAt,
      serverId: row.serverId,
      isCritical: isCritical,
    );
  }

  static Debt fromApi(DebtApiDto dto, {required int localId}) {
    return Debt(
      id: localId,
      shopId: 0,
      customerId: dto.customerId,
      customerName: dto.customerName,
      saleId: dto.saleId,
      originalAmount: dto.originalAmount,
      amountPaid: dto.amountPaid,
      amountRemaining: dto.amountRemaining,
      status: DebtStatusX.fromCode(dto.status),
      createdAt: dto.createdAt,
      dueAt: dto.dueAt,
      serverId: '${dto.id}',
      isCritical: dto.isCritical,
    );
  }
}
