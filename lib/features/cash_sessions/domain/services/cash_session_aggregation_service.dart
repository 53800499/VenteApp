class CashSessionAggregationService {
  const CashSessionAggregationService();

  int expectedCash({
    required int openingCash,
    required int salesCash,
    required int depositsCash,
    required int expensesCash,
    required int withdrawalsCash,
  }) =>
      openingCash + salesCash + depositsCash - expensesCash - withdrawalsCash;

  int expectedMomo({
    required int openingMomo,
    required int salesMomo,
    required int depositsMomo,
    required int expensesMomo,
    required int withdrawalsMomo,
  }) =>
      openingMomo + salesMomo + depositsMomo - expensesMomo - withdrawalsMomo;

  int difference(int counted, int expected) => counted - expected;
}
