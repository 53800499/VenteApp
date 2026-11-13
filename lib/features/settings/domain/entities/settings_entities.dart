// Module 10 — Paramètres & Configuration boutique.

class ShopSettings {
  const ShopSettings({
    required this.name,
    this.phone,
    this.address,
    this.logoPath,
  });

  final String name;
  final String? phone;
  final String? address;
  final String? logoPath;
}

class LocalizationSettings {
  const LocalizationSettings({
    required this.currency,
    required this.language,
  });

  final String currency;
  final String language;
}

class InventorySettings {
  const InventorySettings({required this.defaultAlertThreshold});

  final int defaultAlertThreshold;
}

class CommerceSettings {
  const CommerceSettings({
    this.pricingTiersEnabled = false,
    this.pricingGridMode = 'STANDARD', // 'STANDARD', 'RETAIL_WHOLESALE', 'MULTI_TIER'
    this.negativeStockMode = 'warning', // 'forbidden', 'warning', 'allowed'
    this.confirmBeforeValidation = true,
    this.allowCreditSales = true,
    this.autoPrintReceipt = false,
    this.allowPriceModification = false,
    this.maxCancelDelayHours = 24,
    this.requireOpeningSession = true,
    this.allowedDiscrepancyFcfa = 500,
    this.discrepancyAction = 'reason', // 'reason', 'admin_approval', 'block_closing'
    this.defaultCreditLimit = 100000,
    this.blockOverlimitClients = true,
    this.warnBeforeDueDate = true,
    this.requireReasonForForgiveness = true,
    this.requireReceptionValidation = true,
    this.updateWeightedAverageCost = true,
    this.createSupplierDebtAutomatically = true,
    this.replacementPolicy = 'with_validation', // 'with_validation', 'automatic', 'disabled'
    this.requirePreparationStep = true,
    this.allowPartialDeliveries = true,
    this.requireProofOfDelivery = false,
    this.paperFormat = '58mm', // '58mm', '80mm', 'A4'
    this.showQrCode = true,
    this.showSellerName = true,
    this.enabledModules = const {
      'SALES': true,
      'INVENTORY': true,
      'PROCUREMENT': true,
      'ORDERS_DELIVERIES': true,
      'DEBTS': true,
      'CASH_SESSIONS': true,
      'FX_EXCHANGE': true,
    },
  });

  final bool pricingTiersEnabled;
  final String pricingGridMode;
  final String negativeStockMode;
  final bool confirmBeforeValidation;
  final bool allowCreditSales;
  final bool autoPrintReceipt;
  final bool allowPriceModification;
  final int maxCancelDelayHours;
  final bool requireOpeningSession;
  final int allowedDiscrepancyFcfa;
  final String discrepancyAction;
  final int defaultCreditLimit;
  final bool blockOverlimitClients;
  final bool warnBeforeDueDate;
  final bool requireReasonForForgiveness;
  final bool requireReceptionValidation;
  final bool updateWeightedAverageCost;
  final bool createSupplierDebtAutomatically;
  final String replacementPolicy;
  final bool requirePreparationStep;
  final bool allowPartialDeliveries;
  final bool requireProofOfDelivery;
  final String paperFormat;
  final bool showQrCode;
  final bool showSellerName;
  final Map<String, bool> enabledModules;

  bool isModuleActive(String moduleKey) => enabledModules[moduleKey] ?? true;
}

class SecuritySettings {
  const SecuritySettings({required this.autoLockMinutes});

  final int autoLockMinutes;
}

class ReceiptSettings {
  const ReceiptSettings({this.footer});

  final String? footer;
}

class BackupSettings {
  const BackupSettings({
    this.lastAt,
    this.path,
    required this.reminderRecommended,
  });

  final int? lastAt;
  final String? path;
  final bool reminderRecommended;
}

class SyncSettings {
  const SyncSettings({
    required this.enabled,
    this.lastAt,
  });

  final bool enabled;
  final int? lastAt;
}

class ShopConfiguration {
  const ShopConfiguration({
    required this.shop,
    required this.localization,
    required this.inventory,
    required this.commerce,
    required this.security,
    required this.receipts,
    required this.backup,
    required this.sync,
    required this.updatedAt,
  });

  final ShopSettings shop;
  final LocalizationSettings localization;
  final InventorySettings inventory;
  final CommerceSettings commerce;
  final SecuritySettings security;
  final ReceiptSettings receipts;
  final BackupSettings backup;
  final SyncSettings sync;
  final int updatedAt;
}

class UpdateShopSettingsInput {
  const UpdateShopSettingsInput({
    this.shopName,
    this.shopPhone,
    this.shopAddress,
    this.shopLogoPath,
    this.defaultAlertThreshold,
    this.autoLockMinutes,
    this.receiptFooter,
    this.pricingTiersEnabled,
    this.pricingGridMode,
    this.toggledModuleKey,
    this.isModuleEnabled,
    this.negativeStockMode,
    this.confirmBeforeValidation,
    this.allowCreditSales,
    this.autoPrintReceipt,
    this.allowPriceModification,
    this.maxCancelDelayHours,
    this.requireOpeningSession,
    this.allowedDiscrepancyFcfa,
    this.discrepancyAction,
    this.defaultCreditLimit,
    this.blockOverlimitClients,
    this.warnBeforeDueDate,
    this.requireReasonForForgiveness,
    this.requireReceptionValidation,
    this.updateWeightedAverageCost,
    this.createSupplierDebtAutomatically,
    this.replacementPolicy,
    this.requirePreparationStep,
    this.allowPartialDeliveries,
    this.requireProofOfDelivery,
    this.paperFormat,
    this.showQrCode,
    this.showSellerName,
  });

  final String? shopName;
  final String? shopPhone;
  final String? shopAddress;
  final String? shopLogoPath;
  final int? defaultAlertThreshold;
  final int? autoLockMinutes;
  final String? receiptFooter;
  final bool? pricingTiersEnabled;
  final String? pricingGridMode;
  final String? toggledModuleKey;
  final bool? isModuleEnabled;
  final String? negativeStockMode;
  final bool? confirmBeforeValidation;
  final bool? allowCreditSales;
  final bool? autoPrintReceipt;
  final bool? allowPriceModification;
  final int? maxCancelDelayHours;
  final bool? requireOpeningSession;
  final int? allowedDiscrepancyFcfa;
  final String? discrepancyAction;
  final int? defaultCreditLimit;
  final bool? blockOverlimitClients;
  final bool? warnBeforeDueDate;
  final bool? requireReasonForForgiveness;
  final bool? requireReceptionValidation;
  final bool? updateWeightedAverageCost;
  final bool? createSupplierDebtAutomatically;
  final String? replacementPolicy;
  final bool? requirePreparationStep;
  final bool? allowPartialDeliveries;
  final bool? requireProofOfDelivery;
  final String? paperFormat;
  final bool? showQrCode;
  final bool? showSellerName;

  bool get isEmpty =>
      shopName == null &&
      shopPhone == null &&
      shopAddress == null &&
      shopLogoPath == null &&
      defaultAlertThreshold == null &&
      autoLockMinutes == null &&
      receiptFooter == null &&
      pricingTiersEnabled == null &&
      pricingGridMode == null &&
      toggledModuleKey == null &&
      isModuleEnabled == null &&
      negativeStockMode == null &&
      confirmBeforeValidation == null &&
      allowCreditSales == null &&
      autoPrintReceipt == null &&
      allowPriceModification == null &&
      maxCancelDelayHours == null &&
      requireOpeningSession == null &&
      allowedDiscrepancyFcfa == null &&
      discrepancyAction == null &&
      defaultCreditLimit == null &&
      blockOverlimitClients == null &&
      warnBeforeDueDate == null &&
      requireReasonForForgiveness == null &&
      requireReceptionValidation == null &&
      updateWeightedAverageCost == null &&
      createSupplierDebtAutomatically == null &&
      replacementPolicy == null &&
      requirePreparationStep == null &&
      allowPartialDeliveries == null &&
      requireProofOfDelivery == null &&
      paperFormat == null &&
      showQrCode == null &&
      showSellerName == null;

  /// Champs synchronisés avec l'API cloud (hors préférences locales).
  bool get hasRemoteFields =>
      shopName != null ||
      shopPhone != null ||
      shopAddress != null ||
      shopLogoPath != null ||
      defaultAlertThreshold != null ||
      autoLockMinutes != null ||
      receiptFooter != null;
}

class RecordBackupInput {
  const RecordBackupInput({this.path});

  final String? path;
}

class UpdateSyncSettingsInput {
  const UpdateSyncSettingsInput({
    this.enabled,
    this.lastSyncAt,
  });

  final bool? enabled;
  final int? lastSyncAt;

  bool get isEmpty => enabled == null && lastSyncAt == null;
}

class RecordBackupResult {
  const RecordBackupResult({
    required this.backup,
    required this.recordedAt,
  });

  final BackupSettings backup;
  final int recordedAt;
}

const backupReminderAgeMs = 7 * 24 * 60 * 60 * 1000;
const autoLockMinuteOptions = [1, 5, 15, 30, 60, 120];
