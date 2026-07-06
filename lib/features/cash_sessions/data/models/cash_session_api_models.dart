class CashSessionApiDto {
  const CashSessionApiDto({
    required this.id,
    this.serverId,
    required this.shopId,
    required this.openedBy,
    this.closedBy,
    required this.openedAt,
    this.closedAt,
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
      createdAt: (json['createdAt'] as num?)?.toInt() ??
          (json['created_at'] as num).toInt(),
      updatedAt: (json['updatedAt'] as num?)?.toInt() ??
          (json['updated_at'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'openedAt': openedAt,
        'closedAt': closedAt,
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

class CloseCashSessionApiRequest {
  const CloseCashSessionApiRequest({
    required this.countedCash,
    required this.countedMomo,
    this.closingNote,
    this.ownerPin,
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
        'closingNote': closingNote,
        if (ownerPin != null) 'ownerPin': ownerPin,
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
