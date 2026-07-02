import '../../../auth/domain/entities/auth_entities.dart';
import '../entities/report_entities.dart';
import '../repositories/report_repository.dart';

class GetReport {
  const GetReport(this._repository);

  final ReportRepository _repository;

  Future<Report> call({
    required AuthSession session,
    required ReportQuery query,
    required bool canViewFinancial,
    required bool canUseConsolidated,
    required bool includeSellerPerformance,
  }) {
    return _repository.getReport(
      activeShopId: session.shop.id,
      ownerUserId: session.user.id,
      query: query,
      canViewFinancial: canViewFinancial,
      canUseConsolidated: canUseConsolidated,
      includeSellerPerformance: includeSellerPerformance,
    );
  }
}
