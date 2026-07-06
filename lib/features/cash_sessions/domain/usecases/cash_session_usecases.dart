import '../../../../core/errors/failures.dart';
import '../../../../shared/enums/user_role.dart';
import '../../../auth/domain/entities/auth_entities.dart';
import '../../../auth/domain/usecases/auth_usecases.dart';
import '../entities/cash_session_entities.dart';
import '../repositories/cash_session_repository.dart';

class FindOpenCashSession {
  const FindOpenCashSession(this._repository);

  final CashSessionRepository _repository;

  Future<CashSession?> call({required AuthSession session}) =>
      _repository.findOpenSession(shopId: session.shop.id);
}

class ListCashSessions {
  const ListCashSessions(this._repository);

  final CashSessionRepository _repository;

  Future<List<CashSessionListRow>> call({
    required AuthSession session,
    int limit = 50,
  }) =>
      _repository.listSessions(shopId: session.shop.id, limit: limit);
}

class GetCashSession {
  const GetCashSession(this._repository);

  final CashSessionRepository _repository;

  Future<CashSession> call({
    required AuthSession session,
    required int sessionId,
  }) =>
      _repository.getSession(shopId: session.shop.id, sessionId: sessionId);
}

class GetCashSessionLiveTotals {
  const GetCashSessionLiveTotals(this._repository);

  final CashSessionRepository _repository;

  Future<CashSessionLiveTotals> call({
    required AuthSession session,
    required CashSession cashSession,
  }) =>
      _repository.getLiveTotals(
        shopId: session.shop.id,
        sessionId: cashSession.id,
        openedAt: cashSession.openedAt,
        closedAt: cashSession.closedAt,
      );
}

class ListCashMovements {
  const ListCashMovements(this._repository);

  final CashSessionRepository _repository;

  Future<List<CashMovement>> call({
    required AuthSession session,
    required int sessionId,
  }) =>
      _repository.listMovements(shopId: session.shop.id, sessionId: sessionId);
}

class OpenCashSession {
  const OpenCashSession(this._repository);

  final CashSessionRepository _repository;

  Future<CashSession> call({
    required AuthSession session,
    required OpenCashSessionInput input,
  }) =>
      _repository.openSession(
        shopId: session.shop.id,
        userId: session.user.id,
        input: input,
      );
}

class CloseCashSession {
  const CloseCashSession(this._repository, this._verifyOwnerPin);

  final CashSessionRepository _repository;
  final VerifyShopOwnerPin _verifyOwnerPin;

  Future<CashSession> call({
    required AuthSession session,
    required int sessionId,
    required CloseCashSessionInput input,
  }) async {
    if (session.user.role != UserRole.owner) {
      final pin = input.ownerPin?.trim() ?? '';
      if (pin.length < 4) {
        throw const ValidationFailure(
          'Le PIN du patron est requis pour clôturer la caisse.',
        );
      }
      await _verifyOwnerPin(shopId: session.shop.id, pin: pin);
    }
    return _repository.closeSession(
      shopId: session.shop.id,
      userId: session.user.id,
      sessionId: sessionId,
      input: input,
    );
  }
}

class RecordCashMovement {
  const RecordCashMovement(this._repository);

  final CashSessionRepository _repository;

  Future<CashMovement> call({
    required AuthSession session,
    required int sessionId,
    required RecordCashMovementInput input,
  }) =>
      _repository.recordMovement(
        shopId: session.shop.id,
        userId: session.user.id,
        sessionId: sessionId,
        input: input,
      );
}

class SyncCashSessionsFromRemote {
  const SyncCashSessionsFromRemote(this._repository);

  final CashSessionRepository _repository;

  Future<void> call({required AuthSession session}) =>
      _repository.syncFromRemote(shopId: session.shop.id);
}
