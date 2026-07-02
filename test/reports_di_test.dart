import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:venteapp/app/di/injection_container.dart';
import 'package:venteapp/features/reports/domain/repositories/report_repository.dart';
import 'package:venteapp/features/reports/domain/usecases/get_report.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('GetReport est résolu après initDependencies', () async {
    SharedPreferences.setMockInitialValues({});
    await initDependencies();

    expect(sl.isRegistered<GetReport>(), isTrue);
    expect(sl<GetReport>(), isA<GetReport>());
    expect(sl<ReportRepository>(), isA<ReportRepository>());
  });
}
