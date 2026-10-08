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
  final String? planCode;
  final double amount;
  final String currency;
  final String provider;
  final String? reference;
  final String status;
  final int bonusDays;
  final DateTime? expiresAt;

  const PaymentTransactionRecord({
    required this.id,
    required this.date,
    required this.planName,
    this.planCode,
    required this.amount,
    required this.currency,
    required this.provider,
    this.reference,
    required this.status,
    this.bonusDays = 0,
    this.expiresAt,
  });

  @override
  List<Object?> get props => [
        id,
        date,
        planName,
        planCode,
        amount,
        currency,
        provider,
        reference,
        status,
        bonusDays,
        expiresAt,
      ];
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
  final List<String> capabilities;
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
    this.capabilities = const [],
    required this.maxUsers,
    required this.maxShops,
    required this.currentUsersCount,
    required this.currentShopsCount,
    required this.paymentHistory,
  });

  bool get isActive => status == 'ACTIVE' || status == 'TRIAL' || status == 'GRACE';
  bool get isTrial => status == 'TRIAL';
  bool get isPendingActivation => status == 'PENDING_ACTIVATION';
  bool get isRevoked => status == 'REVOKED' || status == 'SUSPENDED';
  bool get isExpired => status == 'EXPIRED';

  /// Indique si l'utilisateur est sur le forfait permanent gratuit (0 FCFA)
  bool get isFreePlan => planCode.toUpperCase() == 'FREE' || planCode.toUpperCase() == 'STARTER';

  /// Indique si l'abonnement autorise la sauvegarde et synchronisation Cloud
  bool get hasCloudSync {
    if (isFreePlan || isRevoked || isExpired) return false;
    if (capabilities.contains('CLOUD_SYNC')) return true;
    // Par défaut pour les forfaits payants actifs (Essentiel, Pro, Business)
    return isActive && !isFreePlan;
  }

  /// Indique si les données locales ne sont pas sécurisées par le Cloud (risque en cas de perte/casse)
  bool get isDataAtRisk => !hasCloudSync;

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
        capabilities,
        maxUsers,
        maxShops,
        currentUsersCount,
        currentShopsCount,
        paymentHistory,
      ];
}

