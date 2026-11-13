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
  final String status; // 'ACTIVE', 'GRACE', 'EXPIRED', 'PENDING_ACTIVATION', etc.
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
  final String? scheduledPlanCode;
  final DateTime? scheduledEffectiveAt;
  final int daysRemaining;
  final int graceDaysRemaining;
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
    this.scheduledPlanCode,
    this.scheduledEffectiveAt,
    this.daysRemaining = 0,
    this.graceDaysRemaining = 0,
    required this.paymentHistory,
  });

  bool get isActive => status == 'ACTIVE' || status == 'TRIAL' || status == 'GRACE';
  bool get isInGrace => status == 'GRACE';
  bool get isTrial => status == 'TRIAL';
  bool get isPendingActivation => status == 'PENDING_ACTIVATION';
  bool get isRevoked => status == 'REVOKED' || status == 'SUSPENDED';
  bool get isExpired => status == 'EXPIRED';

  /// Indique si l'utilisateur est sur le forfait permanent gratuit (0 FCFA)
  bool get isFreePlan => planCode.toUpperCase() == 'FREE' || planCode.toUpperCase() == 'STARTER';

  /// Indique si l'abonnement autorise la sauvegarde et synchronisation Cloud
  bool get hasCloudSync {
    if (isFreePlan || isRevoked || isExpired || isInGrace) return false;
    if (capabilities.contains('CLOUD_SYNC')) return true;
    // Par défaut pour les forfaits payants actifs (Essentiel, Pro, Business, Enterprise)
    return isActive && !isFreePlan;
  }

  /// Indique si les données locales ne sont pas sécurisées par le Cloud (risque en cas de perte/casse)
  bool get isDataAtRisk => !hasCloudSync;

  Map<String, dynamic> toJson() => {
        'planCode': planCode,
        'planName': planName,
        'status': status,
        'startedAt': startedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'graceUntil': graceUntil.toIso8601String(),
        'autoRenew': autoRenew,
        'grantedModules': grantedModules,
        'capabilities': capabilities,
        'maxUsers': maxUsers,
        'maxShops': maxShops,
        'currentUsersCount': currentUsersCount,
        'currentShopsCount': currentShopsCount,
        'scheduledPlanCode': scheduledPlanCode,
        'scheduledEffectiveAt': scheduledEffectiveAt?.toIso8601String(),
        'daysRemaining': daysRemaining,
        'graceDaysRemaining': graceDaysRemaining,
        'paymentHistory': paymentHistory
            .map((p) => {
                  'id': p.id,
                  'date': p.date.toIso8601String(),
                  'planName': p.planName,
                  'planCode': p.planCode,
                  'amount': p.amount,
                  'currency': p.currency,
                  'provider': p.provider,
                  'reference': p.reference,
                  'status': p.status,
                  'bonusDays': p.bonusDays,
                  'expiresAt': p.expiresAt?.toIso8601String(),
                })
            .toList(),
      };

  factory SubscriptionDetails.fromJson(Map<String, dynamic> json) {
    return SubscriptionDetails(
      planCode: json['planCode'] as String? ?? 'FREE',
      planName: json['planName'] as String? ?? 'ARIKE Gratuit',
      status: json['status'] as String? ?? 'ACTIVE',
      startedAt: json['startedAt'] != null
          ? DateTime.tryParse(json['startedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String) ??
              DateTime.now().add(const Duration(days: 30))
          : DateTime.now().add(const Duration(days: 30)),
      graceUntil: json['graceUntil'] != null
          ? DateTime.tryParse(json['graceUntil'] as String) ??
              DateTime.now().add(const Duration(days: 37))
          : DateTime.now().add(const Duration(days: 37)),
      autoRenew: json['autoRenew'] as bool? ?? false,
      grantedModules: (json['grantedModules'] as List?)?.cast<String>() ??
          const ['SALES', 'INVENTORY', 'CUSTOMERS', 'DEBTS'],
      capabilities: (json['capabilities'] as List?)?.cast<String>() ?? const [],
      maxUsers: json['maxUsers'] as int? ?? 1,
      maxShops: json['maxShops'] as int? ?? 1,
      currentUsersCount: json['currentUsersCount'] as int? ?? 1,
      currentShopsCount: json['currentShopsCount'] as int? ?? 1,
      scheduledPlanCode: json['scheduledPlanCode'] as String?,
      scheduledEffectiveAt: json['scheduledEffectiveAt'] != null
          ? DateTime.tryParse(json['scheduledEffectiveAt'] as String)
          : null,
      daysRemaining: (json['daysRemaining'] as num?)?.toInt() ?? 0,
      graceDaysRemaining: (json['graceDaysRemaining'] as num?)?.toInt() ?? 0,
      paymentHistory: (json['paymentHistory'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map((p) => PaymentTransactionRecord(
                    id: p['id']?.toString() ?? '',
                    date: p['date'] != null
                        ? DateTime.tryParse(p['date'].toString()) ?? DateTime.now()
                        : DateTime.now(),
                    planName: p['planName']?.toString() ?? '',
                    planCode: p['planCode']?.toString(),
                    amount: (p['amount'] as num?)?.toDouble() ?? 0.0,
                    currency: p['currency']?.toString() ?? 'FCFA',
                    provider: p['provider']?.toString() ?? 'Mobile Money',
                    reference: p['reference']?.toString(),
                    status: p['status']?.toString() ?? 'PAYÉ',
                    bonusDays: (p['bonusDays'] as num?)?.toInt() ?? 0,
                    expiresAt: p['expiresAt'] != null
                        ? DateTime.tryParse(p['expiresAt'].toString())
                        : null,
                  ))
              .toList() ??
          const [],
    );
  }

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
        scheduledPlanCode,
        scheduledEffectiveAt,
        daysRemaining,
        graceDaysRemaining,
        paymentHistory,
      ];
}
