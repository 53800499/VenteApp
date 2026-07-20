import '../entities/fx_exchange_entities.dart';
import '../repositories/fx_exchange_repository.dart';

class IsFxModuleEnabled {
  const IsFxModuleEnabled(this._repository);

  final FxExchangeRepository _repository;

  Future<bool> call({required int shopId}) =>
      _repository.isModuleEnabled(shopId: shopId);
}

class ToggleFxModule {
  const ToggleFxModule(this._repository);

  final FxExchangeRepository _repository;

  Future<void> call({required int shopId, required bool enabled}) =>
      _repository.toggleModule(shopId: shopId, enabled: enabled);
}

class ListFxCurrencies {
  const ListFxCurrencies(this._repository);

  final FxExchangeRepository _repository;

  Future<List<FxCurrency>> call() => _repository.listCurrencies();
}

class ListFxShopCurrencies {
  const ListFxShopCurrencies(this._repository);

  final FxExchangeRepository _repository;

  Future<List<FxShopCurrency>> call({required int shopId}) =>
      _repository.listShopCurrencies(shopId: shopId);
}

class UpsertFxShopCurrencies {
  const UpsertFxShopCurrencies(this._repository);

  final FxExchangeRepository _repository;

  Future<List<FxShopCurrency>> call({
    required int shopId,
    required List<UpsertFxShopCurrencyInput> items,
  }) =>
      _repository.upsertShopCurrencies(shopId: shopId, items: items);
}

class CreateFxRate {
  const CreateFxRate(this._repository);

  final FxExchangeRepository _repository;

  Future<FxRateSnapshot> call({
    required int shopId,
    required int userId,
    required CreateFxRateInput input,
  }) =>
      _repository.createRate(shopId: shopId, userId: userId, input: input);
}

class ListFxLatestRates {
  const ListFxLatestRates(this._repository);

  final FxExchangeRepository _repository;

  Future<List<FxRateSnapshot>> call({required int shopId}) =>
      _repository.listLatestRates(shopId: shopId);
}

class ListFxRateHistory {
  const ListFxRateHistory(this._repository);

  final FxExchangeRepository _repository;

  Future<List<FxRateSnapshot>> call({
    required int shopId,
    String? quoteCurrency,
    int limit = 100,
  }) =>
      _repository.listRateHistory(
        shopId: shopId,
        quoteCurrency: quoteCurrency,
        limit: limit,
      );
}

class FindOpenFxSession {
  const FindOpenFxSession(this._repository);

  final FxExchangeRepository _repository;

  Future<FxSession?> call({required int shopId}) =>
      _repository.findOpenSession(shopId: shopId);
}

class ListFxSessions {
  const ListFxSessions(this._repository);

  final FxExchangeRepository _repository;

  Future<List<FxSessionListRow>> call({required int shopId}) =>
      _repository.listSessions(shopId: shopId);
}

class GetFxLiveBalances {
  const GetFxLiveBalances(this._repository);

  final FxExchangeRepository _repository;

  Future<Map<String, int>> call({
    required int shopId,
    required int sessionId,
  }) =>
      _repository.computeLiveBalances(
        shopId: shopId,
        sessionId: sessionId,
      );
}

class OpenFxSession {
  const OpenFxSession(this._repository);

  final FxExchangeRepository _repository;

  Future<FxSession> call({
    required int shopId,
    required int userId,
    required OpenFxSessionInput input,
  }) =>
      _repository.openSession(
        shopId: shopId,
        userId: userId,
        input: input,
      );
}

class CloseFxSession {
  const CloseFxSession(this._repository);

  final FxExchangeRepository _repository;

  Future<FxSession> call({
    required int shopId,
    required int userId,
    required int sessionId,
    required CloseFxSessionInput input,
  }) =>
      _repository.closeSession(
        shopId: shopId,
        userId: userId,
        sessionId: sessionId,
        input: input,
      );
}

class PreviewFxOperation {
  const PreviewFxOperation(this._repository);

  final FxExchangeRepository _repository;

  Future<FxOperationPreview> call({
    required int shopId,
    required CreateFxOperationInput input,
  }) =>
      _repository.previewOperation(shopId: shopId, input: input);
}

class CreateFxOperation {
  const CreateFxOperation(this._repository);

  final FxExchangeRepository _repository;

  Future<FxOperation> call({
    required int shopId,
    required int userId,
    required int sessionId,
    required CreateFxOperationInput input,
    required bool allowNegativeBalance,
  }) =>
      _repository.createOperation(
        shopId: shopId,
        userId: userId,
        sessionId: sessionId,
        input: input,
        allowNegativeBalance: allowNegativeBalance,
      );
}

class ListFxOperations {
  const ListFxOperations(this._repository);

  final FxExchangeRepository _repository;

  Future<List<FxOperation>> call({
    required int shopId,
    int? sessionId,
  }) =>
      _repository.listOperations(shopId: shopId, sessionId: sessionId);
}

class CreateFxMovement {
  const CreateFxMovement(this._repository);

  final FxExchangeRepository _repository;

  Future<FxMovement> call({
    required int shopId,
    required int userId,
    required int sessionId,
    required CreateFxMovementInput input,
    required bool allowNegativeBalance,
  }) =>
      _repository.createMovement(
        shopId: shopId,
        userId: userId,
        sessionId: sessionId,
        input: input,
        allowNegativeBalance: allowNegativeBalance,
      );
}

class ListFxMovements {
  const ListFxMovements(this._repository);

  final FxExchangeRepository _repository;

  Future<List<FxMovement>> call({
    required int shopId,
    int? sessionId,
  }) =>
      _repository.listMovements(shopId: shopId, sessionId: sessionId);
}

class GetFxDailyReport {
  const GetFxDailyReport(this._repository);

  final FxExchangeRepository _repository;

  Future<FxDailyReport> call({
    required int shopId,
    required int sessionId,
  }) =>
      _repository.getDailyReport(shopId: shopId, sessionId: sessionId);
}

class SyncFxExchangeFromRemote {
  const SyncFxExchangeFromRemote(this._repository);

  final FxExchangeRepository _repository;

  Future<void> call({required int shopId}) =>
      _repository.syncFromRemote(shopId: shopId);
}
