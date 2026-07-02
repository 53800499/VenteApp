import '../../../customers/domain/entities/customer_entities.dart';
import '../entities/debt_entities.dart';

abstract class DebtRepository {
  Future<List<Debt>> listCustomerDebts({
    required int shopId,
    required int customerId,
    bool openOnly = true,
  });

  Future<List<ForgivenDebtEntry>> listForgivenDebts({
    required int shopId,
    int? customerId,
  });

  Future<DebtForgivenessInfo?> getDebtForgivenessInfo({
    required int shopId,
    required int debtId,
  });

  Future<Debt> getDebt({
    required int shopId,
    required int debtId,
  });

  Future<DebtDetail> getDebtDetail({
    required int shopId,
    required int debtId,
  });

  Future<DebtPaymentResult> recordPayment({
    required int shopId,
    required int debtId,
    required int userId,
    required RecordDebtPaymentInput input,
  });

  Future<Debt> forgiveDebt({
    required int shopId,
    required int debtId,
    required int userId,
    required String reason,
  });

  Future<DebtReminder> getDebtReminder({
    required int shopId,
    required int debtId,
    required String shopName,
  });

  Future<void> syncFromRemote({required int shopId});
}
