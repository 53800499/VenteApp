import '../../../../core/utils/benin_day_range.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/sales_analysis_entities.dart';

String formatRelativeSaleDate(int soldAtMs) {
  final bounds = getBeninDayBounds();
  const dayMs = 86_400_000;
  final yesterdayStart = bounds.dayStartMs - dayMs;

  if (soldAtMs >= bounds.dayStartMs) return "Aujourd'hui";
  if (soldAtMs >= yesterdayStart) return 'Hier';
  return formatBeninDate(soldAtMs);
}

String formatQuantitySold(double quantity) {
  if (quantity == quantity.roundToDouble()) {
    return quantity.toInt().toString();
  }
  return quantity.toStringAsFixed(1);
}

bool isUnusuallyLowPrice({
  required int enteredPrice,
  required ProductSoldPriceRange range,
}) {
  if (!range.hasEnoughData) return false;
  if (enteredPrice >= range.minPrice) return false;
  final threshold = (range.minPrice * 0.9).round();
  return enteredPrice < threshold;
}

String unusualPriceMessage({
  required String productName,
  required int enteredPrice,
  required ProductSoldPriceRange range,
}) {
  return 'Le produit « $productName » est habituellement vendu entre '
      '${formatFcfa(range.minPrice)} et ${formatFcfa(range.maxPrice)}. '
      'Le prix saisi (${formatFcfa(enteredPrice)}) est inhabituellement bas. '
      'Voulez-vous continuer ?';
}
