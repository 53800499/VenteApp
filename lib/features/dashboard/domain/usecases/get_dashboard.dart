import '../../../../shared/enums/permission.dart';
import '../entities/dashboard_entities.dart';
import '../repositories/dashboard_repository.dart';

class GetDashboard {
  const GetDashboard(this._repository);

  final DashboardRepository _repository;

  Future<DashboardData> call({
    required int shopId,
    required Set<Permission> permissions,
  }) =>
      _repository.getDashboard(shopId: shopId, permissions: permissions);
}
