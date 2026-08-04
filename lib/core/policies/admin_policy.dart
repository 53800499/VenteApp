/// Représente une décision ou politique administrative imposée par le Back-Office ARIKE.
class AdminPolicy {
  const AdminPolicy({
    required this.code,
    required this.value,
    this.enforced = true,
    this.priority = 1,
    this.lockReason,
    this.version = 1,
  });

  /// Codes de politiques administratives reconnus par l'application ARIKE.
  static const String tenantStatus = 'TENANT_STATUS';
  static const String maxDiscountCap = 'MAX_DISCOUNT_CAP';
  static const String forceReadonly = 'FORCE_READONLY';
  static const String minAppVersion = 'MIN_APP_VERSION';
  static const String maxShopsLimit = 'MAX_SHOPS_LIMIT';
  static const String negativeStockOverride = 'NEGATIVE_STOCK_OVERRIDE';
  static const String creditSalesOverride = 'CREDIT_SALES_OVERRIDE';

  /// Le code unique identifiant la politique (ex: `MAX_DISCOUNT_CAP`).
  final String code;

  /// La valeur imposée par la politique (peut être bool, num, String, Map).
  final dynamic value;

  /// Indique si la politique doit être appliquée de manière stricte (priorité absolue).
  final bool enforced;

  /// Niveau de priorité de la politique (par défaut 1 = prioritaire).
  final int priority;

  /// Motif explicatif affiché à l'utilisateur lorsqu'il tente de modifier le réglage.
  final String? lockReason;

  /// Numéro de version de la politique pour la gestion du cache/sync.
  final int version;

  Map<String, dynamic> toJson() => {
        'code': code,
        'value': value,
        'enforced': enforced,
        'priority': priority,
        'lockReason': lockReason,
        'version': version,
      };

  factory AdminPolicy.fromJson(Map<String, dynamic> json) => AdminPolicy(
        code: json['code'] as String,
        value: json['value'],
        enforced: json['enforced'] as bool? ?? true,
        priority: json['priority'] as int? ?? 1,
        lockReason: json['lockReason'] as String?,
        version: json['version'] as int? ?? 1,
      );

  @override
  String toString() =>
      'AdminPolicy(code: $code, value: $value, enforced: $enforced, lockReason: $lockReason)';
}
