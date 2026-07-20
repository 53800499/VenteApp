import '../../domain/entities/fx_exchange_entities.dart';

abstract class FxExchangeRepository {
  Future<bool> isModuleEnabled({required int shopId});

  Future<void> toggleModule({required int shopId, required bool enabled});

  Future<List<FxCurrency>> listCurrencies();

  Future<List<FxShopCurrency>> listShopCurrencies({required int shopId});

  Future<List<FxShopCurrency>> upsertShopCurrencies({
    required int shopId,
    required List<UpsertFxShopCurrencyInput> items,
  });

  Future<FxRateSnapshot> createRate({
    required int shopId,
    required int userId,
    required CreateFxRateInput input,
  });

  Future<List<FxRateSnapshot>> listLatestRates({required int shopId});

  Future<List<FxRateSnapshot>> listRateHistory({
    required int shopId,
    String? quoteCurrency,
    int limit = 100,
  });

  Future<FxSession?> findOpenSession({required int shopId});

  Future<List<FxSessionListRow>> listSessions({
    required int shopId,
    int limit = 50,
  });

  Future<FxSession> getSession({required int shopId, required int sessionId});

  Future<Map<String, int>> computeLiveBalances({
    required int shopId,
    required int sessionId,
  });

  Future<FxSession> openSession({
    required int shopId,
    required int userId,
    required OpenFxSessionInput input,
  });

  Future<FxSession> closeSession({
    required int shopId,
    required int userId,
    required int sessionId,
    required CloseFxSessionInput input,
  });

  Future<FxOperationPreview> previewOperation({
    required int shopId,
    required CreateFxOperationInput input,
  });

  Future<FxOperation> createOperation({
    required int shopId,
    required int userId,
    required int sessionId,
    required CreateFxOperationInput input,
    required bool allowNegativeBalance,
  });

  Future<List<FxOperation>> listOperations({
    required int shopId,
    int? sessionId,
    int limit = 200,
  });

  Future<FxMovement> createMovement({
    required int shopId,
    required int userId,
    required int sessionId,
    required CreateFxMovementInput input,
    required bool allowNegativeBalance,
  });

  Future<List<FxMovement>> listMovements({
    required int shopId,
    int? sessionId,
    int limit = 200,
  });

  Future<FxDailyReport> getDailyReport({
    required int shopId,
    required int sessionId,
  });

  Future<void> syncFromRemote({required int shopId});
}
