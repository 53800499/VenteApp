import '../../domain/entities/debt_entities.dart';

class DebtApiDto {
  const DebtApiDto({
    required this.id,
    required this.customerId,
    this.customerName,
    this.saleId,
    required this.originalAmount,
    required this.amountPaid,
    required this.amountRemaining,
    required this.status,
    this.dueAt,
    required this.createdAt,
    this.updatedAt,
    this.isCritical = false,
    this.daysWithoutPayment = 0,
    this.lastPaymentAt,
    this.payments = const [],
  });

  factory DebtApiDto.fromJson(Map<String, dynamic> json) {
    final paymentsJson = json['payments'];
    return DebtApiDto(
      id: json['id'] as int,
      customerId: json['customerId'] as int,
      customerName: json['customerName'] as String?,
      saleId: json['saleId'] as int?,
      originalAmount: json['originalAmount'] as int,
      amountPaid: json['amountPaid'] as int? ?? 0,
      amountRemaining: json['amountRemaining'] as int,
      status: json['status'] as String? ?? 'open',
      dueAt: json['dueAt'] as int?,
      createdAt: json['createdAt'] as int,
      updatedAt: json['updatedAt'] as int?,
      isCritical: json['isCritical'] as bool? ?? false,
      daysWithoutPayment: json['daysWithoutPayment'] as int? ?? 0,
      lastPaymentAt: json['lastPaymentAt'] as int?,
      payments: paymentsJson is List
          ? paymentsJson
              .whereType<Map<String, dynamic>>()
              .map(DebtPaymentApiDto.fromJson)
              .toList()
          : const [],
    );
  }

  final int id;
  final int customerId;
  final String? customerName;
  final int? saleId;
  final int originalAmount;
  final int amountPaid;
  final int amountRemaining;
  final String status;
  final int? dueAt;
  final int createdAt;
  final int? updatedAt;
  final bool isCritical;
  final int daysWithoutPayment;
  final int? lastPaymentAt;
  final List<DebtPaymentApiDto> payments;
}

class DebtPaymentApiDto {
  const DebtPaymentApiDto({
    required this.id,
    required this.paymentId,
    required this.amount,
    required this.method,
    required this.createdAt,
    this.reference,
    this.userName,
  });

  factory DebtPaymentApiDto.fromJson(Map<String, dynamic> json) {
    return DebtPaymentApiDto(
      id: json['id'] as int,
      paymentId: json['paymentId'] as int,
      amount: json['amount'] as int,
      method: json['method'] as String? ?? 'cash',
      reference: json['reference'] as String?,
      createdAt: json['createdAt'] as int,
      userName: json['userName'] as String?,
    );
  }

  final int id;
  final int paymentId;
  final int amount;
  final String method;
  final String? reference;
  final int createdAt;
  final String? userName;

  DebtPaymentHistoryItem toEntity() {
    return DebtPaymentHistoryItem(
      id: id,
      paymentId: paymentId,
      amount: amount,
      method: DebtRepaymentMethodX.fromCode(method),
      reference: reference,
      userName: userName,
      createdAt: createdAt,
    );
  }
}

class DebtPaymentResultApiDto {
  const DebtPaymentResultApiDto({
    required this.debtId,
    required this.paymentId,
    this.receiptNumber,
    required this.amount,
    this.changeGiven = 0,
    required this.amountRemaining,
    required this.status,
  });

  factory DebtPaymentResultApiDto.fromJson(Map<String, dynamic> json) {
    return DebtPaymentResultApiDto(
      debtId: json['debtId'] as int,
      paymentId: json['paymentId'] as int,
      receiptNumber: json['receiptNumber'] as String?,
      amount: json['amount'] as int,
      changeGiven: json['changeGiven'] as int? ?? 0,
      amountRemaining: json['amountRemaining'] as int,
      status: json['status'] as String? ?? 'partial',
    );
  }

  final int debtId;
  final int paymentId;
  final String? receiptNumber;
  final int amount;
  final int changeGiven;
  final int amountRemaining;
  final String status;

  DebtPaymentResult toEntity({required int localDebtId}) {
    return DebtPaymentResult(
      debtId: localDebtId,
      paymentId: paymentId,
      receiptNumber: receiptNumber,
      amount: amount,
      changeGiven: changeGiven,
      amountRemaining: amountRemaining,
      status: DebtStatusX.fromCode(status),
    );
  }
}

class ForgiveDebtApiDto {
  const ForgiveDebtApiDto({
    required this.id,
    required this.status,
    required this.forgivenAt,
  });

  factory ForgiveDebtApiDto.fromJson(Map<String, dynamic> json) {
    return ForgiveDebtApiDto(
      id: json['id'] as int,
      status: json['status'] as String? ?? 'forgiven',
      forgivenAt: json['forgivenAt'] as int,
    );
  }

  final int id;
  final String status;
  final int forgivenAt;
}
