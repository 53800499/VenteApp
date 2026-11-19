import '../entities/cash_session_entities.dart';

abstract class CashSessionRepository {
  Future<CashSession?> findOpenSession({required int shopId});

  Future<List<CashSessionListRow>> listSessions({
    required int shopId,
    int limit = 50,
  });

  Future<CashSession> getSession({
    required int shopId,
    required int sessionId,
  });

  Future<CashSessionLiveTotals> getLiveTotals({
    required int shopId,
    required int sessionId,
    required int openedAt,
    int? closedAt,
  });

  Future<List<CashMovement>> listMovements({
    required int shopId,
    required int sessionId,
  });

  Future<CashSession> openSession({
    required int shopId,
    required int userId,
    required OpenCashSessionInput input,
  });

  Future<CashSession> submitClosing({
    required int shopId,
    required int userId,
    required int sessionId,
    required SubmitCashSessionClosingInput input,
  });

  Future<CashSession> approveSession({
    required int shopId,
    required int userId,
    required int sessionId,
    required ApproveCashSessionInput input,
  });

  Future<CashSession> closeSession({
    required int shopId,
    required int userId,
    required int sessionId,
    required CloseCashSessionInput input,
  });

  Future<CashMovement> recordMovement({
    required int shopId,
    required int userId,
    required int sessionId,
    required RecordCashMovementInput input,
  });

  Future<CashMovement> recordOwnerDrop({
    required int shopId,
    required int userId,
    required int sessionId,
    required RecordOwnerDropInput input,
  });

  Future<List<CashSessionSoldProduct>> getSessionSoldProducts({
    required int shopId,
    required int openedAt,
    int? closedAt,
  });

  Future<void> syncFromRemote({required int shopId});
}
