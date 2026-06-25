import '../../../../shared/enums/permission.dart';
import '../entities/dashboard_entities.dart';

abstract class DashboardRepository {
  Future<DashboardData> getDashboard({
    required int shopId,
    required Set<Permission> permissions,
    int defaultAlertThreshold = 5,
  });
}
