import 'package:equatable/equatable.dart';

enum CashSessionStatus {
  open,
  closed;

  String get code => name;

  static CashSessionStatus fromCode(String code) => switch (code) {
        'closed' => CashSessionStatus.closed,
        _ => CashSessionStatus.open,
      };

  String get label => switch (this) {
        CashSessionStatus.open => 'Ouverte',
        CashSessionStatus.closed => 'Clôturée',
      };
}

enum CashRegisterType {
  cash,
  mtnMomo,
  moovMoney;

  String get code => switch (this) {
        CashRegisterType.cash => 'cash',
        CashRegisterType.mtnMomo => 'mtn_momo',
        CashRegisterType.moovMoney => 'moov_money',
      };

  static CashRegisterType fromCode(String code) => switch (code) {
        'mtn_momo' => CashRegisterType.mtnMomo,
        'moov_money' => CashRegisterType.moovMoney,
        _ => CashRegisterType.cash,
      };

  String get label => switch (this) {
        CashRegisterType.cash => 'Espèces',
        CashRegisterType.mtnMomo => 'MTN MoMo',
        CashRegisterType.moovMoney => 'Moov Money',
      };
}

enum CashMovementType {
  withdrawal,
  deposit;

  String get code => name;

  static CashMovementType fromCode(String code) => switch (code) {
        'deposit' => CashMovementType.deposit,
        _ => CashMovementType.withdrawal,
      };

  String get label => switch (this) {
        CashMovementType.withdrawal => 'Retrait',
        CashMovementType.deposit => 'Entrée',
      };
}

class CashSession extends Equatable {
  const CashSession({
    required this.id,
    required this.shopId,
    required this.openedBy,
    required this.openedByName,
    this.closedBy,
    this.closedByName,
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
  final int shopId;
  final int openedBy;
  final String openedByName;
  final int? closedBy;
  final String? closedByName;
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
  final CashSessionStatus status;
  final String? closingNote;
  final int createdAt;
  final int updatedAt;

  int get liveExpectedCash =>
      openingCash +
      salesCash +
      depositsCash -
      expensesCash -
      withdrawalsCash;

  int get liveExpectedMomo =>
      openingMomo +
      salesMomo +
      depositsMomo -
      expensesMomo -
      withdrawalsMomo;

  int get totalDifference =>
      (differenceCash ?? 0) + (differenceMomo ?? 0);

  bool get isOpen => status == CashSessionStatus.open;

  @override
  List<Object?> get props => [id, shopId, status, openedAt, closedAt];
}

class CashMovement extends Equatable {
  const CashMovement({
    required this.id,
    required this.shopId,
    required this.sessionId,
    required this.movementType,
    required this.registerType,
    required this.amount,
    this.note,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
  });

  final int id;
  final int shopId;
  final int sessionId;
  final CashMovementType movementType;
  final CashRegisterType registerType;
  final int amount;
  final String? note;
  final int createdBy;
  final String createdByName;
  final int createdAt;

  @override
  List<Object?> get props => [id, sessionId, amount, createdAt];
}

class CashSessionLiveTotals extends Equatable {
  const CashSessionLiveTotals({
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

  final int salesCash;
  final int salesMomo;
  final int expensesCash;
  final int expensesMomo;
  final int depositsCash;
  final int depositsMomo;
  final int withdrawalsCash;
  final int withdrawalsMomo;
  final int saleCount;

  @override
  List<Object?> get props => [
        salesCash,
        salesMomo,
        expensesCash,
        expensesMomo,
        saleCount,
      ];
}

class CashSessionListRow extends Equatable {
  const CashSessionListRow({
    required this.id,
    required this.openedAt,
    this.closedAt,
    required this.openedByName,
    required this.status,
    required this.differenceCash,
    required this.differenceMomo,
    required this.saleCount,
  });

  final int id;
  final int openedAt;
  final int? closedAt;
  final String openedByName;
  final CashSessionStatus status;
  final int differenceCash;
  final int differenceMomo;
  final int saleCount;

  int get totalDifference => differenceCash + differenceMomo;

  @override
  List<Object?> get props => [id, openedAt, status];
}

class OpenCashSessionInput extends Equatable {
  const OpenCashSessionInput({
    required this.openingCash,
    this.openingMomo = 0,
  });

  final int openingCash;
  final int openingMomo;

  @override
  List<Object?> get props => [openingCash, openingMomo];
}

class CloseCashSessionInput extends Equatable {
  const CloseCashSessionInput({
    required this.countedCash,
    required this.countedMomo,
    this.closingNote,
    this.ownerPin,
  });

  final int countedCash;
  final int countedMomo;
  final String? closingNote;
  final String? ownerPin;

  @override
  List<Object?> get props => [countedCash, countedMomo, closingNote, ownerPin];
}

class RecordCashMovementInput extends Equatable {
  const RecordCashMovementInput({
    required this.movementType,
    required this.registerType,
    required this.amount,
    this.note,
  });

  final CashMovementType movementType;
  final CashRegisterType registerType;
  final int amount;
  final String? note;

  @override
  List<Object?> get props => [movementType, registerType, amount];
}
