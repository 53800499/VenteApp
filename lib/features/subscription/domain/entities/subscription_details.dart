import 'package:equatable/equatable.dart';

class SubscriptionPlanDetail extends Equatable {
  final String code;
  final String name;
  final double priceMonthly;
  final double priceYearly;
  final List<String> grantedModules;
  final int maxUsers;
  final int maxShops;

  const SubscriptionPlanDetail({
    required this.code,
    required this.name,
    required this.priceMonthly,
    required this.priceYearly,
    required this.grantedModules,
    required this.maxUsers,
    required this.maxShops,
  });

  @override
  List<Object?> get props => [code, name, priceMonthly, priceYearly, grantedModules, maxUsers, maxShops];
}

class PaymentTransactionRecord extends Equatable {
  final String id;
  final DateTime date;
  final String planName;
  final double amount;
  final String currency;
  final String provider;
  final String status;

  const PaymentTransactionRecord({
    required this.id,
    required this.date,
    required this.planName,
    required this.amount,
    required this.currency,
    required this.provider,
    required this.status,
  });

  @override
  List<Object?> get props => [id, date, planName, amount, currency, provider, status];
}

class SubscriptionDetails extends Equatable {
  final String planCode;
  final String planName;
  final String status; // 'ACTIVE', 'GRACE', 'EXPIRED', etc.
  final DateTime startedAt;
  final DateTime expiresAt;
  final DateTime graceUntil;
  final bool autoRenew;
  final List<String> grantedModules;
  final int maxUsers;
  final int maxShops;
  final int currentUsersCount;
  final int currentShopsCount;
  final List<PaymentTransactionRecord> paymentHistory;

  const SubscriptionDetails({
    required this.planCode,
    required this.planName,
    required this.status,
    required this.startedAt,
    required this.expiresAt,
    required this.graceUntil,
    required this.autoRenew,
    required this.grantedModules,
    required this.maxUsers,
    required this.maxShops,
    required this.currentUsersCount,
    required this.currentShopsCount,
    required this.paymentHistory,
  });

  bool get isActive => status == 'ACTIVE' || status == 'GRACE';

  @override
  List<Object?> get props => [
        planCode,
        planName,
        status,
        startedAt,
        expiresAt,
        graceUntil,
        autoRenew,
        grantedModules,
        maxUsers,
        maxShops,
        currentUsersCount,
        currentShopsCount,
        paymentHistory,
      ];
}
