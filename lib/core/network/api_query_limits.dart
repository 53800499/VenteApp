import '../constants/app_constants.dart';

abstract final class ApiQueryLimits {
  static int clampLimit(int limit, {int? max}) {
    final ceiling = max ?? AppConstants.apiListLimitMax;
    if (limit < 1) return 1;
    if (limit > ceiling) return ceiling;
    return limit;
  }

  static int clampPage(int page) => page < 1 ? 1 : page;
}
