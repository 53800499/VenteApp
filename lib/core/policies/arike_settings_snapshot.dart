enum NegativeStockMode {
  allow,
  warning,
  deny;

  static NegativeStockMode fromString(String? value) {
    switch (value?.toUpperCase()) {
      case 'ALLOW':
        return NegativeStockMode.allow;
      case 'DENY':
      case 'PREVENT':
      case 'FORBID':
        return NegativeStockMode.deny;
      case 'WARNING':
      default:
        return NegativeStockMode.warning;
    }
  }

  String toIsoString() => name.toUpperCase();
}

class CompanySettings {
  const CompanySettings({
    required this.name,
    this.phone,
    this.address,
    this.logoPath,
    this.currency = 'FCFA',
    this.language = 'fr',
  });

  final String name;
  final String? phone;
  final String? address;
  final String? logoPath;
  final String currency;
  final String language;

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'address': address,
        'logoPath': logoPath,
        'currency': currency,
        'language': language,
      };

  factory CompanySettings.fromJson(Map<String, dynamic> json) => CompanySettings(
        name: json['name'] as String? ?? 'Ma Boutique',
        phone: json['phone'] as String?,
        address: json['address'] as String?,
        logoPath: json['logoPath'] as String?,
        currency: json['currency'] as String? ?? 'FCFA',
        language: json['language'] as String? ?? 'fr',
      );
}

class SalesSettings {
  const SalesSettings({
    this.allowCredit = true,
    this.allowDiscount = true,
    this.maxDiscountPercent = 100.0,
    this.allowPriceOverride = true,
    this.requireSaleConfirmation = false,
    this.allowMinimumPriceBypass = false,
  });

  final bool allowCredit;
  final bool allowDiscount;
  final double maxDiscountPercent;
  final bool allowPriceOverride;
  final bool requireSaleConfirmation;
  final bool allowMinimumPriceBypass;

  Map<String, dynamic> toJson() => {
        'allowCredit': allowCredit,
        'allowDiscount': allowDiscount,
        'maxDiscountPercent': maxDiscountPercent,
        'allowPriceOverride': allowPriceOverride,
        'requireSaleConfirmation': requireSaleConfirmation,
        'allowMinimumPriceBypass': allowMinimumPriceBypass,
      };

  factory SalesSettings.fromJson(Map<String, dynamic> json) => SalesSettings(
        allowCredit: json['allowCredit'] as bool? ?? true,
        allowDiscount: json['allowDiscount'] as bool? ?? true,
        maxDiscountPercent: (json['maxDiscountPercent'] as num?)?.toDouble() ?? 100.0,
        allowPriceOverride: json['allowPriceOverride'] as bool? ?? true,
        requireSaleConfirmation: json['requireSaleConfirmation'] as bool? ?? false,
        allowMinimumPriceBypass: json['allowMinimumPriceBypass'] as bool? ?? false,
      );
}

class InventorySettings {
  const InventorySettings({
    this.negativeStockMode = NegativeStockMode.warning,
    this.defaultAlertThreshold = 5,
    this.trackLots = false,
  });

  final NegativeStockMode negativeStockMode;
  final int defaultAlertThreshold;
  final bool trackLots;

  Map<String, dynamic> toJson() => {
        'negativeStockMode': negativeStockMode.toIsoString(),
        'defaultAlertThreshold': defaultAlertThreshold,
        'trackLots': trackLots,
      };

  factory InventorySettings.fromJson(Map<String, dynamic> json) => InventorySettings(
        negativeStockMode: NegativeStockMode.fromString(json['negativeStockMode'] as String?),
        defaultAlertThreshold: json['defaultAlertThreshold'] as int? ?? 5,
        trackLots: json['trackLots'] as bool? ?? false,
      );
}

class CashSettings {
  const CashSettings({
    this.requireCashSessionOpening = false,
    this.requireCashSessionClosing = false,
    this.allowNegativeCashBalance = true,
  });

  final bool requireCashSessionOpening;
  final bool requireCashSessionClosing;
  final bool allowNegativeCashBalance;

  Map<String, dynamic> toJson() => {
        'requireCashSessionOpening': requireCashSessionOpening,
        'requireCashSessionClosing': requireCashSessionClosing,
        'allowNegativeCashBalance': allowNegativeCashBalance,
      };

  factory CashSettings.fromJson(Map<String, dynamic> json) => CashSettings(
        requireCashSessionOpening: json['requireCashSessionOpening'] as bool? ?? false,
        requireCashSessionClosing: json['requireCashSessionClosing'] as bool? ?? false,
        allowNegativeCashBalance: json['allowNegativeCashBalance'] as bool? ?? true,
      );
}

class OrderSettings {
  const OrderSettings({
    this.allowPartialDelivery = true,
    this.allowCustomerRefusal = true,
    this.allowProductReplacement = true,
  });

  final bool allowPartialDelivery;
  final bool allowCustomerRefusal;
  final bool allowProductReplacement;

  Map<String, dynamic> toJson() => {
        'allowPartialDelivery': allowPartialDelivery,
        'allowCustomerRefusal': allowCustomerRefusal,
        'allowProductReplacement': allowProductReplacement,
      };

  factory OrderSettings.fromJson(Map<String, dynamic> json) => OrderSettings(
        allowPartialDelivery: json['allowPartialDelivery'] as bool? ?? true,
        allowCustomerRefusal: json['allowCustomerRefusal'] as bool? ?? true,
        allowProductReplacement: json['allowProductReplacement'] as bool? ?? true,
      );
}

class ProcurementSettings {
  const ProcurementSettings({
    this.requireSupplierInvoice = false,
    this.defaultPaymentTermsDays = 30,
  });

  final bool requireSupplierInvoice;
  final int defaultPaymentTermsDays;

  Map<String, dynamic> toJson() => {
        'requireSupplierInvoice': requireSupplierInvoice,
        'defaultPaymentTermsDays': defaultPaymentTermsDays,
      };

  factory ProcurementSettings.fromJson(Map<String, dynamic> json) => ProcurementSettings(
        requireSupplierInvoice: json['requireSupplierInvoice'] as bool? ?? false,
        defaultPaymentTermsDays: json['defaultPaymentTermsDays'] as int? ?? 30,
      );
}

class DebtSettings {
  const DebtSettings({
    this.allowCreditSales = true,
    this.defaultCreditLimit = 0.0,
    this.maxOverdueDays = 60,
  });

  final bool allowCreditSales;
  final double defaultCreditLimit;
  final int maxOverdueDays;

  Map<String, dynamic> toJson() => {
        'allowCreditSales': allowCreditSales,
        'defaultCreditLimit': defaultCreditLimit,
        'maxOverdueDays': maxOverdueDays,
      };

  factory DebtSettings.fromJson(Map<String, dynamic> json) => DebtSettings(
        allowCreditSales: json['allowCreditSales'] as bool? ?? true,
        defaultCreditLimit: (json['defaultCreditLimit'] as num?)?.toDouble() ?? 0.0,
        maxOverdueDays: json['maxOverdueDays'] as int? ?? 60,
      );
}

class ReceiptSettings {
  const ReceiptSettings({
    this.autoPrint = false,
    this.receiptFooter,
    this.showQrCode = true,
  });

  final bool autoPrint;
  final String? receiptFooter;
  final bool showQrCode;

  Map<String, dynamic> toJson() => {
        'autoPrint': autoPrint,
        'receiptFooter': receiptFooter,
        'showQrCode': showQrCode,
      };

  factory ReceiptSettings.fromJson(Map<String, dynamic> json) => ReceiptSettings(
        autoPrint: json['autoPrint'] as bool? ?? false,
        receiptFooter: json['receiptFooter'] as String?,
        showQrCode: json['showQrCode'] as bool? ?? true,
      );
}

class NotificationSettings {
  const NotificationSettings({
    this.lowStockAlerts = true,
    this.dailySummary = true,
    this.syncAlerts = true,
  });

  final bool lowStockAlerts;
  final bool dailySummary;
  final bool syncAlerts;

  Map<String, dynamic> toJson() => {
        'lowStockAlerts': lowStockAlerts,
        'dailySummary': dailySummary,
        'syncAlerts': syncAlerts,
      };

  factory NotificationSettings.fromJson(Map<String, dynamic> json) => NotificationSettings(
        lowStockAlerts: json['lowStockAlerts'] as bool? ?? true,
        dailySummary: json['dailySummary'] as bool? ?? true,
        syncAlerts: json['syncAlerts'] as bool? ?? true,
      );
}

class SyncSettings {
  const SyncSettings({
    this.enabled = true,
    this.wifiOnly = false,
    this.lastAt,
  });

  final bool enabled;
  final bool wifiOnly;
  final int? lastAt;

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'wifiOnly': wifiOnly,
        'lastAt': lastAt,
      };

  factory SyncSettings.fromJson(Map<String, dynamic> json) => SyncSettings(
        enabled: json['enabled'] as bool? ?? true,
        wifiOnly: json['wifiOnly'] as bool? ?? false,
        lastAt: json['lastAt'] as int?,
      );
}

class SecuritySettings {
  const SecuritySettings({
    this.autoLockMinutes = 5,
    this.requireBiometrics = false,
  });

  final int autoLockMinutes;
  final bool requireBiometrics;

  Map<String, dynamic> toJson() => {
        'autoLockMinutes': autoLockMinutes,
        'requireBiometrics': requireBiometrics,
      };

  factory SecuritySettings.fromJson(Map<String, dynamic> json) => SecuritySettings(
        autoLockMinutes: json['autoLockMinutes'] as int? ?? 5,
        requireBiometrics: json['requireBiometrics'] as bool? ?? false,
      );
}

/// Snapshot complet et immuable des paramètres ARIKE.
class ArikeSettingsSnapshot {
  const ArikeSettingsSnapshot({
    required this.version,
    required this.company,
    required this.sales,
    required this.inventory,
    required this.orders,
    required this.procurement,
    required this.debts,
    required this.cash,
    required this.receipts,
    required this.notifications,
    required this.sync,
    required this.security,
    required this.updatedAt,
  });

  final int version;
  final CompanySettings company;
  final SalesSettings sales;
  final InventorySettings inventory;
  final OrderSettings orders;
  final ProcurementSettings procurement;
  final DebtSettings debts;
  final CashSettings cash;
  final ReceiptSettings receipts;
  final NotificationSettings notifications;
  final SyncSettings sync;
  final SecuritySettings security;
  final DateTime updatedAt;

  /// Valeurs par défaut garantissant 100% de rétrocompatibilité.
  factory ArikeSettingsSnapshot.defaultSnapshot({int version = 1}) {
    return ArikeSettingsSnapshot(
      version: version,
      company: const CompanySettings(name: 'Ma Boutique'),
      sales: const SalesSettings(),
      inventory: const InventorySettings(),
      orders: const OrderSettings(),
      procurement: const ProcurementSettings(),
      debts: const DebtSettings(),
      cash: const CashSettings(),
      receipts: const ReceiptSettings(),
      notifications: const NotificationSettings(),
      sync: const SyncSettings(),
      security: const SecuritySettings(),
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'company': company.toJson(),
        'sales': sales.toJson(),
        'inventory': inventory.toJson(),
        'orders': orders.toJson(),
        'procurement': procurement.toJson(),
        'debts': debts.toJson(),
        'cash': cash.toJson(),
        'receipts': receipts.toJson(),
        'notifications': notifications.toJson(),
        'sync': sync.toJson(),
        'security': security.toJson(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ArikeSettingsSnapshot.fromJson(Map<String, dynamic> json) {
    return ArikeSettingsSnapshot(
      version: json['version'] as int? ?? 1,
      company: CompanySettings.fromJson(json['company'] as Map<String, dynamic>? ?? {}),
      sales: SalesSettings.fromJson(json['sales'] as Map<String, dynamic>? ?? {}),
      inventory: InventorySettings.fromJson(json['inventory'] as Map<String, dynamic>? ?? {}),
      orders: OrderSettings.fromJson(json['orders'] as Map<String, dynamic>? ?? {}),
      procurement: ProcurementSettings.fromJson(json['procurement'] as Map<String, dynamic>? ?? {}),
      debts: DebtSettings.fromJson(json['debts'] as Map<String, dynamic>? ?? {}),
      cash: CashSettings.fromJson(json['cash'] as Map<String, dynamic>? ?? {}),
      receipts: ReceiptSettings.fromJson(json['receipts'] as Map<String, dynamic>? ?? {}),
      notifications: NotificationSettings.fromJson(json['notifications'] as Map<String, dynamic>? ?? {}),
      sync: SyncSettings.fromJson(json['sync'] as Map<String, dynamic>? ?? {}),
      security: SecuritySettings.fromJson(json['security'] as Map<String, dynamic>? ?? {}),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
