import '../entities/report_entities.dart';

abstract class ReportRepository {
  Future<Report> getReport({
    required int activeShopId,
    required int ownerUserId,
    required ReportQuery query,
    required bool canViewFinancial,
    required bool canUseConsolidated,
    required bool includeSellerPerformance,
  });
}
