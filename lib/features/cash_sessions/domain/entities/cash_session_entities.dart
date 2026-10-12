import 'package:equatable/equatable.dart';

enum CashSessionStatus {
  open,
  submitted,
  reviewRequired,
  justified,
  approved,
  reopened,
  closed;

  String get code => switch (this) {
        CashSessionStatus.open => 'open',
        CashSessionStatus.submitted => 'submitted',
        CashSessionStatus.reviewRequired => 'review_required',
        CashSessionStatus.justified => 'justified',
        CashSessionStatus.approved => 'approved',
        CashSessionStatus.reopened => 'reopened',
        CashSessionStatus.closed => 'closed',
      };

  static CashSessionStatus fromCode(String code) => switch (code) {
        'submitted' => CashSessionStatus.submitted,
        'review_required' => CashSessionStatus.reviewRequired,
        'justified' => CashSessionStatus.justified,
        'approved' => CashSessionStatus.approved,
        'reopened' => CashSessionStatus.reopened,
        'closed' => CashSessionStatus.closed,
        _ => CashSessionStatus.open,
      };

  String get label => switch (this) {
        CashSessionStatus.open => 'En cours',
        CashSessionStatus.submitted => 'Soumise',
        CashSessionStatus.reviewRequired => 'À vérifier',
        CashSessionStatus.justified => 'Justifiée',
        CashSessionStatus.approved => 'Validée',
        CashSessionStatus.reopened => 'Rouverte',
        CashSessionStatus.closed => 'Clôturée',
      };
}

enum CashRegisterType {
  cash,
  mtnMomo,
  moovMoney,
  celtis,
  bank;

  String get code => switch (this) {
        CashRegisterType.cash => 'cash',
        CashRegisterType.mtnMomo => 'mtn_momo',
        CashRegisterType.moovMoney => 'moov_money',
        CashRegisterType.celtis => 'celtis',
        CashRegisterType.bank => 'bank',
      };

  static CashRegisterType fromCode(String code) => switch (code) {
        'mtn_momo' => CashRegisterType.mtnMomo,
        'moov_money' => CashRegisterType.moovMoney,
        'celtis' => CashRegisterType.celtis,
        'bank' => CashRegisterType.bank,
        _ => CashRegisterType.cash,
      };

  String get label => switch (this) {
        CashRegisterType.cash => 'Espèces',
        CashRegisterType.mtnMomo => 'MTN MoMo',
        CashRegisterType.moovMoney => 'Moov Money',
        CashRegisterType.celtis => 'Celtis Cash',
        CashRegisterType.bank => 'Banque / Virement',
      };
}

enum CashMovementType {
  withdrawal,
  deposit,
  ownerDrop,
  bankDeposit;

  String get code => switch (this) {
        CashMovementType.withdrawal => 'withdrawal',
        CashMovementType.deposit => 'deposit',
        CashMovementType.ownerDrop => 'owner_drop',
        CashMovementType.bankDeposit => 'bank_deposit',
      };

  static CashMovementType fromCode(String code) => switch (code) {
        'deposit' => CashMovementType.deposit,
        'owner_drop' => CashMovementType.ownerDrop,
        'bank_deposit' => CashMovementType.bankDeposit,
        _ => CashMovementType.withdrawal,
      };

  String get label => switch (this) {
        CashMovementType.withdrawal => 'Retrait',
        CashMovementType.deposit => 'Entrée',
        CashMovementType.ownerDrop => 'Remise au patron',
        CashMovementType.bankDeposit => 'Dépôt banque',
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
  final int shopId;
  final int openedBy;
  final String openedByName;
  final int? closedBy;
  final String? closedByName;
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
  final CashSessionStatus status;
  final String? closingNote;
  final String? justificationCategory;
  final String? justificationNote;
  final String? reviewNote;
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

  bool get isOpen => status == CashSessionStatus.open || status == CashSessionStatus.reopened;
  bool get isPendingReview =>
      status == CashSessionStatus.submitted ||
      status == CashSessionStatus.reviewRequired ||
      status == CashSessionStatus.justified;
  bool get isApproved => status == CashSessionStatus.approved || status == CashSessionStatus.closed;
  bool get hasDifference => (differenceCash ?? 0) != 0 || (differenceMomo ?? 0) != 0;

  @override
  List<Object?> get props => [id, shopId, status, openedAt, closedAt, submittedAt, approvedAt];
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

class SubmitCashSessionClosingInput extends Equatable {
  const SubmitCashSessionClosingInput({
    required this.countedCash,
    required this.countedMomo,
    this.closingNote,
    this.justificationCategory,
    this.justificationNote,
  });

  final int countedCash;
  final int countedMomo;
  final String? closingNote;
  final String? justificationCategory;
  final String? justificationNote;

  @override
  List<Object?> get props => [
        countedCash,
        countedMomo,
        closingNote,
        justificationCategory,
        justificationNote,
      ];
}

class ApproveCashSessionInput extends Equatable {
  const ApproveCashSessionInput({
    this.reviewNote,
  });

  final String? reviewNote;

  @override
  List<Object?> get props => [reviewNote];
}

class RecordOwnerDropInput extends Equatable {
  const RecordOwnerDropInput({
    required this.amount,
    this.registerType = CashRegisterType.cash,
    this.note,
  });

  final int amount;
  final CashRegisterType registerType;
  final String? note;

  @override
  List<Object?> get props => [amount, registerType, note];
}

class CloseCashSessionInput extends Equatable {
  const CloseCashSessionInput({
    required this.countedCash,
    required this.countedMomo,
    this.closingNote,
    this.ownerPin,
    this.justificationCategory,
    this.justificationNote,
  });

  final int countedCash;
  final int countedMomo;
  final String? closingNote;
  final String? ownerPin;
  final String? justificationCategory;
  final String? justificationNote;

  @override
  List<Object?> get props => [
        countedCash,
        countedMomo,
        closingNote,
        ownerPin,
        justificationCategory,
        justificationNote,
      ];
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

extension CashDiscrepancyCategoryX on String {
  String get discrepancyCategoryLabel => switch (this) {
        'unconfirmed_payment' => 'Paiement Mobile Money non confirmé',
        'pending_transaction' => 'Transaction en attente',
        'entry_error' => 'Erreur de saisie vente',
        'unrecorded_expense' => 'Dépense urgente non saisie',
        'network_fee' => 'Frais de retrait Mobile Money',
        'cash_breakage' => 'Erreur rendu de monnaie',
        'other' => 'Autre motif',
        _ => this,
      };
}
