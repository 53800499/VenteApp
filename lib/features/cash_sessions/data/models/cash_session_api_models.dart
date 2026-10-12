class CashSessionApiDto {
  const CashSessionApiDto({
    required this.id,
    this.serverId,
    required this.shopId,
    required this.openedBy,
    this.closedBy,
    required this.openedAt,
    this.closedAt,
    this.submittedAt,
    this.submittedBy,
    this.approvedAt,
    this.approvedBy,
    required this.openingCash,
    required this.openingMomo,
    required this.salesCash,
    required this.salesMomo,
    required this.expensesCash,
    required this.expensesMomo,
    required this.depositsCash,
    required this.depositsMomo,
    required this.withdrawalsCash,
    required this.withdrawalsMomo,
    this.expectedCash,
    this.expectedMomo,
    this.countedCash,
    this.countedMomo,
    this.differenceCash,
    this.differenceMomo,
    required this.saleCount,
    required this.status,
    this.closingNote,
    this.justificationCategory,
    this.justificationNote,
    this.reviewNote,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String? serverId;
  final int shopId;
  final int openedBy;
  final int? closedBy;
  final int openedAt;
  final int? closedAt;
  final int? submittedAt;
  final int? submittedBy;
  final int? approvedAt;
  final int? approvedBy;
  final int openingCash;
  final int openingMomo;
  final int salesCash;
  final int salesMomo;
  final int expensesCash;
  final int expensesMomo;
  final int depositsCash;
  final int depositsMomo;
  final int withdrawalsCash;
  final int withdrawalsMomo;
  final int? expectedCash;
  final int? expectedMomo;
  final int? countedCash;
  final int? countedMomo;
  final int? differenceCash;
  final int? differenceMomo;
  final int saleCount;
  final String status;
  final String? closingNote;
  final String? justificationCategory;
  final String? justificationNote;
  final String? reviewNote;
  final int createdAt;
  final int updatedAt;

  factory CashSessionApiDto.fromJson(Map<String, dynamic> json) {
    return CashSessionApiDto(
      id: (json['id'] as num).toInt(),
      serverId: json['serverId']?.toString() ?? json['server_id']?.toString(),
      shopId: (json['shopId'] as num?)?.toInt() ??
          (json['shop_id'] as num).toInt(),
      openedBy: (json['openedBy'] as num?)?.toInt() ??
          (json['opened_by'] as num).toInt(),
      closedBy: (json['closedBy'] as num?)?.toInt() ??
          (json['closed_by'] as num?)?.toInt(),
      openedAt: (json['openedAt'] as num?)?.toInt() ??
          (json['opened_at'] as num).toInt(),
      closedAt: (json['closedAt'] as num?)?.toInt() ??
          (json['closed_at'] as num?)?.toInt(),
      submittedAt: (json['submittedAt'] as num?)?.toInt() ??
          (json['submitted_at'] as num?)?.toInt(),
      submittedBy: (json['submittedBy'] as num?)?.toInt() ??
          (json['submitted_by'] as num?)?.toInt(),
      approvedAt: (json['approvedAt'] as num?)?.toInt() ??
          (json['approved_at'] as num?)?.toInt(),
      approvedBy: (json['approvedBy'] as num?)?.toInt() ??
          (json['approved_by'] as num?)?.toInt(),
      openingCash: (json['openingCash'] as num?)?.toInt() ??
          (json['opening_cash'] as num?)?.toInt() ??
          0,
      openingMomo: (json['openingMomo'] as num?)?.toInt() ??
          (json['opening_momo'] as num?)?.toInt() ??
          0,
      salesCash: (json['salesCash'] as num?)?.toInt() ??
          (json['sales_cash'] as num?)?.toInt() ??
          0,
      salesMomo: (json['salesMomo'] as num?)?.toInt() ??
          (json['sales_momo'] as num?)?.toInt() ??
          0,
      expensesCash: (json['expensesCash'] as num?)?.toInt() ??
          (json['expenses_cash'] as num?)?.toInt() ??
          0,
      expensesMomo: (json['expensesMomo'] as num?)?.toInt() ??
          (json['expenses_momo'] as num?)?.toInt() ??
          0,
      depositsCash: (json['depositsCash'] as num?)?.toInt() ??
          (json['deposits_cash'] as num?)?.toInt() ??
          0,
      depositsMomo: (json['depositsMomo'] as num?)?.toInt() ??
          (json['deposits_momo'] as num?)?.toInt() ??
          0,
      withdrawalsCash: (json['withdrawalsCash'] as num?)?.toInt() ??
          (json['withdrawals_cash'] as num?)?.toInt() ??
          0,
      withdrawalsMomo: (json['withdrawalsMomo'] as num?)?.toInt() ??
          (json['withdrawals_momo'] as num?)?.toInt() ??
          0,
      expectedCash: (json['expectedCash'] as num?)?.toInt() ??
          (json['expected_cash'] as num?)?.toInt(),
      expectedMomo: (json['expectedMomo'] as num?)?.toInt() ??
          (json['expected_momo'] as num?)?.toInt(),
      countedCash: (json['countedCash'] as num?)?.toInt() ??
          (json['counted_cash'] as num?)?.toInt(),
      countedMomo: (json['countedMomo'] as num?)?.toInt() ??
          (json['counted_momo'] as num?)?.toInt(),
      differenceCash: (json['differenceCash'] as num?)?.toInt() ??
          (json['difference_cash'] as num?)?.toInt(),
      differenceMomo: (json['differenceMomo'] as num?)?.toInt() ??
          (json['difference_momo'] as num?)?.toInt(),
      saleCount: (json['saleCount'] as num?)?.toInt() ??
          (json['sale_count'] as num?)?.toInt() ??
          0,
      status: json['status'] as String? ?? 'closed',
      closingNote: json['closingNote'] as String? ??
          json['closing_note'] as String?,
      justificationCategory: json['justificationCategory'] as String? ??
          json['justification_category'] as String?,
      justificationNote: json['justificationNote'] as String? ??
          json['justification_note'] as String?,
      reviewNote: json['reviewNote'] as String? ??
          json['review_note'] as String?,
      createdAt: (json['createdAt'] as num?)?.toInt() ??
          (json['created_at'] as num).toInt(),
      updatedAt: (json['updatedAt'] as num?)?.toInt() ??
          (json['updated_at'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'openedAt': openedAt,
        'closedAt': closedAt,
        'submittedAt': submittedAt,
        'submittedBy': submittedBy,
        'approvedAt': approvedAt,
        'approvedBy': approvedBy,
        'openingCash': openingCash,
        'openingMomo': openingMomo,
        'salesCash': salesCash,
        'salesMomo': salesMomo,
        'expensesCash': expensesCash,
        'expensesMomo': expensesMomo,
        'depositsCash': depositsCash,
        'depositsMomo': depositsMomo,
        'withdrawalsCash': withdrawalsCash,
        'withdrawalsMomo': withdrawalsMomo,
        'expectedCash': expectedCash,
        'expectedMomo': expectedMomo,
        'countedCash': countedCash,
        'countedMomo': countedMomo,
        'differenceCash': differenceCash,
        'differenceMomo': differenceMomo,
        'saleCount': saleCount,
        'status': status,
        'closingNote': closingNote,
        'justificationCategory': justificationCategory,
        'justificationNote': justificationNote,
        'reviewNote': reviewNote,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}

class OpenCashSessionApiRequest {
  const OpenCashSessionApiRequest({
    required this.openingCash,
    this.openingMomo = 0,
  });

  final int openingCash;
  final int openingMomo;

  Map<String, dynamic> toJson() => {
        'openingCash': openingCash,
        'openingMomo': openingMomo,
      };
}

class SubmitCashSessionApiRequest {
  const SubmitCashSessionApiRequest({
    required this.countedCash,
    required this.countedMomo,
    this.closingNote,
    this.justificationCategory,
    this.justificationNote,
    required this.salesCash,
    required this.salesMomo,
    required this.expensesCash,
    required this.expensesMomo,
    required this.depositsCash,
    required this.depositsMomo,
    required this.withdrawalsCash,
    required this.withdrawalsMomo,
    required this.saleCount,
  });

  final int countedCash;
  final int countedMomo;
  final String? closingNote;
  final String? justificationCategory;
  final String? justificationNote;
  final int salesCash;
  final int salesMomo;
  final int expensesCash;
  final int expensesMomo;
  final int depositsCash;
  final int depositsMomo;
  final int withdrawalsCash;
  final int withdrawalsMomo;
  final int saleCount;

  Map<String, dynamic> toJson() => {
        'countedCash': countedCash,
        'countedMomo': countedMomo,
        if (closingNote != null) 'closingNote': closingNote,
        if (justificationCategory != null)
          'justificationCategory': justificationCategory,
        if (justificationNote != null) 'justificationNote': justificationNote,
        'salesCash': salesCash,
        'salesMomo': salesMomo,
        'expensesCash': expensesCash,
        'expensesMomo': expensesMomo,
        'depositsCash': depositsCash,
        'depositsMomo': depositsMomo,
        'withdrawalsCash': withdrawalsCash,
        'withdrawalsMomo': withdrawalsMomo,
        'saleCount': saleCount,
      };
}

class ApproveCashSessionApiRequest {
  const ApproveCashSessionApiRequest({
    this.reviewNote,
  });

  final String? reviewNote;

  Map<String, dynamic> toJson() => {
        if (reviewNote != null) 'reviewNote': reviewNote,
      };
}

class OwnerDropApiRequest {
  const OwnerDropApiRequest({
    required this.amount,
    this.registerType = 'cash',
    this.note,
  });

  final int amount;
  final String registerType;
  final String? note;

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'registerType': registerType,
        if (note != null) 'note': note,
      };
}

class CloseCashSessionApiRequest {
  const CloseCashSessionApiRequest({
    required this.countedCash,
    required this.countedMomo,
    this.closingNote,
    this.ownerPin,
    this.justificationCategory,
    this.justificationNote,
    required this.salesCash,
    required this.salesMomo,
    required this.expensesCash,
    required this.expensesMomo,
    required this.depositsCash,
    required this.depositsMomo,
    required this.withdrawalsCash,
    required this.withdrawalsMomo,
    required this.saleCount,
  });

  final int countedCash;
  final int countedMomo;
  final String? closingNote;
  final String? ownerPin;
  final String? justificationCategory;
  final String? justificationNote;
  final int salesCash;
  final int salesMomo;
  final int expensesCash;
  final int expensesMomo;
  final int depositsCash;
  final int depositsMomo;
  final int withdrawalsCash;
  final int withdrawalsMomo;
  final int saleCount;

  Map<String, dynamic> toJson() => {
        'countedCash': countedCash,
        'countedMomo': countedMomo,
        if (closingNote != null) 'closingNote': closingNote,
        if (ownerPin != null) 'ownerPin': ownerPin,
        if (justificationCategory != null)
          'justificationCategory': justificationCategory,
        if (justificationNote != null) 'justificationNote': justificationNote,
        'salesCash': salesCash,
        'salesMomo': salesMomo,
        'expensesCash': expensesCash,
        'expensesMomo': expensesMomo,
        'depositsCash': depositsCash,
        'depositsMomo': depositsMomo,
        'withdrawalsCash': withdrawalsCash,
        'withdrawalsMomo': withdrawalsMomo,
        'saleCount': saleCount,
      };
}

class CashMovementApiDto {
  const CashMovementApiDto({
    required this.id,
    required this.sessionId,
    required this.movementType,
    required this.registerType,
    required this.amount,
    this.note,
    required this.createdBy,
    required this.createdAt,
  });

  final int id;
  final int sessionId;
  final String movementType;
  final String registerType;
  final int amount;
  final String? note;
  final int createdBy;
  final int createdAt;

  factory CashMovementApiDto.fromJson(Map<String, dynamic> json) {
    return CashMovementApiDto(
      id: (json['id'] as num).toInt(),
      sessionId: (json['sessionId'] as num?)?.toInt() ??
          (json['session_id'] as num).toInt(),
      movementType: json['movementType'] as String? ??
          json['movement_type'] as String? ??
          'deposit',
      registerType: json['registerType'] as String? ??
          json['register_type'] as String? ??
          'cash',
      amount: (json['amount'] as num).toInt(),
      note: json['note'] as String?,
      createdBy: (json['createdBy'] as num?)?.toInt() ??
          (json['created_by'] as num).toInt(),
      createdAt: (json['createdAt'] as num?)?.toInt() ??
          (json['created_at'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'movementType': movementType,
        'registerType': registerType,
        'amount': amount,
        'note': note,
      };
}

class CreateCashMovementApiRequest {
  const CreateCashMovementApiRequest({
    required this.movementType,
    required this.registerType,
    required this.amount,
    this.note,
  });

  final String movementType;
  final String registerType;
  final int amount;
  final String? note;

  Map<String, dynamic> toJson() => {
        'movementType': movementType,
        'registerType': registerType,
        'amount': amount,
        if (note != null && note!.isNotEmpty) 'note': note,
      };
}
