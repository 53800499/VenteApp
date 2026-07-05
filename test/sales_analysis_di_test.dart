import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:venteapp/app/di/injection_container.dart';
import 'package:venteapp/features/sales_analysis/data/datasources/remote/sales_analysis_remote_datasource.dart';
import 'package:venteapp/features/sales_analysis/domain/repositories/sales_analysis_repository.dart';
import 'package:venteapp/features/sales_analysis/domain/usecases/sales_analysis_usecases.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Analyse des ventes — DI remote + use cases', () async {
    SharedPreferences.setMockInitialValues({});
    await initDependencies();
    ensureSalesAnalysisDependencies();

    expect(sl.isRegistered<SalesAnalysisRemoteDatasource>(), isTrue);
    expect(sl.isRegistered<ListCategorySalesAnalysis>(), isTrue);
    expect(sl.isRegistered<GetMarginAnalysis>(), isTrue);
    expect(sl.isRegistered<ListPriceDeviationAnalysis>(), isTrue);
    expect(sl.isRegistered<GetSalesTrendAnalysis>(), isTrue);
    expect(sl<SalesAnalysisRepository>(), isA<SalesAnalysisRepository>());
  });
}
