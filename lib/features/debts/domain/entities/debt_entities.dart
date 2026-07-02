import 'package:equatable/equatable.dart';

enum DebtStatus { open, partial, paid, cancelled, forgiven }

enum DebtRepaymentMethod { cash, mtnMomo, moovMoney, other }

extension DebtStatusX on DebtStatus {
  String get code => switch (this) {
        DebtStatus.open => 'open',
        DebtStatus.partial => 'partial',
        DebtStatus.paid => 'paid',
        DebtStatus.cancelled => 'cancelled',
        DebtStatus.forgiven => 'forgiven',
      };

  static DebtStatus fromCode(String? code) => switch (code) {
        'partial' => DebtStatus.partial,
        'paid' => DebtStatus.paid,
        'cancelled' => DebtStatus.cancelled,
        'forgiven' => DebtStatus.forgiven,
        _ => DebtStatus.open,
      };

  bool get isRepayable =>
      this == DebtStatus.open || this == DebtStatus.partial;

  String get label => switch (this) {
        DebtStatus.open => 'Ouverte',
        DebtStatus.partial => 'Partielle',
        DebtStatus.paid => 'Soldée',
        DebtStatus.cancelled => 'Annulée',
        DebtStatus.forgiven => 'Pardonnée',
      };
}

extension DebtRepaymentMethodX on DebtRepaymentMethod {
  String get code => switch (this) {
        DebtRepaymentMethod.cash => 'cash',
        DebtRepaymentMethod.mtnMomo => 'mtn_momo',
        DebtRepaymentMethod.moovMoney => 'moov_money',
        DebtRepaymentMethod.other => 'other',
      };

  String get label => switch (this) {
        DebtRepaymentMethod.cash => 'Espèces',
        DebtRepaymentMethod.mtnMomo => 'MTN MoMo',
        DebtRepaymentMethod.moovMoney => 'Moov Money',
        DebtRepaymentMethod.other => 'Autre',
      };

  static DebtRepaymentMethod fromCode(String? code) => switch (code) {
        'mtn_momo' => DebtRepaymentMethod.mtnMomo,
        'moov_money' => DebtRepaymentMethod.moovMoney,
        'other' => DebtRepaymentMethod.other,
        _ => DebtRepaymentMethod.cash,
      };
}

class Debt extends Equatable {
  const Debt({
    required this.id,
    required this.shopId,
    required this.customerId,
    this.customerName,
    this.saleId,
    this.receiptNumber,
    required this.originalAmount,
    required this.amountPaid,
    required this.amountRemaining,
    required this.status,
    required this.createdAt,
    this.dueAt,
    this.serverId,
    this.isCritical = false,
  });

  final int id;
  final int shopId;
  final int customerId;
  final String? customerName;
  final int? saleId;
  final String? receiptNumber;
  final int originalAmount;
  final int amountPaid;
  final int amountRemaining;
  final DebtStatus status;
  final int createdAt;
  final int? dueAt;
  final String? serverId;
  final bool isCritical;

  int? get apiId => serverId != null ? int.tryParse(serverId!) : null;

  bool get isRepayable => status.isRepayable && amountRemaining > 0;

  double get repaymentProgress =>
      originalAmount > 0 ? amountPaid / originalAmount : 0;

  @override
  List<Object?> get props => [id, customerId, amountRemaining, status];
}

class DebtPaymentHistoryItem extends Equatable {
  const DebtPaymentHistoryItem({
    required this.id,
    required this.amount,
    required this.method,
    required this.createdAt,
    this.paymentId,
    this.reference,
    this.userName,
    this.receiptNumber,
  });

  final int id;
  final int? paymentId;
  final int amount;
  final DebtRepaymentMethod method;
  final String? reference;
  final String? userName;
  final String? receiptNumber;
  final int createdAt;

  @override
  List<Object?> get props => [id, amount, createdAt];
}

class DebtDetail extends Equatable {
  const DebtDetail({
    required this.debt,
    required this.payments,
    this.customerName,
    this.daysWithoutPayment = 0,
    this.lastPaymentAt,
    this.forgiveness,
  });

  final Debt debt;
  final String? customerName;
  final List<DebtPaymentHistoryItem> payments;
  final int daysWithoutPayment;
  final int? lastPaymentAt;
  final DebtForgivenessInfo? forgiveness;

  @override
  List<Object?> get props => [debt, payments.length, debt.status, forgiveness];
}

/// Métadonnées d'un pardon de dette (audit `debt_forgiven`).
class DebtForgivenessInfo extends Equatable {
  const DebtForgivenessInfo({
    required this.forgivenAt,
    required this.reason,
    required this.forgivenAmount,
    this.forgivenByName,
  });

  final int forgivenAt;
  final String reason;
  final int forgivenAmount;
  final String? forgivenByName;

  @override
  List<Object?> get props => [forgivenAt, reason, forgivenAmount];
}

class ForgivenDebtEntry extends Equatable {
  const ForgivenDebtEntry({
    required this.debt,
    required this.forgiveness,
    this.customerName,
  });

  final Debt debt;
  final String? customerName;
  final DebtForgivenessInfo forgiveness;

  @override
  List<Object?> get props => [debt.id, forgiveness.forgivenAt];
}

class RecordDebtPaymentInput extends Equatable {
  const RecordDebtPaymentInput({
    required this.amount,
    required this.method,
    this.reference,
    this.amountTendered,
    this.note,
  });

  final int amount;
  final DebtRepaymentMethod method;
  final String? reference;
  final int? amountTendered;
  final String? note;

  @override
  List<Object?> get props => [amount, method, reference];
}

class DebtPaymentResult extends Equatable {
  const DebtPaymentResult({
    required this.debtId,
    required this.amount,
    required this.amountRemaining,
    required this.status,
    this.paymentId,
    this.receiptNumber,
    this.changeGiven = 0,
  });

  final int debtId;
  final int? paymentId;
  final String? receiptNumber;
  final int amount;
  final int changeGiven;
  final int amountRemaining;
  final DebtStatus status;

  @override
  List<Object?> get props => [debtId, amount, amountRemaining, status];
}
