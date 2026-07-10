import '../../../auth/domain/entities/auth_entities.dart';
import '../../../customers/domain/entities/customer_entities.dart';
import '../../../../shared/enums/permission.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../../shared/guards/permission_guard.dart';
import '../../../../core/errors/failures.dart';
import '../entities/debt_entities.dart';
import '../repositories/debt_repository.dart';

class ListCustomerDebts {
  ListCustomerDebts(this._repository);

  final DebtRepository _repository;

  Future<List<Debt>> call({
    required AuthSession session,
    required int customerId,
    bool openOnly = true,
  }) {
    return _repository.listCustomerDebts(
      shopId: session.shop.id,
      customerId: customerId,
      openOnly: openOnly,
    );
  }
}

class ListForgivenDebts {
  ListForgivenDebts(this._repository);

  final DebtRepository _repository;

  Future<List<ForgivenDebtEntry>> call({
    required AuthSession session,
    int? customerId,
  }) {
    if (!PermissionGuard.can(session.user.permissions, Permission.debtsRead)) {
      throw const UnauthorizedFailure(
        'Vous n\'avez pas la permission de consulter les dettes.',
      );
    }
    return _repository.listForgivenDebts(
      shopId: session.shop.id,
      customerId: customerId,
    );
  }
}

class ListPaidDebts {
  ListPaidDebts(this._repository);

  final DebtRepository _repository;

  Future<List<Debt>> call({
    required AuthSession session,
    int? customerId,
  }) {
    if (!PermissionGuard.can(session.user.permissions, Permission.debtsRead)) {
      throw const UnauthorizedFailure(
        'Vous n\'avez pas la permission de consulter les dettes.',
      );
    }
    return _repository.listPaidDebts(
      shopId: session.shop.id,
      customerId: customerId,
    );
  }
}

class GetDebt {
  GetDebt(this._repository);

  final DebtRepository _repository;

  Future<Debt> call({
    required AuthSession session,
    required int debtId,
  }) {
    if (!PermissionGuard.can(session.user.permissions, Permission.debtsRead)) {
      throw const UnauthorizedFailure(
        'Vous n\'avez pas la permission de consulter les dettes.',
      );
    }
    return _repository.getDebt(
      shopId: session.shop.id,
      debtId: debtId,
    );
  }
}

class GetDebtDetail {
  GetDebtDetail(this._repository);

  final DebtRepository _repository;

  Future<DebtDetail> call({
    required AuthSession session,
    required int debtId,
  }) {
    if (!PermissionGuard.can(session.user.permissions, Permission.debtsRead)) {
      throw const UnauthorizedFailure(
        'Vous n\'avez pas la permission de consulter les dettes.',
      );
    }
    return _repository.getDebtDetail(
      shopId: session.shop.id,
      debtId: debtId,
    );
  }
}

class GetDebtDetailReminder {
  GetDebtDetailReminder(this._repository);

  final DebtRepository _repository;

  Future<DebtReminder> call({
    required AuthSession session,
    required int debtId,
  }) {
    if (!PermissionGuard.can(session.user.permissions, Permission.debtsRead)) {
      throw const UnauthorizedFailure(
        'Vous n\'avez pas la permission d\'envoyer un rappel.',
      );
    }
    return _repository.getDebtReminder(
      shopId: session.shop.id,
      debtId: debtId,
      shopName: session.shop.name,
    );
  }
}

class RecordDebtPayment {
  RecordDebtPayment(this._repository);

  final DebtRepository _repository;

  Future<DebtPaymentResult> call({
    required AuthSession session,
    required int debtId,
    required RecordDebtPaymentInput input,
  }) {
    if (!PermissionGuard.can(session.user.permissions, Permission.debtsPayment) ||
        !PermissionGuard.can(session.user.permissions, Permission.paymentsCreate)) {
      throw const UnauthorizedFailure(
        'Vous n\'avez pas la permission d\'enregistrer un paiement.',
      );
    }
    return _repository.recordPayment(
      shopId: session.shop.id,
      debtId: debtId,
      userId: session.user.id,
      input: input,
    );
  }
}

class ForgiveDebt {
  ForgiveDebt(this._repository);

  final DebtRepository _repository;

  Future<Debt> call({
    required AuthSession session,
    required int debtId,
    required String reason,
  }) {
    if (session.user.role != UserRole.owner) {
      throw const UnauthorizedFailure(
        'Seul le patron peut pardonner une dette.',
      );
    }
    if (!PermissionGuard.can(
      session.user.permissions,
      Permission.debtsForgive,
    )) {
      throw const UnauthorizedFailure(
        'Vous n\'avez pas la permission de pardonner une dette.',
      );
    }
    return _repository.forgiveDebt(
      shopId: session.shop.id,
      debtId: debtId,
      userId: session.user.id,
      reason: reason,
    );
  }
}
